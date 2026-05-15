import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var socketServer: SocketServer?
    private var commandRouter: CommandRouter?
    private var messageStore: CurrentMessageStore?
    private var touchBarController: TouchBarController?

    private let hotkeyManager = HotkeyManager()
    private let selectedTextReader = SelectedTextReader()
    private let floatingTextPanel = FloatingTextPanelController()
    private let translator = BaiduTranslator()
    private let ocr = OfflineOCR()
    private let screenshotManager = ScreenshotManager()
    private let toastWindow = ToastWindow()
    private let permissionManager = PermissionManager()
    private var isCapturingScreenshot = false
    private var isReadingSelectedText = false
    private var isCaptureAndTextFeatureEnabled = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = CurrentMessageStore()
        let router = CommandRouter(store: store)
        let socketPath = NSHomeDirectory() + "/.touchbar-island/touchbar.sock"
        let server = SocketServer(path: socketPath) { line in
            router.handle(rawLine: line)
        }

        messageStore = store
        commandRouter = router
        socketServer = server
        touchBarController = TouchBarController(store: store)
        statusBarController = StatusBarController(messageStore: store)
        touchBarController?.start()
        server.start()

        statusBarController?.onCaptureAndTextFeatureToggled = { [weak self] enabled in
            self?.isCaptureAndTextFeatureEnabled = enabled
        }

        hotkeyManager.onReadSelectedText = { [weak self] in
            self?.triggerReadSelectedText()
        }
        hotkeyManager.onStartScreenshot = { [weak self] in
            self?.triggerScreenshotSelection()
        }
        hotkeyManager.registerHotkeys()
    }

    func applicationWillTerminate(_ notification: Notification) {
        socketServer?.stop()
        touchBarController?.stop()
        hotkeyManager.unregisterHotkeys()
    }

    private func triggerReadSelectedText() {
        guard isCaptureAndTextFeatureEnabled else {
            toastWindow.show(message: "截图与获取文本功能已关闭")
            return
        }
        guard !isCapturingScreenshot, !isReadingSelectedText else { return }
        guard permissionManager.ensureAccessibilityPermission() else {
            toastWindow.show(message: "请先在系统设置中开启辅助功能权限")
            return
        }
        isReadingSelectedText = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let result = self.selectedTextReader.readSelectedText()
            guard let text = result.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                DispatchQueue.main.async {
                    self.isReadingSelectedText = false
                }
                return
            }
            let title = self.title(for: result.method)
            DispatchQueue.main.async {
                self.floatingTextPanel.show(sourceText: text, translatedText: "翻译中...", title: title)
                self.translateSelectedText(text)
                self.isReadingSelectedText = false
            }
        }
    }

    private func translateSelectedText(_ text: String) {
        translator.translate(text) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let translatedText):
                    self?.floatingTextPanel.updateTranslation(translatedText)
                case .failure(let error):
                    self?.floatingTextPanel.updateTranslation("翻译失败：\(error.localizedDescription)")
                }
            }
        }
    }

    private func title(for method: SelectedTextReadMethod) -> String {
        switch method {
        case .accessibility:
            return "选中文本 - AX"
        case .clipboard:
            return "选中文本 - 剪贴板"
        case .failed:
            return "选中文本 - 未读取到"
        }
    }

    private func triggerScreenshotSelection() {
        guard isCaptureAndTextFeatureEnabled else {
            toastWindow.show(message: "截图与获取文本功能已关闭")
            return
        }
        guard !isCapturingScreenshot else { return }
        permissionManager.requestScreenRecordingPermissionIfNeeded()
        guard permissionManager.hasScreenRecordingPermission() else {
            toastWindow.show(message: "请先在系统设置中开启屏幕录制权限")
            return
        }
        isCapturingScreenshot = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let url = try self.screenshotManager.captureInteractively()
                self.handleScreenshotOCRAndTranslate(url: url)
            } catch {
                DispatchQueue.main.async {
                    let nsError = error as NSError
                    if nsError.domain != "ScreenshotManager" || nsError.code != 4 {
                        self.toastWindow.show(message: "截图失败：\(error.localizedDescription)")
                    }
                    self.isCapturingScreenshot = false
                }
            }
        }
    }

    private func handleScreenshotOCRAndTranslate(url: URL) {
        ocr.recognizeText(imageURL: url) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    self.floatingTextPanel.show(sourceText: "OCR失败", translatedText: error.localizedDescription, title: "截图翻译 - OCR失败")
                    self.isCapturingScreenshot = false
                }
            case .success(let ocrText):
                DispatchQueue.main.async {
                    self.floatingTextPanel.show(sourceText: ocrText, translatedText: "翻译中...", title: "截图翻译")
                }
                self.translator.translate(ocrText) { [weak self] translationResult in
                    DispatchQueue.main.async {
                        switch translationResult {
                        case .success(let translatedText):
                            self?.floatingTextPanel.updateTranslation(translatedText)
                        case .failure(let error):
                            self?.floatingTextPanel.updateTranslation("翻译失败：\(error.localizedDescription)")
                        }
                        self?.isCapturingScreenshot = false
                    }
                }
            }
        }
    }
}
