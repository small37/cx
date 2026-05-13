import Foundation
import Darwin

let args = CommandLine.arguments
guard args.count >= 3 else {
    exit(2)
}

let socketPath = args[1]
let payload = args[2] + "\n"

let fd = socket(AF_UNIX, SOCK_STREAM, 0)
guard fd >= 0 else { exit(1) }
defer { close(fd) }

var addr = sockaddr_un()
addr.sun_family = sa_family_t(AF_UNIX)
let pathBytes = socketPath.utf8CString
let maxPath = MemoryLayout.size(ofValue: addr.sun_path)
guard pathBytes.count <= maxPath else { exit(1) }

withUnsafeMutablePointer(to: &addr.sun_path.0) { ptr in
    pathBytes.withUnsafeBufferPointer { src in
        _ = memcpy(ptr, src.baseAddress!, src.count)
    }
}

let len = socklen_t(MemoryLayout.size(ofValue: addr.sun_family) + pathBytes.count)
let connected = withUnsafePointer(to: &addr) {
    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        connect(fd, $0, len)
    }
}
guard connected == 0 else { exit(1) }

let data = Array(payload.utf8)
let written = data.withUnsafeBytes {
    write(fd, $0.baseAddress, data.count)
}
if written < 0 {
    exit(1)
}

