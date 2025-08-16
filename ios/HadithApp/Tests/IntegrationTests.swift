import XCTest
import Combine
@testable import HadithApp

/// Integration tests for Auth + API layer
class IntegrationTests: XCTestCase {
    
    var cancellables = Set<AnyCancellable>()
    var authManager: AuthenticationManager!
    var hadithService: HadithService!
    var apiService: APIService!
    
    override func setUp() {
        super.setUp()
        cancellables.removeAll()
        
        // Use test environment
        authManager = AuthenticationManager.shared
        hadithService = HadithService.shared
        apiService = APIService.shared
        
        // Ensure clean state
        authManager.logout()
    }
    
    override func tearDown() {
        super.tearDown()
        cancellables.removeAll()
        authManager.logout()
    }
    
    // MARK: - Authentication Tests
    
    func testAuthenticationFlow() {
        let expectation = XCTestExpectation(description: "Authentication flow")
        
        // Test signup -> login -> profile -> logout
        let testEmail = "test\(Int.random(in: 1000...9999))@example.com"
        let testPassword = "TestPassword123"
        let testName = "Test User"
        
        authManager.signup(email: testEmail, password: testPassword, fullName: testName)
            .flatMap { _ in
                // Verify we're authenticated
                XCTAssertTrue(self.authManager.isAuthenticated)
                XCTAssertNotNil(self.authManager.currentUser)
                XCTAssertEqual(self.authManager.currentUser?.email, testEmail)
                
                // Test profile update
                let update = UserUpdate(full_name: "Updated Name", password: nil)
                return self.authManager.updateProfile(update)
            }
            .flatMap { _ in
                // Verify profile was updated
                XCTAssertEqual(self.authManager.currentUser?.full_name, "Updated Name")
                
                // Test token refresh
                return self.authManager.refreshToken()
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Authentication flow failed: \(error)")
                    }
                    expectation.fulfill()
                },
                receiveValue: { _ in
                    // Verify we're still authenticated after refresh
                    XCTAssertTrue(self.authManager.isAuthenticated)
                    XCTAssertNotNil(self.authManager.currentUser)
                    
                    // Test logout
                    self.authManager.logout()
                    XCTAssertFalse(self.authManager.isAuthenticated)
                    XCTAssertNil(self.authManager.currentUser)
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 30.0)
    }
    
    func testLoginWithInvalidCredentials() {
        let expectation = XCTestExpectation(description: "Invalid login")
        
        authManager.login(email: "invalid@example.com", password: "wrongpassword")
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTAssertEqual(error, AuthError.invalidCredentials)
                        XCTAssertFalse(self.authManager.isAuthenticated)
                        expectation.fulfill()
                    } else {
                        XCTFail("Expected login to fail")
                    }
                },
                receiveValue: { _ in
                    XCTFail("Login should have failed")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 15.0)
    }
    
    // MARK: - Hadith Service Tests
    
    func testHadithServiceEndpoints() {
        let expectation = XCTestExpectation(description: "Hadith service endpoints")
        
        // Test public endpoints (no auth required)
        hadithService.getCollections(page: 1, pageSize: 5)
            .flatMap { collectionsResponse in
                XCTAssertTrue(collectionsResponse.success)
                XCTAssertFalse(collectionsResponse.data.isEmpty)
                
                // Test hadiths endpoint
                return self.hadithService.getHadiths(page: 1, pageSize: 5)
            }
            .flatMap { hadithsResponse in
                XCTAssertTrue(hadithsResponse.success)
                XCTAssertFalse(hadithsResponse.data.isEmpty)
                
                // Test daily hadith
                return self.hadithService.getDailyHadith()
            }
            .flatMap { dailyResponse in
                XCTAssertTrue(dailyResponse.success)
                XCTAssertNotNil(dailyResponse.data)
                
                // Test random hadith
                return self.hadithService.getRandomHadith()
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Hadith service test failed: \(error)")
                    }
                    expectation.fulfill()
                },
                receiveValue: { randomResponse in
                    XCTAssertTrue(randomResponse.success)
                    XCTAssertNotNil(randomResponse.data)
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 20.0)
    }
    
    func testSearchFunctionality() {
        let expectation = XCTestExpectation(description: "Search functionality")
        
        hadithService.searchHadiths(query: "prayer", page: 1, pageSize: 10)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Search test failed: \(error)")
                    }
                    expectation.fulfill()
                },
                receiveValue: { searchResponse in
                    XCTAssertTrue(searchResponse.success)
                    // Results may be empty, but response should be valid
                    XCTAssertNotNil(searchResponse.data)
                    XCTAssertNotNil(searchResponse.meta)
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 15.0)
    }
    
    // MARK: - Authenticated Endpoints Tests
    
    func testAuthenticatedEndpoints() {
        let expectation = XCTestExpectation(description: "Authenticated endpoints")
        
        // First authenticate
        let testEmail = "authtest\(Int.random(in: 1000...9999))@example.com"
        let testPassword = "TestPassword123"
        
        authManager.signup(email: testEmail, password: testPassword, fullName: "Auth Test User")
            .flatMap { _ in
                // Test getting favorites (should be empty initially)
                return self.hadithService.getFavorites()
            }
            .flatMap { favoritesResponse in
                XCTAssertTrue(favoritesResponse.success)
                XCTAssertTrue(favoritesResponse.data.isEmpty) // Should be empty for new user
                
                // Get a hadith to favorite
                return self.hadithService.getHadiths(page: 1, pageSize: 1)
            }
            .flatMap { hadithsResponse in
                guard let firstHadith = hadithsResponse.data.first else {
                    throw HadithServiceError.notFound("No hadiths available")
                }
                
                // Add to favorites
                return self.hadithService.addFavorite(hadithId: firstHadith.id, notes: "Test favorite")
            }
            .flatMap { favoriteResponse in
                XCTAssertTrue(favoriteResponse.success)
                XCTAssertEqual(favoriteResponse.data.notes, "Test favorite")
                
                // Verify favorites list now contains the item
                return self.hadithService.getFavorites()
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Authenticated endpoints test failed: \(error)")
                    }
                    expectation.fulfill()
                },
                receiveValue: { favoritesResponse in
                    XCTAssertTrue(favoritesResponse.success)
                    XCTAssertEqual(favoritesResponse.data.count, 1)
                    XCTAssertEqual(favoritesResponse.data.first?.notes, "Test favorite")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 30.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandling() {
        let expectation = XCTestExpectation(description: "Error handling")
        
        // Test unauthorized access to protected endpoint
        hadithService.getFavorites()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTAssertEqual(error, HadithServiceError.authenticationRequired)
                        expectation.fulfill()
                    } else {
                        XCTFail("Expected authentication error")
                    }
                },
                receiveValue: { _ in
                    XCTFail("Should have failed with authentication error")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testNetworkErrorHandling() {
        let expectation = XCTestExpectation(description: "Network error handling")
        
        // Test with invalid endpoint
        apiService.get<HadithsResponse>(endpoint: "/invalid-endpoint")
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTAssertTrue(error is APIServiceError)
                        expectation.fulfill()
                    } else {
                        XCTFail("Expected network error")
                    }
                },
                receiveValue: { _ in
                    XCTFail("Should have failed with network error")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - End-to-End Integration Test
    
    func testEndToEndFlow() {
        let expectation = XCTestExpectation(description: "End-to-end flow")
        
        let testEmail = "e2e\(Int.random(in: 1000...9999))@example.com"
        let testPassword = "TestPassword123"
        
        // Complete user journey: signup -> browse -> search -> favorite -> logout
        authManager.signup(email: testEmail, password: testPassword, fullName: "E2E Test User")
            .flatMap { _ in
                // Browse collections
                return self.hadithService.getCollections()
            }
            .flatMap { collectionsResponse in
                XCTAssertFalse(collectionsResponse.data.isEmpty)
                
                // Get daily hadith
                return self.hadithService.getDailyHadith()
            }
            .flatMap { dailyResponse in
                XCTAssertNotNil(dailyResponse.data)
                
                // Search for hadiths
                return self.hadithService.searchHadiths(query: "Allah")
            }
            .flatMap { searchResponse in
                // Favorite the first search result (if any)
                if let firstHadith = searchResponse.data.first {
                    return self.hadithService.addFavorite(hadithId: firstHadith.id)
                } else {
                    // If no search results, get any hadith and favorite it
                    return self.hadithService.getHadiths(page: 1, pageSize: 1)
                        .flatMap { hadithsResponse in
                            guard let firstHadith = hadithsResponse.data.first else {
                                throw HadithServiceError.notFound("No hadiths available")
                            }
                            return self.hadithService.addFavorite(hadithId: firstHadith.id)
                        }
                        .eraseToAnyPublisher()
                }
            }
            .flatMap { _ in
                // Verify favorites
                return self.hadithService.getFavorites()
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("End-to-end test failed: \(error)")
                    }
                    
                    // Logout at the end
                    self.authManager.logout()
                    XCTAssertFalse(self.authManager.isAuthenticated)
                    
                    expectation.fulfill()
                },
                receiveValue: { favoritesResponse in
                    XCTAssertTrue(favoritesResponse.success)
                    XCTAssertFalse(favoritesResponse.data.isEmpty)
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 45.0)
    }
    
    // MARK: - Performance Tests
    
    func testAPIPerformance() {
        measure {
            let expectation = XCTestExpectation(description: "API performance")
            
            hadithService.getHadiths(page: 1, pageSize: 20)
                .sink(
                    receiveCompletion: { _ in expectation.fulfill() },
                    receiveValue: { _ in }
                )
                .store(in: &cancellables)
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    // MARK: - Validation Tests
    
    func testInputValidation() {
        // Test email validation
        XCTAssertTrue(AuthenticationManager.isValidEmail("test@example.com"))
        XCTAssertFalse(AuthenticationManager.isValidEmail("invalid-email"))
        
        // Test password validation
        let strongPassword = AuthenticationManager.isValidPassword("StrongPass123")
        XCTAssertTrue(strongPassword.isValid)
        
        let weakPassword = AuthenticationManager.isValidPassword("weak")
        XCTAssertFalse(weakPassword.isValid)
        XCTAssertNotNil(weakPassword.message)
        
        // Test name validation
        XCTAssertTrue(AuthenticationManager.isValidFullName("John Doe"))
        XCTAssertFalse(AuthenticationManager.isValidFullName("J"))
    }
}

// MARK: - Mock Data Helpers

extension IntegrationTests {
    
    func createTestUser() -> (email: String, password: String, name: String) {
        let timestamp = Int(Date().timeIntervalSince1970)
        return (
            email: "test\(timestamp)@example.com",
            password: "TestPassword123",
            name: "Test User \(timestamp)"
        )
    }
}

// MARK: - Test Configuration

extension IntegrationTests {
    
    /// Configure test environment
    override class func setUp() {
        super.setUp()
        
        // Set test configuration
        // In a real app, you might want to use a test backend URL
        print("🧪 Running integration tests with backend: \(Environment.baseURL)")
    }
}
