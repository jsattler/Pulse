import Foundation
import Network
import os

/// Performs TCP connectivity checks against a configured host and port.
struct TCPMonitorProvider: MonitorProvider {
    private let config: TCPMonitorConfig
    private let logger = Logger(subsystem: "com.sattlerjoshua.Pulse", category: "TCPMonitor")

    init(config: TCPMonitorConfig) {
        self.config = config
    }

    func check() async throws -> CheckResult {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(config.host),
            port: NWEndpoint.Port(integerLiteral: UInt16(config.port))
        )
        let connection = NWConnection(to: endpoint, using: .tcp)
        
        let start = ContinuousClock.now
        
        return await withCheckedContinuation { continuation in
            var hasResponded = false
            
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if !hasResponded {
                        hasResponded = true
                        connection.cancel()
                        let elapsed = ContinuousClock.now - start
                        continuation.resume(returning: CheckResult(
                            status: .operational,
                            responseTime: elapsed,
                            timestamp: .now
                        ))
                    }
                case .failed(let error):
                    if !hasResponded {
                        hasResponded = true
                        connection.cancel()
                        continuation.resume(returning: CheckResult(
                            status: .downtime,
                            timestamp: .now,
                            message: error.localizedDescription
                        ))
                    }
                default:
                    break
                }
            }
            
            // Timeout after 5 seconds if no response.
            Task {
                try? await Task.sleep(for: .seconds(5))
                if !hasResponded {
                    hasResponded = true
                    connection.cancel()
                    continuation.resume(returning: CheckResult(
                        status: .downtime,
                        timestamp: .now,
                        message: "Connection timed out"
                    ))
                }
            }
            
            connection.start(queue: .global())
        }
    }
}
