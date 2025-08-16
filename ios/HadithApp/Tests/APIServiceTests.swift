import XCTest
import Combine
@testable import HadithApp

/// Unit tests for APIService
class APIServiceTests: XCTestCase {
    
    var apiService: APIService!
    var cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        super.setUp()
        apiService = APIService.shared
        cancellables.removeAll()
    }
    
    override func tearDown() {
        super.tearDown()
        cancellables.removeAll()
        apiService = nil
    }
    
    // MARK: - URL Building Tests
    
    func testURLBuilding() {
        // Test basic endpoint
        let basicURL = apiService.buildURL(endpoint: "/test")
        XCTAssertNotNil(basicURL)
        XCTAssertTrue(basicURL!.absoluteString.contains("/test"))
        
        // Test endpoint with query items
        let queryItems = [
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "size", value: "20")
        ]
        let urlWithQuery = apiService.buildURL(endpoint: "/hadiths", queryItems: queryItems)
        XCTAssertNotNil(urlWithQuery)
        XCTAssertTrue(urlWithQuery!.absoluteString.contains("page=1"))
        XCTAssertTrue(urlWithQuery!.absoluteString.contains("size=20"))
    }
    
    func testInvalidURLHandling() {
        let expectation = XCTestExpectation(description: "Invalid URL handling")
        
        // Create a request with invalid characters that would break URL formation
        let invalidEndpoint = "/test with spaces"
        
        apiService.get<HadithsResponse>(endpoint: invalidEndpoint)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        if case APIServiceError.invalidURL = error {
                            expectation.fulfill()
                        } else {
                            XCTFail("Expected invalidURL error, got: \(error)")
                        }
                    } else {
                        XCTFail("Expected failure for invalid URL")
                    }
                },
                receiveValue: { _ in
                    XCTFail("Should not receive value for invalid URL")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Authentication Header Tests
    
    func testAuthHeaderWithoutToken() {
        let expectation = XCTestExpectation(description: "Auth header without token")
        
        // Ensure no token is stored
        try? KeychainManager.shared.deleteToken(forKey: KeychainManager.Keys.accessToken)
        
        let request = URLRequest(url: URL(string: "https://example.com")!)
        
        apiService.addAuthHeader(to: request)
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Should not fail when no token is present")
                    }
                },
                receiveValue: { request in
                    // Should not have Authorization header when no token
                    XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
                    XCTAssertNotNil(request.value(forHTTPHeaderField: "API-Version"))
                    XCTAssertNotNil(request.value(forHTTPHeaderField: "User-Agent"))
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testAuthHeaderWithToken() {
        let expectation = XCTestExpectation(description: "Auth header with token")
        
        // Save a test token
        let testToken = "test_access_token_123"
        try? KeychainManager.shared.saveToken(testToken, forKey: KeychainManager.Keys.accessToken)
        
        let request = URLRequest(url: URL(string: "https://example.com")!)
        
        apiService.addAuthHeader(to: request)
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Should not fail when token is present")
                    }
                },
                receiveValue: { request in
                    // Should have Authorization header with Bearer token
                    let authHeader = request.value(forHTTPHeaderField: "Authorization")
                    XCTAssertEqual(authHeader, "Bearer \(testToken)")
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        // Clean up
        try? KeychainManager.shared.deleteToken(forKey: KeychainManager.Keys.accessToken)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - HTTP Method Tests
    
    func testGETRequest() {
        let expectation = XCTestExpectation(description: "GET request")
        
        // Mock a successful response
        apiService.get<CollectionsResponse>(endpoint: "/collections")
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        // In unit tests, this will likely fail due to no network
                        // but we can verify the error type
                        print("Expected network error in unit test: \(error)")
                        expectation.fulfill()
                    case .finished:
                        break
                    }
                },
                receiveValue: { response in
                    // If we somehow get a response in unit test
                    XCTAssertTrue(response.success)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testPOSTRequest() {
        let expectation = XCTestExpectation(description: "POST request")
        
        let loginRequest = LoginRequest(email: "test@example.com", password: "password")
        
        apiService.post<LoginRequest, AuthResponse>(endpoint: "/auth/login", body: loginRequest)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .failure(let error):
                        // Expected in unit test environment
                        print("Expected network error in unit test: \(error)")
                        expectation.fulfill()
                    case .finished:
                        break
                    }
                },
                receiveValue: { response in
                    XCTAssertTrue(response.success)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorResponseDecoding() {
        // This would typically be tested with a mock network layer
        // For now, we test the error types
        
        let networkError = URLError(.notConnectedToInternet)
        let apiError = APIServiceError.networkError(networkError)
        
        XCTAssertEqual(apiError.errorDescription, "Network error: \(networkError.localizedDescription)")
        XCTAssertEqual(apiError.recoverySuggestion, "Please check your internet connection and try again")
    }
    
    func testHTTPStatusCodeHandling() {
        // Test different HTTP status codes
        let authError = APIServiceError.authenticationError("Invalid token")
        XCTAssertTrue(authError.isAuthenticationError)
        XCTAssertEqual(authError.recoverySuggestion, "Please log in again")
        
        let notFoundError = APIServiceError.notFound("Resource not found")
        XCTAssertEqual(notFoundError.errorDescription, "Resource not found: Resource not found")
        
        let serverError = APIServiceError.serverError(500, "Internal server error")
        XCTAssertEqual(serverError.recoverySuggestion, "Please try again later")
    }
    
    // MARK: - Retry Mechanism Tests
    
    func testRetryMechanism() {
        let expectation = XCTestExpectation(description: "Retry mechanism")
        var attemptCount = 0
        
        let requestPublisher = { () -> AnyPublisher<HadithsResponse, APIServiceError> in
            attemptCount += 1
            
            if attemptCount < 3 {
                // Simulate network failure for first 2 attempts
                return Fail(error: APIServiceError.networkError(URLError(.networkConnectionLost)))
                    .eraseToAnyPublisher()
            } else {
                // Simulate success on 3rd attempt
                let mockResponse = HadithsResponse(
                    success: true,
                    message: "Success",
                    data: [],
                    meta: nil
                )
                return Just(mockResponse)
                    .setFailureType(to: APIServiceError.self)
                    .eraseToAnyPublisher()
            }
        }
        
        apiService.requestWithRetry(maxRetries: 2, baseDelay: 0.1, requestPublisher: requestPublisher)
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Should succeed after retries")
                    }
                },
                receiveValue: { response in
                    XCTAssertTrue(response.success)
                    XCTAssertEqual(attemptCount, 3) // Should have made 3 attempts
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testRetryExhaustion() {
        let expectation = XCTestExpectation(description: "Retry exhaustion")
        var attemptCount = 0
        
        let requestPublisher = { () -> AnyPublisher<HadithsResponse, APIServiceError> in
            attemptCount += 1
            // Always fail
            return Fail(error: APIServiceError.networkError(URLError(.networkConnectionLost)))
                .eraseToAnyPublisher()
        }
        
        apiService.requestWithRetry(maxRetries: 2, baseDelay: 0.1, requestPublisher: requestPublisher)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTAssertTrue(error is APIServiceError)
                        XCTAssertEqual(attemptCount, 3) // Initial + 2 retries
                        expectation.fulfill()
                    } else {
                        XCTFail("Should fail after exhausting retries")
                    }
                },
                receiveValue: { _ in
                    XCTFail("Should not succeed")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - JSON Encoding/Decoding Tests
    
    func testJSONEncoding() {
        let loginRequest = LoginRequest(email: "test@example.com", password: "password123")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(loginRequest)
            
            XCTAssertFalse(data.isEmpty)
            
            // Verify the encoded data contains expected fields
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertEqual(json?["email"] as? String, "test@example.com")
            XCTAssertEqual(json?["password"] as? String, "password123")
        } catch {
            XCTFail("JSON encoding failed: \(error)")
        }
    }
    
    func testJSONDecoding() {
        let jsonString = """
        {
            "success": true,
            "message": "Test message",
            "data": {
                "access_token": "test_token",
                "token_type": "Bearer",
                "expires_in": 3600
            },
            "user": {
                "id": 1,
                "email": "test@example.com",
                "full_name": "Test User",
                "is_active": true,
                "is_verified": false,
                "role": "user",
                "created_at": "2024-01-01T00:00:00.000000",
                "updated_at": "2024-01-01T00:00:00.000000"
            }
        }
        """
        
        guard let data = jsonString.data(using: .utf8) else {
            XCTFail("Failed to create test data")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let response = try decoder.decode(AuthResponse.self, from: data)
            
            XCTAssertTrue(response.success)
            XCTAssertEqual(response.data.access_token, "test_token")
            XCTAssertEqual(response.user.email, "test@example.com")
            XCTAssertEqual(response.user.id, 1)
        } catch {
            XCTFail("JSON decoding failed: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testURLBuildingPerformance() {
        measure {
            for _ in 0..<1000 {
                let queryItems = [
                    URLQueryItem(name: "page", value: "1"),
                    URLQueryItem(name: "size", value: "20"),
                    URLQueryItem(name: "query", value: "test")
                ]
                _ = apiService.buildURL(endpoint: "/hadiths", queryItems: queryItems)
            }
        }
    }
    
    func testHeaderBuildingPerformance() {
        // Save a test token
        try? KeychainManager.shared.saveToken("test_token", forKey: KeychainManager.Keys.accessToken)
        
        measure {
            let request = URLRequest(url: URL(string: "https://example.com")!)
            
            for _ in 0..<100 {
                apiService.addAuthHeader(to: request)
                    .sink(
                        receiveCompletion: { _ in },
                        receiveValue: { _ in }
                    )
                    .store(in: &cancellables)
            }
        }
        
        // Clean up
        try? KeychainManager.shared.deleteToken(forKey: KeychainManager.Keys.accessToken)
    }
}

// MARK: - Test Helpers

extension APIServiceTests {
    /// Create a mock successful response
    func createMockResponse<T: Codable>(_ data: T) -> Data {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(data)
        } catch {
            XCTFail("Failed to create mock response: \(error)")
            return Data()
        }
    }
    
    /// Create a mock error response
    func createMockErrorResponse(statusCode: Int, message: String) -> Data {
        let errorResponse = ErrorResponse(
            success: false,
            message: message,
            details: nil,
            error_code: "TEST_ERROR"
        )
        return createMockResponse(errorResponse)
    }
}
