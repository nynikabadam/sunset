//
//  NetworkMonitor.swift
//  sunset
//
//  Knows whether the phone is online, so the app can show the offline screen
//  and reload the forecast when the connection comes back.
//

import Foundation
import Network
import Observation

@Observable
final class NetworkMonitor {
    private(set) var isOnline = true

    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.isOnline = online }
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
    }

    deinit { monitor.cancel() }
}
