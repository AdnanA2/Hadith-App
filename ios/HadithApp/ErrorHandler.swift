import Foundation
import Combine
import UIKit

/// Centralized error handling and user notification system
class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()
    
    @Published var currentError: AppError?
    @Published var isShowingError = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupErrorObservation()
    }
    
    // MARK: - Error Handling Methods
    
    /// Handle an error and decide how to present it to the user
    /// - Parameters:
    ///   - error: The error to handle
    ///   - context: Additional context about where the error occurred
    ///   - shouldDisplay: Whether to automatically show the error to the user
    func handle(_ error: Error, context: String? = nil, shouldDisplay: Bool = true) {
        let appError = AppError.from(error: error, context: context)
        
        // Log the error
        logError(appError)
        
        // Handle authentication errors specially
        if appError.isAuthenticationError {
            handleAuthenticationError(appError)
            return
        }
        
        // Display error to user if requested
        if shouldDisplay {
            DispatchQueue.main.async {
                self.currentError = appError
                self.isShowingError = true
            }
        }
        
        // Send error analytics if configured
        sendErrorAnalytics(appError)
    }
    
    /// Clear the current error
    func clearError() {
        DispatchQueue.main.async {
            self.currentError = nil
            self.isShowingError = false
        }
    }
    
    /// Handle network connectivity issues
    func handleNetworkError(_ error: Error) {
        let networkError = AppError.networkError(error.localizedDescription)
        
        // Check if device is offline
        if isDeviceOffline() {
            let offlineError = AppError.offline
            handle(offlineError, context: "Network connectivity check")
        } else {
            handle(networkError, context: "Network request")
        }
    }
    
    /// Handle authentication-related errors
    private func handleAuthenticationError(_ error: AppError) {
        // Log out user if authentication fails
        AuthenticationManager.shared.logout()
        
        // Show authentication error
        DispatchQueue.main.async {
            self.currentError = error
            self.isShowingError = true
        }
    }
    
    // MARK: - Error Recovery
    
    /// Attempt to recover from an error automatically
    /// - Parameter error: The error to recover from
    /// - Returns: True if recovery was attempted, false otherwise
    func attemptRecovery(from error: AppError) -> Bool {
        switch error {
        case .authenticationError:
            // Try to refresh token
            AuthenticationManager.shared.refreshToken()
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: { _ in
                        self.clearError()
                    }
                )
                .store(in: &cancellables)
            return true
            
        case .networkError, .serverError:
            // Could implement retry logic here
            return false
            
        case .offline:
            // Monitor network status and retry when online
            monitorNetworkStatus()
            return true
            
        default:
            return false
        }
    }
    
    // MARK: - Private Methods
    
    private func setupErrorObservation() {
        // Observe authentication errors
        AuthenticationManager.shared.$authError
            .compactMap { $0 }
            .sink { [weak self] authError in
                let appError = AppError.from(error: authError, context: "Authentication")
                self?.handle(appError)
            }
            .store(in: &cancellables)
    }
    
    private func logError(_ error: AppError) {
        if Environment.isDebug {
            print("🚨 Error: \(error.title)")
            print("📝 Description: \(error.message)")
            if let context = error.context {
                print("🔍 Context: \(context)")
            }
            if let suggestion = error.recoverySuggestion {
                print("💡 Suggestion: \(suggestion)")
            }
        }
        
        // In production, you might want to send this to a logging service
        // like Firebase Crashlytics, Sentry, etc.
    }
    
    private func sendErrorAnalytics(_ error: AppError) {
        // Implementation for sending error analytics
        // This could integrate with Firebase Analytics, Mixpanel, etc.
        
        #if DEBUG
        print("📊 Analytics: Error reported - \(error.analyticsName)")
        #endif
    }
    
    private func isDeviceOffline() -> Bool {
        // Simple network reachability check
        // In a real app, you might want to use Network framework or Reachability
        return false // Placeholder
    }
    
    private func monitorNetworkStatus() {
        // Monitor network status and clear offline error when connection is restored
        // This would typically use Network framework
    }
}

// MARK: - AppError

