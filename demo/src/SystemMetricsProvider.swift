import Foundation
import Darwin

struct SystemMetrics {
    let cpuPercent: Double
    let memoryPercent: Double
}

final class SystemMetricsProvider {
    private var previousTicks: host_cpu_load_info_data_t?

    func sample() -> SystemMetrics {
        let cpu = sampleCPU()
        let memory = sampleMemory()
        return SystemMetrics(cpuPercent: cpu, memoryPercent: memory)
    }

    private func sampleCPU() -> Double {
        var cpuInfo = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        guard let previous = previousTicks else {
            previousTicks = cpuInfo
            return 0
        }

        let user = Double(cpuInfo.cpu_ticks.0 - previous.cpu_ticks.0)
        let system = Double(cpuInfo.cpu_ticks.1 - previous.cpu_ticks.1)
        let idle = Double(cpuInfo.cpu_ticks.2 - previous.cpu_ticks.2)
        let nice = Double(cpuInfo.cpu_ticks.3 - previous.cpu_ticks.3)

        previousTicks = cpuInfo
        let total = user + system + idle + nice
        guard total > 0 else { return 0 }
        let active = user + system + nice
        return max(0, min(100, active / total * 100))
    }

    private func sampleMemory() -> Double {
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        let usedPages = vmStats.active_count + vmStats.inactive_count + vmStats.wire_count + vmStats.compressor_page_count
        let usedBytes = Double(usedPages) * Double(pageSize)
        let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)
        guard totalBytes > 0 else { return 0 }
        return max(0, min(100, usedBytes / totalBytes * 100))
    }
}
