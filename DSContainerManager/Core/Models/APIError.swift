import Foundation

enum SynologyAPIError: Error, Equatable, LocalizedError {
    case invalidURL
    case networkError(String)
    case invalidCredentials
    case accountDisabled
    case permissionDenied
    case sessionExpired
    case sessionInterrupted
    case otpRequired
    case otpFailed
    case apiError(code: Int, message: String)
    case decodingError(String)
    case unknownError(String)
    case noActiveSession

    static func fromErrorCode(_ code: Int) -> SynologyAPIError {
        switch code {
        case 400:
            return .invalidCredentials
        case 401:
            return .accountDisabled
        case 402:
            return .permissionDenied
        case 403:
            return .otpRequired
        case 404:
            return .otpFailed
        case 105:
            return .permissionDenied
        case 106:
            return .sessionExpired
        case 107:
            return .sessionInterrupted
        default:
            return .apiError(code: code, message: "Synology API error code \(code)")
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid server URL"
        case let .networkError(message):
            "Network error: \(message)"
        case .invalidCredentials:
            "Invalid username or password"
        case .accountDisabled:
            "Account is disabled"
        case .permissionDenied:
            "Permission denied"
        case .sessionExpired:
            "Session expired — please reconnect"
        case .sessionInterrupted:
            "Session interrupted by another login"
        case .otpRequired:
            "Two-factor authentication code required"
        case .otpFailed:
            "Invalid two-factor authentication code"
        case let .apiError(code, message):
            "API error \(code): \(message)"
        case let .decodingError(message):
            "Data error: \(message)"
        case let .unknownError(message):
            "Unknown error: \(message)"
        case .noActiveSession:
            "No active session — please log in"
        }
    }

    var isSessionError: Bool {
        switch self {
        case .sessionExpired, .sessionInterrupted, .noActiveSession:
            true
        default:
            false
        }
    }
}
