import Foundation
import Network
import os

/// Performs TCP connectivity checks against a configured host and port.
struct TCPMonitorProvider: MonitorProvider {
    private let config: TCPMonitorConfig
    private let logger = Logger(subsystem: "com.sattlerjoshua.Pulse", category: "TCPMonitor")
    private let queue = DispatchQueue(label: "com.sattlerjoshua.Pulse.tcp-check")

    init(config: TCPMonitorConfig) {
        self.config = config
    }

    func check() async throws -> CheckResult {
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(config.host),
            port: NWEndpoint.Port(integerLiteral: UInt16(config.port))
        )
        
        let parameters = NWParameters.tcp
        let connection = NWConnection(to: endpoint, using: parameters)
        let lock = OSAllocatedUnfairLock(initialState: false)
        let start = ContinuousClock.now
        
        return await withCheckedContinuation { continuation in
            connection.stateUpdateHandler = { state in
                self.logger.debug("TCP state update for \(self.config.host):\(self.config.port): \(String(describing: state))")
                
                switch state {
                case .ready:
                    if config.expectResponse == true {
                        // Start receiving data to verify the handshake
                        self.logger.debug("TCP [\(self.config.host)] ready, waiting for data...")
                        receiveBanner(connection: connection)
                    } else {
                        complete(with: .operational, message: nil)
                    }
                case .failed(let error):
                    complete(with: .downtime, message: error.localizedDescription)
                case .waiting(let error):
                    complete(with: .downtime, message: "Waiting/Refused: \(error.localizedDescription)")
                default:
                    break
                }
            }
            
            func receiveBanner(connection: NWConnection) {
                connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { content, _, isComplete, error in
                    if let error = error {
                        complete(with: .downtime, message: "Read failed: \(error.localizedDescription)")
                    } else if content != nil {
                        complete(with: .operational, message: nil)
                    } else if isComplete {
                        complete(with: .downtime, message: "Connection closed by server without data")
                    }
                }
            }
            
            func complete(with status: MonitorStatus, message: String?) {
                let alreadyResponded = lock.withLock { isResponded in
                    let original = isResponded
                    isResponded = true
                    return original
                }
                
                if !alreadyResponded {
                    connection.stateUpdateHandler = nil
                    connection.cancel()
                    
                    let elapsed = ContinuousClock.now - start
                    self.logger.info("TCP check for \(self.config.host):\(self.config.port) completed: \(status.rawValue) in \(elapsed)")
                    
                    continuation.resume(returning: CheckResult(
                        status: status,
                        responseTime: elapsed,
                        timestamp: .now,
                        message: message
                    ))
                }
            }
            
            // Hard timeout at 5 seconds.
            Task {
                try? await Task.sleep(for: .seconds(5))
                complete(with: .downtime, message: "Timeout")
            }
            
            connection.start(queue: queue)
        }
    }
}
