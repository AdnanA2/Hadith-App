import Foundation
import Combine

/// Manages user authentication state and operations
class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    // MARK: - Published Properties
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var authError: AuthError?
    
    // MARK: - Private Properties
    
    private let apiService = APIService.shared
    private let keychain = KeychainManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        checkAuthenticationStatus()
    }
    
    // MARK: - Public Methods
    
    /// Check current authentication status on app launch
    func checkAuthenticationStatus() {
        isLoading = true
        
        do {
            if let token = try keychain.getToken(forKey: KeychainManager.Keys.accessToken) {
                // Validate token with backend
                validateToken()
            } else {
                // No token found
                DispatchQueue.main.async {
                    self.isAuthenticated = false
                    self.currentUser = nil
                    self.isLoading = false
                }
            }
        } catch {
            print("Error checking authentication: \(error)")
            DispatchQueue.main.async {
                self.isAuthenticated = false
                self.currentUser = nil
                self.isLoading = false
                self.authError = AuthError.keychainError(error.localizedDescription)
            }
        }
    }
    
    /// Sign up a new user
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - fullName: User's full name
    /// - Returns: Publisher that emits authentication response or error
    func signup(email: String, password: String, fullName: String) -> AnyPublisher<AuthResponse, AuthError> {
        let signupData = SignupRequest(
            email: email,
            password: password,
            full_name: fullName
        )
        
        isLoading = true
        authError = nil
        
        return apiService.post<SignupRequest, AuthResponse>(endpoint: "/auth/signup", body: signupData)
            .handleEvents(
                receiveOutput: { [weak self] response in
                    self?.handleSuccessfulAuth(response)
                },
                receiveCompletion: { [weak self] completion in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                    }
                    
                    if case .failure(let error) = completion {
                        DispatchQueue.main.async {
                            self?.authError = AuthError.from(apiError: error)
                        }
                    }
                }
            )
            .mapError { AuthError.from(apiError: $0) }
            .eraseToAnyPublisher()
    }
    
    /// Log in an existing user
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    /// - Returns: Publisher that emits authentication response or error
    func login(email: String, password: String) -> AnyPublisher<AuthResponse, AuthError> {
        let loginData = LoginRequest(email: email, password: password)
        
        isLoading = true
        authError = nil
        
        return apiService.post<LoginRequest, AuthResponse>(endpoint: "/auth/login", body: loginData)
            .handleEvents(
                receiveOutput: { [weak self] response in
                    self?.handleSuccessfulAuth(response)
                },
                receiveCompletion: { [weak self] completion in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                    }
                    
                    if case .failure(let error) = completion {
                        DispatchQueue.main.async {
                            self?.authError = AuthError.from(apiError: error)
                        }
                    }
                }
            )
            .mapError { AuthError.from(apiError: $0) }
            .eraseToAnyPublisher()
    }
    
    /// Refresh the current access token
    /// - Returns: Publisher that emits refreshed auth response or error
    func refreshToken() -> AnyPublisher<AuthResponse, AuthError> {
        guard isAuthenticated else {
            return Fail(error: AuthError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        return apiService.post<EmptyRequest, AuthResponse>(endpoint: "/auth/refresh", body: EmptyRequest())
            .handleEvents(
                receiveOutput: { [weak self] response in
                    self?.handleSuccessfulAuth(response)
                }
            )
            .mapError { AuthError.from(apiError: $0) }
            .eraseToAnyPublisher()
    }
    
    /// Update current user profile
    /// - Parameter userUpdate: Updated user data
    /// - Returns: Publisher that emits updated user response or error
    func updateProfile(_ userUpdate: UserUpdate) -> AnyPublisher<UserResponse, AuthError> {
        guard isAuthenticated else {
            return Fail(error: AuthError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        return apiService.put<UserUpdate, UserResponse>(endpoint: "/auth/me", body: userUpdate)
            .handleEvents(
                receiveOutput: { [weak self] response in
                    DispatchQueue.main.async {
                        self?.currentUser = response.data
                    }
                }
            )
            .mapError { AuthError.from(apiError: $0) }
            .eraseToAnyPublisher()
    }
    
    /// Get current user profile
    /// - Returns: Publisher that emits user response or error
    func getCurrentUser() -> AnyPublisher<UserResponse, AuthError> {
        guard isAuthenticated else {
            return Fail(error: AuthError.notAuthenticated)
                .eraseToAnyPublisher()
        }
        
        return apiService.get<UserResponse>(endpoint: "/auth/me")
            .handleEvents(
                receiveOutput: { [weak self] response in
                    DispatchQueue.main.async {
                        self?.currentUser = response.data
                    }
                }
            )
            .mapError { AuthError.from(apiError: $0) }
            .eraseToAnyPublisher()
    }
    
    /// Log out the current user
    func logout() {
        do {
            // Clear tokens from keychain
            try keychain.deleteToken(forKey: KeychainManager.Keys.accessToken)
            
            // Clear user state
            DispatchQueue.main.async {
                self.isAuthenticated = false
                self.currentUser = nil
                self.authError = nil
            }
            
            // Cancel any ongoing requests
            cancellables.removeAll()
            
        } catch {
            print("Error during logout: \(error)")
            DispatchQueue.main.async {
                self.authError = AuthError.keychainError(error.localizedDescription)
            }
        }
    }
    
    /// Clear authentication error
    func clearError() {
        DispatchQueue.main.async {
            self.authError = nil
        }
    }
    
    // MARK: - Private Methods
    
    private func validateToken() {
        apiService.get<UserResponse>(endpoint: "/auth/me")
            .sink(
                receiveCompletion: { [weak self] completion in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                    }
                    
                    if case .failure(let error) = completion {
                        print("Token validation failed: \(error)")
                        
                        // If token is invalid, clear authentication state
                        if error.isAuthenticationError {
                            self?.clearAuthenticationState()
                        } else {
                            DispatchQueue.main.async {
                                self?.authError = AuthError.from(apiError: error)
                            }
                        }
                    }
                },
                receiveValue: { [weak self] response in
                    DispatchQueue.main.async {
                        self?.isAuthenticated = true
                        self?.currentUser = response.data
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func handleSuccessfulAuth(_ response: AuthResponse) {
        do {
            // Save token to keychain
            try keychain.saveToken(response.data.access_token, forKey: KeychainManager.Keys.accessToken)
            
            // Update state on main thread
            DispatchQueue.main.async {
                self.isAuthenticated = true
                self.currentUser = response.user
                self.authError = nil
            }
            
        } catch {
            print("Error saving token: \(error)")
            DispatchQueue.main.async {
                self.authError = AuthError.keychainError(error.localizedDescription)
            }
        }
    }
    
    private func clearAuthenticationState() {
        do {
            try keychain.deleteToken(forKey: KeychainManager.Keys.accessToken)
        } catch {
            print("Error clearing token: \(error)")
        }
        
        DispatchQueue.main.async {
            self.isAuthenticated = false
            self.currentUser = nil
        }
    }
}

// MARK: - AuthError

enum AuthError: Error, LocalizedError, Identifiable {
    case invalidCredentials
    case emailAlreadyExists
    case networkError(String)
    case serverError(String)
    case validationError(String, [String]?)
    case keychainError(String)
    case notAuthenticated
    case unknown(String)
    
    var id: String {
        switch self {
        case .invalidCredentials:
            return "invalid_credentials"
        case .emailAlreadyExists:
            return "email_already_exists"
        case .networkError:
            return "network_error"
        case .serverError:
            return "server_error"
        case .validationError:
            return "validation_error"
        case .keychainError:
            return "keychain_error"
        case .notAuthenticated:
            return "not_authenticated"
        case .unknown:
            return "unknown_error"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .emailAlreadyExists:
            return "An account with this email already exists"
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .validationError(let message, _):
            return "Validation error: \(message)"
        case .keychainError(let message):
            return "Security error: \(message)"
        case .notAuthenticated:
            return "You must be logged in to perform this action"
        case .unknown(let message):
            return "An unknown error occurred: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidCredentials:
            return "Please check your email and password and try again"
        case .emailAlreadyExists:
            return "Try logging in instead, or use a different email address"
        case .networkError:
            return "Please check your internet connection and try again"
        case .serverError:
            return "Please try again later"
        case .validationError(_, let details):
            return details?.joined(separator: ", ")
        case .keychainError:
            return "Please try restarting the app"
        case .notAuthenticated:
            return "Please log in to continue"
        case .unknown:
            return "Please try again"
        }
    }
    
    static func from(apiError: APIServiceError) -> AuthError {
        switch apiError {
        case .authenticationError(let message):
            if message.lowercased().contains("incorrect") || message.lowercased().contains("invalid") {
                return .invalidCredentials
            }
            return .serverError(message)
        case .validationError(let message, let details):
            if message.lowercased().contains("already registered") || message.lowercased().contains("already exists") {
                return .emailAlreadyExists
            }
            return .validationError(message, details)
        case .networkError(let error):
            return .networkError(error.localizedDescription)
        case .serverError(_, let message):
            return .serverError(message)
        case .httpError(_, let message):
            return .serverError(message)
        default:
            return .unknown(apiError.localizedDescription)
        }
    }
}

// MARK: - Validation Extensions

extension AuthenticationManager {
    /// Validate email format
    static func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    /// Validate password strength
    static func isValidPassword(_ password: String) -> (isValid: Bool, message: String?) {
        guard password.count >= 8 else {
            return (false, "Password must be at least 8 characters long")
        }
        
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasNumber = password.range(of: "\\d", options: .regularExpression) != nil
        
        if !hasUppercase || !hasLowercase || !hasNumber {
            return (false, "Password must contain uppercase, lowercase, and numeric characters")
        }
        
        return (true, nil)
    }
    
    /// Validate full name
    static func isValidFullName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 2 && trimmed.count <= 100
    }
}
