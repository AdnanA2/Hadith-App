import Foundation
import Combine
import UIKit

/// Centralized error handling and user notification system
class ErrorHandler: ObservableObject {
    static let shared = ErrorHandler()
    
    @Published var currentError: DisplayableError?
    @Published var isShowingError = false
    
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger.shared
    private let monitoringService = MonitoringService.shared
    
    private init() {
        setupErrorObservation()
    }
    
    // MARK: - Public Methods
    
    /// Handle an error and optionally show it to the user
    /// - Parameters:
    ///   - error: The error to handle
    ///   - showToUser: Whether to display the error to the user
    ///   - context: Additional context about where the error occurred
    func handle(_ error: Error, showToUser: Bool = true, context: String? = nil) {
        let displayableError = createDisplayableError(from: error, context: context)
        
        // Log the error
        logError(displayableError)
        
        // Track error for analytics
        monitoringService.trackError(error, context: context)
        
        // Show to user if requested
        if showToUser {
            DispatchQueue.main.async {
                self.currentError = displayableError
                self.isShowingError = true
            }
        }
    }
    
    /// Handle multiple errors (e.g., from parallel network requests)
    /// - Parameters:
    ///   - errors: Array of errors to handle
    ///   - showToUser: Whether to display errors to the user
    ///   - context: Additional context about where the errors occurred
    func handle(_ errors: [Error], showToUser: Bool = true, context: String? = nil) {
        guard !errors.isEmpty else { return }
        
        // Log and track all errors
        errors.forEach { error in
            let displayableError = createDisplayableError(from: error, context: context)
            logError(displayableError)
            monitoringService.trackError(error, context: context)
        }
        
        // Show the most severe error to user
        if showToUser {
            let mostSevere = errors.max { error1, error2 in
                errorSeverity(error1) < errorSeverity(error2)
            }
            
            if let error = mostSevere {
                let displayableError = createDisplayableError(from: error, context: context)
                DispatchQueue.main.async {
                    self.currentError = displayableError
                    self.isShowingError = true
                }
            }
        }
    }
    
    /// Clear the current error
    func clearError() {
        DispatchQueue.main.async {
            self.currentError = nil
            self.isShowingError = false
        }
    }
    
    /// Handle authentication errors specifically
    /// - Parameter error: The authentication error
    func handleAuthError(_ error: AuthError) {
        let displayableError = DisplayableError(
            title: "Authentication Error",
            message: error.localizedDescription,
            severity: .high,
            actionTitle: error.id == "not_authenticated" ? "Log In" : "Try Again",
            action: { [weak self] in
                if error.id == "not_authenticated" {
                    self?.showLoginScreen()
                } else {
                    self?.clearError()
                }
            },
            originalError: error
        )
        
        logError(displayableError)
        monitoringService.trackError(error, context: "authentication")
        sendErrorToAnalytics(displayableError)
        
        DispatchQueue.main.async {
            self.currentError = displayableError
            self.isShowingError = true
        }
    }
    
    /// Handle network connectivity errors
    /// - Parameter error: The network error
    func handleNetworkError(_ error: Error) {
        let isOffline = isNetworkUnavailable(error)
        
        let displayableError = DisplayableError(
            title: isOffline ? "No Internet Connection" : "Network Error",
            message: isOffline ? "Please check your internet connection and try again." : error.localizedDescription,
            severity: isOffline ? .medium : .high,
            actionTitle: "Retry",
            action: { [weak self] in
                self?.clearError()
                // Could trigger a retry mechanism here
            },
            originalError: error
        )
        
        logError(displayableError)
        
        DispatchQueue.main.async {
            self.currentError = displayableError
            self.isShowingError = true
        }
    }
    
    // MARK: - Private Methods
    
