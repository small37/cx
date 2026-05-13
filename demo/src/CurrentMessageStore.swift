import Foundation

final class CurrentMessageStore {
    private let queue = DispatchQueue(label: "touchbar.message.store", qos: .utility)
    private var expirationTimer: DispatchSourceTimer?
    private var observers: [UUID: () -> Void] = [:]

    private(set) var currentMessage: TouchBarMessage?
    private(set) var defaultStatus = "已启动"
    private(set) var isPaused = false

    @discardableResult
    func addObserver(_ observer: @escaping () -> Void) -> UUID {
        let id = UUID()
        queue.async { [weak self] in
            self?.observers[id] = observer
        }
        return id
    }

    func removeObserver(_ id: UUID) {
        queue.async { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    func setPaused(_ paused: Bool) {
        queue.async { [weak self] in
            guard let self else { return }
            self.isPaused = paused
            self.notifyChange()
        }
    }

    func setDefaultStatus(_ text: String) {
        queue.async { [weak self] in
            guard let self else { return }
            self.defaultStatus = text
            self.notifyChange()
        }
    }

    func setMessage(_ message: TouchBarMessage?) {
        queue.async { [weak self] in
            guard let self else { return }
            self.expirationTimer?.cancel()
            self.expirationTimer = nil
            self.currentMessage = message

            if let ttl = message?.ttl, ttl > 0 {
                let timer = DispatchSource.makeTimerSource(queue: self.queue)
                timer.schedule(deadline: .now() + ttl)
                timer.setEventHandler { [weak self] in
                    guard let self else { return }
                    self.currentMessage = nil
                    self.expirationTimer?.cancel()
                    self.expirationTimer = nil
                    self.notifyChange()
                }
                self.expirationTimer = timer
                timer.resume()
            }

            self.notifyChange()
        }
    }

    func clearMessage() {
        setMessage(nil)
    }

    func snapshot(completion: @escaping (_ currentMessage: TouchBarMessage?, _ defaultStatus: String, _ isPaused: Bool) -> Void) {
        queue.async { [weak self] in
            guard let self else { return }
            completion(self.currentMessage, self.defaultStatus, self.isPaused)
        }
    }

    private func notifyChange() {
        let callbacks = observers.values
        DispatchQueue.main.async {
            for cb in callbacks {
                cb()
            }
        }
    }
}
