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
        let lock = OSAllocatedUnfairLock(initialState: false)
        
        return await withCheckedContinuation { continuation in
            connection.stateUpdateHandler = { state in
                self.logger.debug("TCP state update for \(self.config.host):\(self.config.port): \(String(describing: state))")
                switch state {
                case .ready:
                    let alreadyResponded = lock.withLock { isResponded in
                        let original = isResponded
                        isResponded = true
                        return original
                    }
                    
                    if !alreadyResponded {
                        self.logger.info("TCP connection ready for \(self.config.host):\(self.config.port)")
                        connection.cancel()
                        let elapsed = ContinuousClock.now - start
                        continuation.resume(returning: CheckResult(
                            status: .operational,
                            responseTime: elapsed,
                            timestamp: .now
                        ))
                    }
                case .failed(let error):
                    let alreadyResponded = lock.withLock { isResponded in
                        let original = isResponded
                        isResponded = true
                        return original
                    }

                    if !alreadyResponded {
                        self.logger.warning("TCP connection failed for \(self.config.host):\(self.config.port): \(error.localizedDescription)")
                        connection.cancel()
                        continuation.resume(returning: CheckResult(
                            status: .downtime,
                            timestamp: .now,
                            message: error.localizedDescription
                        ))
                    }
                case .waiting(let error):
                    self.logger.debug("TCP connection waiting for \(self.config.host):\(self.config.port): \(error.localizedDescription)")
                default:
                    break
                }
            }
            
            // Timeout after 5 seconds if no response.
            Task {
                try? await Task.sleep(for: .seconds(5))
                let alreadyResponded = lock.withLock { isResponded in
                    let original = isResponded
                    isResponded = true
                    return original
                }

                if !alreadyResponded {
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
