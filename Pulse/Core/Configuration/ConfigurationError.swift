import Foundation

/// Errors that can occur when loading or validating configuration.
enum ConfigurationError: LocalizedError {
    case fileNotFound(URL)
    case decodingFailed(Error)
    case validationFailed(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            "Configuration file not found at \(url.path())."
        case .decodingFailed(let error):
            "Failed to decode configuration: \(error.localizedDescription)"
        case .validationFailed(let reason):
            "Configuration validation failed: \(reason)"
        }
    }
}
