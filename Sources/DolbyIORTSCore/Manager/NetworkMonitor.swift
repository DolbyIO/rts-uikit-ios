//
//  NetworkMonitor.swift
//  
//
//  Created by Raveendran, Aravind on 22/8/2023.
//

import Foundation
import Network

final class NetworkMonitor: ObservableObject {

    private let monitor = NWPathMonitor()

    static let shared = NetworkMonitor()

    @Published var isReachable: Bool = true
    private let queue = DispatchQueue(label: "NetworkConnectivityMonitor")

    init() {
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.isReachable = path.status != .unsatisfied
        }

        monitor.start(queue: queue)
    }
}