enum AppError: Error, LocalizedError, Identifiable {
    case authenticationError(String? = nil)
    case authorizationError(String? = nil)
    case networkError(String)
    case serverError(String)
    case validationError(String, [String]?)
    case notFound(String)
    case offline
    case dataCorruption(String)
    case unknown(String)
    
    // Custom errors with context
    case customError(title: String, message: String, context: String?)
    
    var id: String {
        switch self {
        case .authenticationError:
            return "authentication_error"
        case .authorizationError:
            return "authorization_error"
        case .networkError:
            return "network_error"
        case .serverError:
            return "server_error"
        case .validationError:
            return "validation_error"
        case .notFound:
            return "not_found"
        case .offline:
            return "offline"
        case .dataCorruption:
            return "data_corruption"
        case .unknown:
            return "unknown_error"
        case .customError:
            return "custom_error"
        }
    }
    
    var title: String {
        switch self {
        case .authenticationError:
            return "Authentication Error"
        case .authorizationError:
            return "Authorization Error"
        case .networkError:
            return "Network Error"
        case .serverError:
            return "Server Error"
        case .validationError:
            return "Validation Error"
        case .notFound:
            return "Not Found"
        case .offline:
            return "No Internet Connection"
        case .dataCorruption:
            return "Data Error"
        case .unknown:
            return "Unexpected Error"
        case .customError(let title, _, _):
            return title
        }
    }
    
    var message: String {
        switch self {
        case .authenticationError(let message):
            return message ?? "Please log in again to continue"
        case .authorizationError(let message):
            return message ?? "You don't have permission to access this resource"
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .validationError(let message, _):
            return "Validation error: \(message)"
        case .notFound(let message):
            return "Not found: \(message)"
        case .offline:
            return "Please check your internet connection and try again"
        case .dataCorruption(let message):
            return "Data corruption detected: \(message)"
        case .unknown(let message):
            return "An unexpected error occurred: \(message)"
        case .customError(_, let message, _):
            return message
        }
    }
    
    var context: String? {
        switch self {
        case .customError(_, _, let context):
            return context
        default:
            return nil
        }
    }
    
    var errorDescription: String? {
        return message
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .authenticationError:
            return "Try logging in again"
        case .authorizationError:
            return "Contact support if you believe this is an error"
        case .networkError, .offline:
            return "Check your internet connection and try again"
        case .serverError:
            return "Please try again later"
        case .validationError(_, let details):
            return details?.joined(separator: ", ")
        case .notFound:
            return "The requested item may have been moved or deleted"
        case .dataCorruption:
            return "Try restarting the app or clearing app data"
        case .unknown:
            return "Please try again or contact support"
        case .customError:
            return "Please try again"
        }
    }
    
    var isAuthenticationError: Bool {
        switch self {
        case .authenticationError, .authorizationError:
            return true
        default:
            return false
        }
    }
    
    var isNetworkError: Bool {
        switch self {
        case .networkError, .offline:
            return true
        default:
            return false
        }
    }
    
    var analyticsName: String {
        return id
    }
    
    // MARK: - Factory Methods
    
    static func from(error: Error, context: String? = nil) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        
        if let authError = error as? AuthError {
            switch authError {
            case .invalidCredentials:
                return .authenticationError("Invalid credentials")
            case .emailAlreadyExists:
                return .validationError("Email already exists", nil)
            case .networkError(let message):
                return .networkError(message)
            case .serverError(let message):
                return .serverError(message)
            case .validationError(let message, let details):
                return .validationError(message, details)
            case .keychainError(let message):
                return .dataCorruption(message)
            case .notAuthenticated:
                return .authenticationError("Not authenticated")
            case .unknown(let message):
                return .unknown(message)
            }
        }
        
        if let apiError = error as? APIServiceError {
            switch apiError {
            case .invalidURL(let endpoint):
                return .unknown("Invalid URL: \(endpoint)")
            case .invalidResponse:
                return .serverError("Invalid response from server")
            case .networkError(let error):
                return .networkError(error.localizedDescription)
            case .encodingError(let error):
                return .unknown("Encoding error: \(error.localizedDescription)")
            case .decodingError(let error):
                return .serverError("Failed to decode response: \(error.localizedDescription)")
            case .authenticationError(let message):
                return .authenticationError(message)
            case .authorizationError(let message):
                return .authorizationError(message)
            case .notFound(let message):
                return .notFound(message)
            case .validationError(let message, let details):
                return .validationError(message, details)
            case .serverError(_, let message):
                return .serverError(message)
            case .httpError(_, let message):
                return .serverError(message)
            case .serviceUnavailable:
                return .serverError("Service temporarily unavailable")
            }
        }
        
        if let hadithError = error as? HadithServiceError {
            switch hadithError {
            case .notFound(let message):
                return .notFound(message)
            case .networkError(let message):
                return .networkError(message)
            case .authenticationRequired:
                return .authenticationError("Authentication required")
            case .serverError(let message):
                return .serverError(message)
            case .validationError(let message):
                return .validationError(message, nil)
            case .unknown(let message):
                return .unknown(message)
            }
        }
        
        // Handle URLError specifically
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .offline
            case .timedOut:
                return .networkError("Request timed out")
            case .cannotFindHost, .cannotConnectToHost:
                return .networkError("Cannot connect to server")
            default:
                return .networkError(urlError.localizedDescription)
            }
        }
        
        return .unknown(error.localizedDescription)
    }
}

