import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var socketServer: SocketServer?
    private var commandRouter: CommandRouter?
    private var messageStore: CurrentMessageStore?
    private var touchBarController: TouchBarController?

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
    }

    func applicationWillTerminate(_ notification: Notification) {
        socketServer?.stop()
        touchBarController?.stop()
    }
}
