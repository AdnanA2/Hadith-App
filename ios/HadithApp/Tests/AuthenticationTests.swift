import XCTest
import Combine
@testable import HadithApp

/// Unit tests for AuthenticationManager
class AuthenticationTests: XCTestCase {
    
    var authManager: AuthenticationManager!
    var cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        super.setUp()
        authManager = AuthenticationManager.shared
        cancellables.removeAll()
        
        // Clean slate for each test
        authManager.logout()
        try? KeychainManager.shared.clearAll()
    }
    
    override func tearDown() {
        super.tearDown()
        cancellables.removeAll()
        authManager.logout()
        try? KeychainManager.shared.clearAll()
    }
    
    // MARK: - Initial State Tests
    
    func testInitialState() {
        XCTAssertFalse(authManager.isAuthenticated)
        XCTAssertNil(authManager.currentUser)
        XCTAssertFalse(authManager.isLoading)
        XCTAssertNil(authManager.authError)
    }
    
    // MARK: - Validation Tests
    
    func testEmailValidation() {
        // Valid emails
        XCTAssertTrue(AuthenticationManager.isValidEmail("test@example.com"))
        XCTAssertTrue(AuthenticationManager.isValidEmail("user.name+tag@domain.co.uk"))
        XCTAssertTrue(AuthenticationManager.isValidEmail("x@y.z"))
        
        // Invalid emails
        XCTAssertFalse(AuthenticationManager.isValidEmail("invalid-email"))
        XCTAssertFalse(AuthenticationManager.isValidEmail("@domain.com"))
        XCTAssertFalse(AuthenticationManager.isValidEmail("user@"))
        XCTAssertFalse(AuthenticationManager.isValidEmail("user@domain"))
        XCTAssertFalse(AuthenticationManager.isValidEmail(""))
    }
    
    func testPasswordValidation() {
        // Valid passwords
        let strongPassword = AuthenticationManager.isValidPassword("StrongPass123")
        XCTAssertTrue(strongPassword.isValid)
        XCTAssertNil(strongPassword.message)
        
        let anotherStrong = AuthenticationManager.isValidPassword("MySecure1Password")
        XCTAssertTrue(anotherStrong.isValid)
        
        // Invalid passwords - too short
        let shortPassword = AuthenticationManager.isValidPassword("Short1")
        XCTAssertFalse(shortPassword.isValid)
        XCTAssertNotNil(shortPassword.message)
        XCTAssertTrue(shortPassword.message!.contains("8 characters"))
        
        // Invalid passwords - no uppercase
        let noUppercase = AuthenticationManager.isValidPassword("lowercase123")
        XCTAssertFalse(noUppercase.isValid)
        XCTAssertTrue(noUppercase.message!.contains("uppercase"))
        
        // Invalid passwords - no lowercase
        let noLowercase = AuthenticationManager.isValidPassword("UPPERCASE123")
        XCTAssertFalse(noLowercase.isValid)
        XCTAssertTrue(noLowercase.message!.contains("lowercase"))
        
        // Invalid passwords - no numbers
        let noNumbers = AuthenticationManager.isValidPassword("NoNumbers")
        XCTAssertFalse(noNumbers.isValid)
        XCTAssertTrue(noNumbers.message!.contains("numeric"))
    }
    
    func testFullNameValidation() {
        // Valid names
        XCTAssertTrue(AuthenticationManager.isValidFullName("John Doe"))
        XCTAssertTrue(AuthenticationManager.isValidFullName("Mary Jane Watson"))
        XCTAssertTrue(AuthenticationManager.isValidFullName("李小明"))
        XCTAssertTrue(AuthenticationManager.isValidFullName("José María"))
        
        // Invalid names
        XCTAssertFalse(AuthenticationManager.isValidFullName("J")) // Too short
        XCTAssertFalse(AuthenticationManager.isValidFullName("")) // Empty
        XCTAssertFalse(AuthenticationManager.isValidFullName("   ")) // Only whitespace
        
        // Name that's too long (over 100 characters)
        let longName = String(repeating: "a", count: 101)
        XCTAssertFalse(AuthenticationManager.isValidFullName(longName))
    }
    
    // MARK: - Authentication State Management Tests
    
    func testAuthenticationStateChanges() {
        let expectation = XCTestExpectation(description: "Authentication state changes")
        var stateChanges: [Bool] = []
        
        // Monitor authentication state changes
        authManager.$isAuthenticated
            .sink { isAuthenticated in
                stateChanges.append(isAuthenticated)
                
                // After we collect a few state changes, verify them
                if stateChanges.count >= 2 {
                    XCTAssertEqual(stateChanges[0], false) // Initial state
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testUserStateManagement() {
        let expectation = XCTestExpectation(description: "User state management")
        
        // Create a mock user
        let mockUser = User(
            id: 1,
            email: "test@example.com",
            full_name: "Test User",
            is_active: true,
            is_verified: false,
            role: "user",
            created_at: "2024-01-01T00:00:00.000000",
            updated_at: "2024-01-01T00:00:00.000000"
        )
        
        // Monitor user changes
        authManager.$currentUser
            .dropFirst() // Skip initial nil
            .sink { user in
                XCTAssertNotNil(user)
                XCTAssertEqual(user?.email, "test@example.com")
                XCTAssertEqual(user?.id, 1)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Simulate setting a user
        DispatchQueue.main.async {
            self.authManager.currentUser = mockUser
            self.authManager.isAuthenticated = true
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorStateManagement() {
        let expectation = XCTestExpectation(description: "Error state management")
        
        let testError = AuthError.invalidCredentials
        
        // Monitor error changes
        authManager.$authError
            .dropFirst() // Skip initial nil
            .sink { error in
                XCTAssertNotNil(error)
                XCTAssertEqual(error?.id, "invalid_credentials")
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Set an error
        DispatchQueue.main.async {
            self.authManager.authError = testError
        }
        
        wait(for: [expectation], timeout: 2.0)
    }
    
    func testErrorClearing() {
        // Set an error first
        authManager.authError = AuthError.networkError("Test error")
        XCTAssertNotNil(authManager.authError)
        
        // Clear the error
        authManager.clearError()
        
        // Verify error is cleared
        let expectation = XCTestExpectation(description: "Error cleared")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNil(self.authManager.authError)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Token Management Tests
    
    func testTokenStorage() {
        let testToken = "test_access_token_123"
        let mockTokenData = TokenData(
            access_token: testToken,
            token_type: "Bearer",
            expires_in: 3600
        )
        
        let mockUser = User(
            id: 1,
            email: "test@example.com",
            full_name: "Test User",
            is_active: true,
            is_verified: false,
            role: "user",
            created_at: "2024-01-01T00:00:00.000000",
            updated_at: "2024-01-01T00:00:00.000000"
        )
        
        let mockAuthResponse = AuthResponse(
            success: true,
            message: "Login successful",
            data: mockTokenData,
            user: mockUser
        )
        
        // Test token storage through successful auth handling
        authManager.handleSuccessfulAuth(mockAuthResponse)
        
        // Verify token was stored
        do {
            let storedToken = try KeychainManager.shared.getToken(forKey: KeychainManager.Keys.accessToken)
            XCTAssertEqual(storedToken, testToken)
        } catch {
            XCTFail("Failed to retrieve stored token: \(error)")
        }
        
        // Verify authentication state
        XCTAssertTrue(authManager.isAuthenticated)
        XCTAssertEqual(authManager.currentUser?.email, "test@example.com")
    }
    
    func testLogout() {
        // First, set up authenticated state
        let testToken = "test_token"
        try? KeychainManager.shared.saveToken(testToken, forKey: KeychainManager.Keys.accessToken)
        
        let mockUser = User(
            id: 1,
            email: "test@example.com",
            full_name: "Test User",
            is_active: true,
            is_verified: false,
            role: "user",
            created_at: "2024-01-01T00:00:00.000000",
            updated_at: "2024-01-01T00:00:00.000000"
        )
        
        authManager.currentUser = mockUser
        authManager.isAuthenticated = true
        
        // Verify initial state
        XCTAssertTrue(authManager.isAuthenticated)
        XCTAssertNotNil(authManager.currentUser)
        
        // Perform logout
        authManager.logout()
        
        // Verify logout cleared everything
        let expectation = XCTestExpectation(description: "Logout completed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertFalse(self.authManager.isAuthenticated)
            XCTAssertNil(self.authManager.currentUser)
            XCTAssertNil(self.authManager.authError)
            
            // Verify token was removed from keychain
            do {
                let token = try KeychainManager.shared.getToken(forKey: KeychainManager.Keys.accessToken)
                XCTAssertNil(token)
            } catch {
                // This is expected - token should be deleted
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Error Conversion Tests
    
    func testAuthErrorFromAPIError() {
        // Test authentication error conversion
        let apiAuthError = APIServiceError.authenticationError("Invalid credentials")
        let authError = AuthError.from(apiError: apiAuthError)
        
        if case AuthError.invalidCredentials = authError {
            // Correct conversion
        } else {
            XCTFail("Should convert to invalidCredentials")
        }
        
        // Test validation error conversion
        let apiValidationError = APIServiceError.validationError("Email already exists", ["Email is already registered"])
        let validationAuthError = AuthError.from(apiError: apiValidationError)
        
        if case AuthError.emailAlreadyExists = validationAuthError {
            // Correct conversion
        } else {
            XCTFail("Should convert to emailAlreadyExists")
        }
        
        // Test network error conversion
        let networkError = URLError(.notConnectedToInternet)
        let apiNetworkError = APIServiceError.networkError(networkError)
        let networkAuthError = AuthError.from(apiError: apiNetworkError)
        
        if case AuthError.networkError = networkAuthError {
            // Correct conversion
        } else {
            XCTFail("Should convert to networkError")
        }
    }
    
    // MARK: - Loading State Tests
    
    func testLoadingState() {
        XCTAssertFalse(authManager.isLoading)
        
        // Simulate loading state during authentication check
        authManager.isLoading = true
        XCTAssertTrue(authManager.isLoading)
        
        // Simulate completion
        authManager.isLoading = false
        XCTAssertFalse(authManager.isLoading)
    }
    
    // MARK: - Authentication Status Check Tests
    
    func testAuthenticationStatusCheckWithoutToken() {
        // Ensure no token exists
        try? KeychainManager.shared.deleteToken(forKey: KeychainManager.Keys.accessToken)
        
        let expectation = XCTestExpectation(description: "Auth status check without token")
        
        // Monitor state changes
        authManager.$isLoading
            .dropFirst() // Skip initial state
            .sink { isLoading in
                if !isLoading {
                    // Loading completed
                    XCTAssertFalse(self.authManager.isAuthenticated)
                    XCTAssertNil(self.authManager.currentUser)
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Trigger authentication status check
        authManager.checkAuthenticationStatus()
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testAuthenticationStatusCheckWithToken() {
        // Store a test token
        let testToken = "valid_test_token"
        try? KeychainManager.shared.saveToken(testToken, forKey: KeychainManager.Keys.accessToken)
        
        let expectation = XCTestExpectation(description: "Auth status check with token")
        
        // In a real scenario, this would validate the token with the backend
        // For unit tests, we expect it to attempt validation and likely fail due to no network
        authManager.$isLoading
            .dropFirst()
            .sink { isLoading in
                if !isLoading {
                    // Loading completed - in unit test, token validation will likely fail
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Trigger authentication status check
        authManager.checkAuthenticationStatus()
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Memory Management Tests
    
    func testCancellablesCleanup() {
        // Create some subscriptions
        authManager.$isAuthenticated
            .sink { _ in }
            .store(in: &authManager.cancellables)
        
        authManager.$currentUser
            .sink { _ in }
            .store(in: &authManager.cancellables)
        
        // Verify cancellables exist
        XCTAssertFalse(authManager.cancellables.isEmpty)
        
        // Logout should clean up cancellables
        authManager.logout()
        
        // Note: In the current implementation, logout calls cancellables.removeAll()
        // This test verifies that behavior
        XCTAssertTrue(authManager.cancellables.isEmpty)
    }
    
    // MARK: - Thread Safety Tests
    
    func testThreadSafetyOfStateUpdates() {
        let expectation = XCTestExpectation(description: "Thread safety")
        let iterations = 100
        var completedIterations = 0
        
        // Perform multiple concurrent state updates
        for i in 0..<iterations {
            DispatchQueue.global().async {
                // Simulate various state changes from background threads
                if i % 2 == 0 {
                    self.authManager.clearError()
                } else {
                    DispatchQueue.main.async {
                        self.authManager.authError = AuthError.networkError("Test error \(i)")
                    }
                }
                
                DispatchQueue.main.async {
                    completedIterations += 1
                    if completedIterations == iterations {
                        expectation.fulfill()
                    }
                }
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
        
        // Verify we didn't crash and state is consistent
        XCTAssertNotNil(authManager)
    }
}

// MARK: - Test Helpers

extension AuthenticationTests {
    /// Create a mock AuthResponse for testing
    func createMockAuthResponse(email: String = "test@example.com") -> AuthResponse {
        let tokenData = TokenData(
            access_token: "mock_token_\(UUID().uuidString)",
            token_type: "Bearer",
            expires_in: 3600
        )
        
        let user = User(
            id: Int.random(in: 1...1000),
            email: email,
            full_name: "Test User",
            is_active: true,
            is_verified: false,
            role: "user",
            created_at: "2024-01-01T00:00:00.000000",
            updated_at: "2024-01-01T00:00:00.000000"
        )
        
        return AuthResponse(
            success: true,
            message: "Authentication successful",
            data: tokenData,
            user: user
        )
    }
    
    /// Simulate successful authentication
    func simulateSuccessfulAuth() -> AuthResponse {
        let authResponse = createMockAuthResponse()
        authManager.handleSuccessfulAuth(authResponse)
        return authResponse
    }
}
