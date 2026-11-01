import Foundation
import Network

/// Calls back when the network becomes available again, so offline changes sync.
final class NetworkMonitor: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "\(AppConfiguration.bundleIdentifier).network-monitor")
    private var wasSatisfied = true

    func start(onReconnect: @escaping @MainActor @Sendable () -> Void) {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let isSatisfied = path.status == .satisfied
            defer { wasSatisfied = isSatisfied }
            if isSatisfied && !wasSatisfied {
                Task { @MainActor in onReconnect() }
            }
        }
        monitor.start(queue: queue)
    }
}