// MARK: - Error Presentation Helpers

extension ErrorHandler {
    /// Get appropriate system image for error type
    func systemImage(for error: AppError) -> String {
        switch error {
        case .authenticationError, .authorizationError:
            return "person.crop.circle.badge.exclamationmark"
        case .networkError, .offline:
            return "wifi.exclamationmark"
        case .serverError:
            return "server.rack"
        case .validationError:
            return "exclamationmark.triangle"
        case .notFound:
            return "questionmark.circle"
        case .dataCorruption:
            return "exclamationmark.octagon"
        case .unknown, .customError:
            return "exclamationmark.circle"
        }
    }
    
    /// Get appropriate color for error type
    func errorColor(for error: AppError) -> String {
        switch error {
        case .authenticationError, .authorizationError:
            return "orange"
        case .networkError, .offline:
            return "blue"
        case .serverError:
            return "red"
        case .validationError:
            return "yellow"
        case .notFound:
            return "gray"
        case .dataCorruption:
            return "purple"
        case .unknown, .customError:
            return "red"
        }
    }
}

// MARK: - Publisher Extensions for Error Handling

extension Publisher {
    /// Handle errors using the global error handler
    /// - Parameters:
    ///   - errorHandler: The error handler to use (defaults to shared instance)
    ///   - context: Context information about where the error occurred
    ///   - shouldDisplay: Whether to automatically display the error
    /// - Returns: Publisher that handles errors
    func handleErrors(
        with errorHandler: ErrorHandler = ErrorHandler.shared,
        context: String? = nil,
        shouldDisplay: Bool = true
    ) -> Publishers.HandleEvents<Self> {
        return handleEvents(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    errorHandler.handle(error, context: context, shouldDisplay: shouldDisplay)
                }
            }
        )
    }
    
    /// Retry with exponential backoff on network errors
    /// - Parameters:
    ///   - maxRetries: Maximum number of retry attempts
    ///   - baseDelay: Base delay between retries
    /// - Returns: Publisher that retries on network errors
    func retryOnNetworkError(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0
    ) -> AnyPublisher<Output, Failure> {
        return self.catch { error -> AnyPublisher<Output, Failure> in
            let appError = AppError.from(error: error)
            
            if maxRetries > 0 && appError.isNetworkError {
                return Just(())
                    .delay(for: .seconds(baseDelay), scheduler: DispatchQueue.main)
                    .flatMap { _ in
                        self.retryOnNetworkError(
                            maxRetries: maxRetries - 1,
                            baseDelay: baseDelay * 2
                        )
                    }
                    .eraseToAnyPublisher()
            } else {
                return Fail(error: error)
                    .eraseToAnyPublisher()
            }
        }
        .eraseToAnyPublisher()
    }
}
