import Foundation

/// Errors that can occur when loading or validating configuration.
enum ConfigurationError: LocalizedError {
    case decodingFailed(Error)
    case validationFailed(String)

    var errorDescription: String? {
        switch self {
        case .decodingFailed(let error):
            "Failed to decode configuration: \(error.localizedDescription)"
        case .validationFailed(let reason):
            "Configuration validation failed: \(reason)"
        }
    }
}