    private func setupErrorObservation() {
        // Observe authentication manager errors
        AuthenticationManager.shared.$authError
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.handleAuthError(error)
            }
            .store(in: &cancellables)
    }
    
    private func createDisplayableError(from error: Error, context: String?) -> DisplayableError {
        var title = "Error"
        var message = error.localizedDescription
        var severity = ErrorSeverity.medium
        var actionTitle = "OK"
        var action: (() -> Void)? = { [weak self] in self?.clearError() }
        
        // Customize based on error type
        switch error {
        case let apiError as APIServiceError:
            title = "Service Error"
            severity = apiError.isAuthenticationError ? .high : .medium
            if apiError.isAuthenticationError {
                actionTitle = "Log In"
                action = { [weak self] in self?.showLoginScreen() }
            }
            
        case let authError as AuthError:
            title = "Authentication Error"
            severity = .high
            if authError.id == "not_authenticated" {
                actionTitle = "Log In"
                action = { [weak self] in self?.showLoginScreen() }
            }
            
        case let hadithError as HadithServiceError:
            title = "Content Error"
            severity = hadithError.id == "authentication_required" ? .high : .medium
            
        case let keychainError as KeychainError:
            title = "Security Error"
            severity = .high
            message = keychainError.localizedDescription
            
        case is URLError:
            title = "Network Error"
            severity = .medium
            actionTitle = "Retry"
            
        default:
            title = "Unexpected Error"
            severity = .low
        }
        
        // Add context if provided
        if let context = context {
            message = "\(message)\n\nContext: \(context)"
        }
        
        return DisplayableError(
            title: title,
            message: message,
            severity: severity,
            actionTitle: actionTitle,
            action: action,
            originalError: error
        )
    }
    
    private func logError(_ error: DisplayableError) {
        logger.error("\(error.title): \(error.message)")
        if let originalError = error.originalError {
            logger.error("Original error: \(originalError)")
        }
    }
    

    

    
    private func errorSeverity(_ error: Error) -> Int {
        switch error {
        case is AuthError:
            return 3
        case let apiError as APIServiceError:
            return apiError.isAuthenticationError ? 3 : 2
        case is KeychainError:
            return 3
        case is URLError:
            return 2
        default:
            return 1
        }
    }
    
    private func isNetworkUnavailable(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost:
                return true
            default:
                return false
            }
        }
        return false
    }
    
    private func showLoginScreen() {
        // This would typically trigger navigation to the login screen
        // Implementation depends on your navigation system (SwiftUI, UIKit, etc.)
        NotificationCenter.default.post(name: .showLoginScreen, object: nil)
    }
}

// MARK: - DisplayableError

struct DisplayableError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let severity: ErrorSeverity
    let actionTitle: String
    let action: (() -> Void)?
    let originalError: Error
    
    var shouldShowToUser: Bool {
        return severity != .low
    }
}

// MARK: - ErrorSeverity

enum ErrorSeverity: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var icon: String {
        switch self {
        case .low:
            return "ℹ️"
        case .medium:
            return "⚠️"
        case .high:
            return "❌"
        case .critical:
            return "🚨"
        }
    }
    
    var color: String {
        switch self {
        case .low:
            return "blue"
        case .medium:
            return "orange"
        case .high:
            return "red"
        case .critical:
            return "purple"
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let showLoginScreen = Notification.Name("showLoginScreen")
    static let errorOccurred = Notification.Name("errorOccurred")
}

// MARK: - DateFormatter Extensions

extension DateFormatter {
    static let logTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - Error Recovery Helpers

extension ErrorHandler {
    /// Attempt to recover from common errors automatically
    /// - Parameter error: The error to attempt recovery from
    /// - Returns: True if recovery was attempted, false otherwise
    func attemptAutomaticRecovery(from error: Error) -> Bool {
        switch error {
        case let apiError as APIServiceError:
            if apiError.isAuthenticationError {
                // Attempt token refresh
                AuthenticationManager.shared.refreshToken()
                    .sink(
                        receiveCompletion: { _ in },
                        receiveValue: { _ in
                            self.clearError()
                        }
                    )
                    .store(in: &cancellables)
                return true
            }
            
        case is URLError:
            // For network errors, we could implement retry logic
            // This is just a placeholder
            return false
            
        default:
            return false
        }
        
        return false
    }
    
    /// Get error statistics for debugging
    func getErrorStatistics() -> [String: Any] {
        // In a real implementation, you'd track error counts, types, etc.
        return [
            "total_errors": 0,
            "auth_errors": 0,
            "network_errors": 0,
            "last_error_time": Date()
        ]
    }
}

// MARK: - SwiftUI Integration Helpers

#if canImport(SwiftUI)
import SwiftUI

extension ErrorHandler {
    /// Create an Alert from the current error for SwiftUI
    func createAlert() -> Alert {
        guard let error = currentError else {
            return Alert(title: Text("Unknown Error"))
        }
        
        if let action = error.action {
            return Alert(
                title: Text(error.title),
                message: Text(error.message),
                primaryButton: .default(Text(error.actionTitle), action: action),
                secondaryButton: .cancel()
            )
        } else {
            return Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text(error.actionTitle)) {
                    self.clearError()
                }
            )
        }
    }
}
#endif