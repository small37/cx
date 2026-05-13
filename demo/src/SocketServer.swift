import Foundation
import Darwin

final class SocketServer {
    private let path: String
    private let onLine: (String) -> Void
    private let queue = DispatchQueue(label: "touchbar.socket.server", qos: .utility)

    private var listenFD: Int32 = -1
    private var listenSource: DispatchSourceRead?
    private var clientSources: [Int32: DispatchSourceRead] = [:]
    private var clientBuffers: [Int32: Data] = [:]

    init(path: String, onLine: @escaping (String) -> Void) {
        self.path = path
        self.onLine = onLine
    }

    func start() {
        queue.async { [weak self] in
            self?.startInternal()
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.stopInternal()
        }
    }

    deinit {
        stop()
    }

    private func startInternal() {
        stopInternal()

        let dirPath = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dirPath, withIntermediateDirectories: true)
        unlink(path)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let maxPath = MemoryLayout.size(ofValue: addr.sun_path)
        let utf8 = path.utf8CString
        guard utf8.count <= maxPath else {
            close(fd)
            return
        }
        withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in
            utf8.withUnsafeBufferPointer { src in
                _ = memcpy(ptr, src.baseAddress!, src.count)
            }
        }

        let bindLen = socklen_t(MemoryLayout.size(ofValue: addr.sun_family) + utf8.count)
        guard withUnsafePointer(to: &addr, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, bindLen)
            }
        }) == 0 else {
            close(fd)
            return
        }

        guard listen(fd, 8) == 0 else {
            close(fd)
            return
        }

        listenFD = fd
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in
            self?.acceptClients()
        }
        source.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.listenFD >= 0 {
                close(self.listenFD)
                self.listenFD = -1
            }
            unlink(self.path)
        }
        listenSource = source
        source.resume()
    }

    private func stopInternal() {
        listenSource?.cancel()
        listenSource = nil

        for (fd, source) in clientSources {
            source.cancel()
            close(fd)
        }
        clientSources.removeAll()
        clientBuffers.removeAll()

        if listenFD >= 0 {
            close(listenFD)
            listenFD = -1
        }
        unlink(path)
    }

    private func acceptClients() {
        var clientAddr = sockaddr()
        var clientLen: socklen_t = socklen_t(MemoryLayout<sockaddr>.size)
        let clientFD = accept(listenFD, &clientAddr, &clientLen)
        guard clientFD >= 0 else { return }

        let source = DispatchSource.makeReadSource(fileDescriptor: clientFD, queue: queue)
        clientSources[clientFD] = source
        clientBuffers[clientFD] = Data()

        source.setEventHandler { [weak self] in
            self?.readFromClient(fd: clientFD)
        }
        source.setCancelHandler { [weak self] in
            guard let self else { return }
            self.clientBuffers.removeValue(forKey: clientFD)
            self.clientSources.removeValue(forKey: clientFD)
            close(clientFD)
        }
        source.resume()
    }

    private func readFromClient(fd: Int32) {
        var buf = [UInt8](repeating: 0, count: 4096)
        let readCount = Darwin.read(fd, &buf, buf.count)

        if readCount > 0 {
            var data = clientBuffers[fd] ?? Data()
            data.append(buf, count: readCount)

            while let newline = data.firstIndex(of: 0x0A) {
                let lineData = data.prefix(upTo: newline)
                if let line = String(data: lineData, encoding: .utf8), !line.isEmpty {
                    onLine(line)
                }
                data.removeSubrange(...newline)
            }
            clientBuffers[fd] = data
            return
        }

        if readCount == 0 {
            // EOF：尝试处理最后一行（无换行）
            if let remaining = clientBuffers[fd], !remaining.isEmpty,
               let line = String(data: remaining, encoding: .utf8), !line.isEmpty {
                onLine(line)
            }
        }

        clientSources[fd]?.cancel()
    }
}
