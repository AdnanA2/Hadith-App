# iOS Integration Guide for Hadith App

## Overview
This guide provides step-by-step instructions for integrating your iOS app with the Hadith backend API. The backend is live with authentication, CORS, pagination, and HTTPS deployment.

## Table of Contents
1. [Xcode Project Configuration](#1-xcode-project-configuration)
2. [Authentication Token Management](#2-authentication-token-management)
3. [API Service Layer](#3-api-service-layer)
4. [Testing Strategy](#4-testing-strategy)
5. [Common Pitfalls & Solutions](#5-common-pitfalls--solutions)

---

## 1. Xcode Project Configuration

### 1.1 Network Security Configuration

Create a `NetworkSecurity.plist` file in your project:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <false/>
        <key>NSExceptionDomains</key>
        <dict>
            <key>your-api-domain.com</key>
            <dict>
                <key>NSExceptionAllowsInsecureHTTPLoads</key>
                <false/>
                <key>NSExceptionMinimumTLSVersion</key>
                <string>TLSv1.2</string>
                <key>NSExceptionRequiresForwardSecrecy</key>
                <true/>
            </dict>
        </dict>
    </dict>
</dict>
</plist>
```

### 1.2 Info.plist Configuration

Add these keys to your `Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.yourapp.hadith</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>hadithapp</string>
        </array>
    </dict>
</array>
```

### 1.3 Environment Configuration

Create an `Environment.swift` file:

```swift
enum Environment {
    static let baseURL = "https://your-api-domain.com/api/v1"
    static let apiVersion = "v1"
    
    #if DEBUG
    static let isDebug = true
    #else
    static let isDebug = false
    #endif
}
```

---

## 2. Authentication Token Management

### 2.1 Secure Token Storage

Use Keychain for secure token storage:

```swift
import Security
import Foundation

class KeychainManager {
    static let shared = KeychainManager()
    private let service = "com.yourapp.hadith"
    
    private init() {}
    
    func saveToken(_ token: String, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: token.data(using: .utf8)!
        ]
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    func getToken(forKey key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return token
    }
    
    func deleteToken(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

enum KeychainError: Error {
    case saveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case readFailed(OSStatus)
}
```

### 2.2 Authentication Manager

```swift
import Foundation
import Combine

class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    private let keychain = KeychainManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        checkAuthenticationStatus()
    }
    
    func checkAuthenticationStatus() {
        do {
            if let token = try keychain.getToken(forKey: "access_token") {
                // Validate token with backend
                validateToken(token)
            } else {
                isAuthenticated = false
                currentUser = nil
            }
        } catch {
            print("Error checking authentication: \(error)")
            isAuthenticated = false
            currentUser = nil
        }
    }
    
    func login(email: String, password: String) -> AnyPublisher<AuthResponse, Error> {
        let loginData = LoginRequest(email: email, password: password)
        
        return APIService.shared.post(endpoint: "/auth/login", body: loginData)
            .handleEvents(receiveOutput: { [weak self] response in
                self?.handleSuccessfulAuth(response)
            })
            .eraseToAnyPublisher()
    }
    
    func signup(email: String, password: String, fullName: String) -> AnyPublisher<AuthResponse, Error> {
        let signupData = SignupRequest(email: email, password: password, full_name: fullName)
        
        return APIService.shared.post(endpoint: "/auth/signup", body: signupData)
            .handleEvents(receiveOutput: { [weak self] response in
                self?.handleSuccessfulAuth(response)
            })
            .eraseToAnyPublisher()
    }
    
    func logout() {
        do {
            try keychain.deleteToken(forKey: "access_token")
            isAuthenticated = false
            currentUser = nil
        } catch {
            print("Error during logout: \(error)")
        }
    }
    
    private func handleSuccessfulAuth(_ response: AuthResponse) {
        do {
            try keychain.saveToken(response.data.access_token, forKey: "access_token")
            isAuthenticated = true
            currentUser = response.user
        } catch {
            print("Error saving token: \(error)")
        }
    }
    
    private func validateToken(_ token: String) {
        APIService.shared.get(endpoint: "/auth/me")
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure = completion {
                        self?.isAuthenticated = false
                        self?.currentUser = nil
                    }
                },
                receiveValue: { [weak self] (response: UserResponse) in
                    self?.isAuthenticated = true
                    self?.currentUser = response.data
                }
            )
            .store(in: &cancellables)
    }
}
```

---

## 3. API Service Layer

### 3.1 Core API Service

```swift
import Foundation
import Combine

class APIService {
    static let shared = APIService()
    private let baseURL = Environment.baseURL
    private let session = URLSession.shared
    
    private init() {}
    
    // MARK: - Generic Request Methods
    
    func get<T: Decodable>(endpoint: String, queryItems: [URLQueryItem]? = nil) -> AnyPublisher<T, Error> {
        guard let url = buildURL(endpoint: endpoint, queryItems: queryItems) else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        return addAuthHeader(to: request)
            .flatMap { request in
                self.session.dataTaskPublisher(for: request)
            }
            .map(\.data)
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error in
                if error is DecodingError {
                    return APIError.decodingError(error)
                }
                return APIError.networkError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func post<T: Encodable, U: Decodable>(endpoint: String, body: T) -> AnyPublisher<U, Error> {
        guard let url = buildURL(endpoint: endpoint) else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            return Fail(error: APIError.encodingError(error))
                .eraseToAnyPublisher()
        }
        
        return addAuthHeader(to: request)
            .flatMap { request in
                self.session.dataTaskPublisher(for: request)
            }
            .map(\.data)
            .decode(type: U.self, decoder: JSONDecoder())
            .mapError { error in
                if error is DecodingError {
                    return APIError.decodingError(error)
                }
                return APIError.networkError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func put<T: Encodable, U: Decodable>(endpoint: String, body: T) -> AnyPublisher<U, Error> {
        guard let url = buildURL(endpoint: endpoint) else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            return Fail(error: APIError.encodingError(error))
                .eraseToAnyPublisher()
        }
        
        return addAuthHeader(to: request)
            .flatMap { request in
                self.session.dataTaskPublisher(for: request)
            }
            .map(\.data)
            .decode(type: U.self, decoder: JSONDecoder())
            .mapError { error in
                if error is DecodingError {
                    return APIError.decodingError(error)
                }
                return APIError.networkError(error)
            }
            .eraseToAnyPublisher()
    }
    
    func delete<T: Decodable>(endpoint: String) -> AnyPublisher<T, Error> {
        guard let url = buildURL(endpoint: endpoint) else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        return addAuthHeader(to: request)
            .flatMap { request in
                self.session.dataTaskPublisher(for: request)
            }
            .map(\.data)
            .decode(type: T.self, decoder: JSONDecoder())
            .mapError { error in
                if error is DecodingError {
                    return APIError.decodingError(error)
                }
                return APIError.networkError(error)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    
    private func buildURL(endpoint: String, queryItems: [URLQueryItem]? = nil) -> URL? {
        var components = URLComponents(string: baseURL + endpoint)
        components?.queryItems = queryItems
        return components?.url
    }
    
    private func addAuthHeader(to request: URLRequest) -> AnyPublisher<URLRequest, Error> {
        return Future { promise in
            do {
                let token = try KeychainManager.shared.getToken(forKey: "access_token")
                var request = request
                
                if let token = token {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                
                promise(.success(request))
            } catch {
                promise(.failure(APIError.authenticationError))
            }
        }
        .eraseToAnyPublisher()
    }
}

// MARK: - Error Types

enum APIError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case encodingError(Error)
    case authenticationError
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .authenticationError:
            return "Authentication failed"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}
```

### 3.2 Data Models

```swift
import Foundation

// MARK: - Authentication Models

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct SignupRequest: Codable {
    let email: String
    let password: String
    let full_name: String
}

struct AuthResponse: Codable {
    let success: Bool
    let message: String
    let data: TokenData
    let user: User
}

struct TokenData: Codable {
    let access_token: String
    let token_type: String
    let expires_in: Int
}

struct User: Codable, Identifiable {
    let id: Int
    let email: String
    let full_name: String
    let is_active: Bool
    let is_verified: Bool
    let role: String
    let created_at: String
    let updated_at: String
}

struct UserResponse: Codable {
    let success: Bool
    let data: User
}

// MARK: - Hadith Models

struct Hadith: Codable, Identifiable {
    let id: String
    let collection_id: String
    let chapter_id: String
    let hadith_number: Int
    let arabic_text: String
    let english_text: String
    let narrator: String
    let grade: String
    let grade_details: String?
    let refs: [String: String]?
    let tags: [String]?
    let source_url: String?
    let created_at: String
    let updated_at: String
    let collection_name_en: String
    let collection_name_ar: String
    let chapter_title_en: String
    let chapter_title_ar: String
    let chapter_number: Int
    let is_favorite: Bool
}

struct HadithResponse: Codable {
    let success: Bool
    let data: [Hadith]
    let meta: PaginationMeta
}

struct PaginationMeta: Codable {
    let page: Int
    let page_size: Int
    let total_count: Int
    let total_pages: Int
    let has_next: Bool
    let has_prev: Bool
}

// MARK: - Collection Models

struct Collection: Codable, Identifiable {
    let id: String
    let name_en: String
    let name_ar: String
    let description_en: String?
    let description_ar: String?
    let created_at: String
    let updated_at: String
}

struct CollectionResponse: Codable {
    let success: Bool
    let data: [Collection]
    let meta: PaginationMeta
}

// MARK: - Favorite Models

struct Favorite: Codable, Identifiable {
    let id: Int
    let user_id: Int
    let hadith_id: String
    let notes: String?
    let added_at: String
    let hadith: Hadith
}

struct FavoriteResponse: Codable {
    let success: Bool
    let data: [Favorite]
    let meta: PaginationMeta
}

struct AddFavoriteRequest: Codable {
    let hadith_id: String
    let notes: String?
}
```

### 3.3 Hadith Service

```swift
import Foundation
import Combine

class HadithService {
    static let shared = HadithService()
    private let apiService = APIService.shared
    
    private init() {}
    
    // MARK: - Hadith Endpoints
    
    func getHadiths(
        query: String? = nil,
        collectionId: String? = nil,
        chapterId: String? = nil,
        grade: String? = nil,
        narrator: String? = nil,
        page: Int = 1,
        pageSize: Int = 20
    ) -> AnyPublisher<HadithResponse, Error> {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "page_size", value: "\(pageSize)")
        ]
        
        if let query = query {
            queryItems.append(URLQueryItem(name: "q", value: query))
        }
        
        if let collectionId = collectionId {
            queryItems.append(URLQueryItem(name: "collection_id", value: collectionId))
        }
        
        if let chapterId = chapterId {
            queryItems.append(URLQueryItem(name: "chapter_id", value: chapterId))
        }
        
        if let grade = grade {
            queryItems.append(URLQueryItem(name: "grade", value: grade))
        }
        
        if let narrator = narrator {
            queryItems.append(URLQueryItem(name: "narrator", value: narrator))
        }
        
        return apiService.get(endpoint: "/hadiths", queryItems: queryItems)
    }
    
    func getDailyHadith(date: String? = nil) -> AnyPublisher<DailyHadithResponse, Error> {
        var queryItems: [URLQueryItem] = []
        
        if let date = date {
            queryItems.append(URLQueryItem(name: "date_param", value: date))
        }
        
        return apiService.get(endpoint: "/hadiths/daily", queryItems: queryItems)
    }
    
    func getRandomHadith(
        collectionId: String? = nil,
        grade: String? = nil,
        excludeFavorites: Bool = false
    ) -> AnyPublisher<HadithResponse, Error> {
        var queryItems: [URLQueryItem] = []
        
        if let collectionId = collectionId {
            queryItems.append(URLQueryItem(name: "collection_id", value: collectionId))
        }
        
        if let grade = grade {
            queryItems.append(URLQueryItem(name: "grade", value: grade))
        }
        
        if excludeFavorites {
            queryItems.append(URLQueryItem(name: "exclude_favorites", value: "true"))
        }
        
        return apiService.get(endpoint: "/hadiths/random", queryItems: queryItems)
    }
    
    func getHadith(by id: String) -> AnyPublisher<HadithResponse, Error> {
        return apiService.get(endpoint: "/hadiths/\(id)")
    }
    
    // MARK: - Collection Endpoints
    
    func getCollections(page: Int = 1, pageSize: Int = 20) -> AnyPublisher<CollectionResponse, Error> {
        let queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "page_size", value: "\(pageSize)")
        ]
        
        return apiService.get(endpoint: "/collections", queryItems: queryItems)
    }
    
    func getCollection(by id: String) -> AnyPublisher<CollectionResponse, Error> {
        return apiService.get(endpoint: "/collections/\(id)")
    }
    
    // MARK: - Favorite Endpoints
    
    func getFavorites(
        page: Int = 1,
        pageSize: Int = 20,
        collectionId: String? = nil
    ) -> AnyPublisher<FavoriteResponse, Error> {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "page_size", value: "\(pageSize)")
        ]
        
        if let collectionId = collectionId {
            queryItems.append(URLQueryItem(name: "collection_id", value: collectionId))
        }
        
        return apiService.get(endpoint: "/favorites", queryItems: queryItems)
    }
    
    func addFavorite(hadithId: String, notes: String? = nil) -> AnyPublisher<FavoriteResponse, Error> {
        let request = AddFavoriteRequest(hadith_id: hadithId, notes: notes)
        return apiService.post(endpoint: "/favorites", body: request)
    }
    
    func removeFavorite(by id: Int) -> AnyPublisher<EmptyResponse, Error> {
        return apiService.delete(endpoint: "/favorites/\(id)")
    }
    
    func toggleFavorite(hadithId: String) -> AnyPublisher<FavoriteResponse, Error> {
        return apiService.post(endpoint: "/favorites/hadith/\(hadithId)", body: EmptyRequest())
    }
}

// MARK: - Additional Response Models

struct DailyHadithResponse: Codable {
    let success: Bool
    let message: String
    let data: Hadith
    let date: String
}

struct EmptyRequest: Codable {}

struct EmptyResponse: Codable {
    let success: Bool
    let message: String
}
```

---

## 4. Testing Strategy

### 4.1 Unit Tests

Create test files for each service:

```swift
import XCTest
import Combine
@testable import YourApp

class APIServiceTests: XCTestCase {
    var cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        super.setUp()
        cancellables.removeAll()
    }
    
    func testSuccessfulHadithFetch() {
        let expectation = XCTestExpectation(description: "Fetch hadiths")
        
        HadithService.shared.getHadiths(page: 1, pageSize: 5)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("API call failed: \(error)")
                    }
                },
                receiveValue: { response in
                    XCTAssertTrue(response.success)
                    XCTAssertFalse(response.data.isEmpty)
                    XCTAssertEqual(response.data.count, 5)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testAuthenticationFlow() {
        let expectation = XCTestExpectation(description: "Authentication")
        
        AuthenticationManager.shared.login(email: "test@example.com", password: "password")
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Authentication failed: \(error)")
                    }
                },
                receiveValue: { response in
                    XCTAssertTrue(response.success)
                    XCTAssertNotNil(response.data.access_token)
                    XCTAssertEqual(response.user.email, "test@example.com")
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 10.0)
    }
}
```

### 4.2 Integration Tests

```swift
class IntegrationTests: XCTestCase {
    var cancellables = Set<AnyCancellable>()
    
    func testEndToEndHadithFlow() {
        let expectation = XCTestExpectation(description: "End-to-end flow")
        
        // 1. Login
        AuthenticationManager.shared.login(email: "test@example.com", password: "password")
            .flatMap { _ in
                // 2. Fetch hadiths
                HadithService.shared.getHadiths(page: 1, pageSize: 1)
            }
            .flatMap { hadithResponse in
                // 3. Add to favorites
                guard let hadith = hadithResponse.data.first else {
                    return Fail(error: APIError.serverError("No hadiths found"))
                        .eraseToAnyPublisher()
                }
                return HadithService.shared.addFavorite(hadithId: hadith.id)
            }
            .flatMap { _ in
                // 4. Fetch favorites
                HadithService.shared.getFavorites()
            }
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTFail("Integration test failed: \(error)")
                    }
                },
                receiveValue: { favoritesResponse in
                    XCTAssertTrue(favoritesResponse.success)
                    XCTAssertFalse(favoritesResponse.data.isEmpty)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 15.0)
    }
}
```

### 4.3 Network Testing

```swift
class NetworkTests: XCTestCase {
    func testNetworkConnectivity() {
        let expectation = XCTestExpectation(description: "Network connectivity")
        
        // Test basic connectivity
        guard let url = URL(string: Environment.baseURL + "/collections") else {
            XCTFail("Invalid URL")
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                XCTFail("Network error: \(error)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                XCTFail("Invalid response")
                return
            }
            
            XCTAssertEqual(httpResponse.statusCode, 200)
            expectation.fulfill()
        }.resume()
        
        wait(for: [expectation], timeout: 10.0)
    }
}
```

### 4.4 Manual Testing Checklist

Create a testing checklist for manual verification:

```markdown
## Manual Testing Checklist

### Authentication
- [ ] User can sign up with valid email/password
- [ ] User can login with valid credentials
- [ ] Invalid credentials show appropriate error
- [ ] Token is stored securely in Keychain
- [ ] User can logout successfully
- [ ] App remembers login state after restart

### Hadith Features
- [ ] Daily hadith loads correctly
- [ ] Hadith list loads with pagination
- [ ] Search functionality works
- [ ] Filters work (collection, grade, narrator)
- [ ] Individual hadith details display correctly
- [ ] Arabic and English text display properly

### Favorites
- [ ] User can add hadith to favorites
- [ ] User can remove hadith from favorites
- [ ] Favorites list shows user's saved hadiths
- [ ] Favorites persist after app restart

### Network Handling
- [ ] App handles network errors gracefully
- [ ] Loading states display correctly
- [ ] Offline mode works (if implemented)
- [ ] Retry mechanism works for failed requests

### Performance
- [ ] App loads quickly
- [ ] Scrolling is smooth
- [ ] Images load efficiently
- [ ] Memory usage is reasonable
```

---

## 5. Common Pitfalls & Solutions

### 5.1 Authentication Issues

**Problem:** Token expiration not handled
```swift
// Solution: Add token refresh logic
class AuthenticationManager {
    func refreshToken() -> AnyPublisher<AuthResponse, Error> {
        // Implement token refresh endpoint
        return APIService.shared.post(endpoint: "/auth/refresh", body: RefreshRequest())
    }
}
```

**Problem:** Token stored in UserDefaults instead of Keychain
```swift
// ❌ Wrong
UserDefaults.standard.set(token, forKey: "access_token")

// ✅ Correct
try KeychainManager.shared.saveToken(token, forKey: "access_token")
```

### 5.2 Network Issues

**Problem:** No timeout handling
```swift
// Solution: Configure URLSession with timeout
let config = URLSessionConfiguration.default
config.timeoutIntervalForRequest = 30
config.timeoutIntervalForResource = 60
let session = URLSession(configuration: config)
```

**Problem:** No retry logic
```swift
// Solution: Add retry mechanism
func getWithRetry<T: Decodable>(endpoint: String, retries: Int = 3) -> AnyPublisher<T, Error> {
    return get(endpoint: endpoint)
        .catch { error -> AnyPublisher<T, Error> in
            if retries > 0 && error is URLError {
                return self.getWithRetry(endpoint: endpoint, retries: retries - 1)
                    .delay(for: .seconds(2), scheduler: DispatchQueue.main)
                    .eraseToAnyPublisher()
            }
            return Fail(error: error).eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
}
```

### 5.3 Memory Management

**Problem:** Cancellables not properly managed
```swift
// Solution: Use proper cancellable management
class ViewModel: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    
    func fetchData() {
        APIService.shared.get(endpoint: "/hadiths")
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] response in
                    self?.hadiths = response.data
                }
            )
            .store(in: &cancellables)
    }
}
```

### 5.4 Error Handling

**Problem:** Generic error messages
```swift
// Solution: Provide specific error handling
enum APIError: Error, LocalizedError {
    case networkError(Error)
    case authenticationError
    case serverError(String)
    case decodingError(Error)
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Please check your internet connection"
        case .authenticationError:
            return "Please log in again"
        case .serverError(let message):
            return "Server error: \(message)"
        case .decodingError:
            return "Unable to process server response"
        }
    }
}
```

### 5.5 Security Issues

**Problem:** Hardcoded API URLs
```swift
// ❌ Wrong
let baseURL = "https://api.example.com"

// ✅ Correct
enum Environment {
    static let baseURL = Bundle.main.infoDictionary?["API_BASE_URL"] as? String ?? "https://api.example.com"
}
```

**Problem:** No certificate pinning
```swift
// Solution: Implement certificate pinning for production
class CertificatePinningDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Implement certificate pinning logic
    }
}
```

### 5.6 Performance Issues

**Problem:** No caching
```swift
// Solution: Implement caching
class CacheManager {
    static let shared = CacheManager()
    private let cache = NSCache<NSString, AnyObject>()
    
    func set<T: AnyObject>(_ object: T, forKey key: String) {
        cache.setObject(object, forKey: key as NSString)
    }
    
    func get<T: AnyObject>(forKey key: String) -> T? {
        return cache.object(forKey: key as NSString) as? T
    }
}
```

**Problem:** No image caching
```swift
// Solution: Use SDWebImage or similar for image caching
import SDWebImage

ImageView(url: URL(string: "https://example.com/image.jpg"))
    .resizable()
    .aspectRatio(contentMode: .fit)
```

### 5.7 Testing Issues

**Problem:** No mock data for testing
```swift
// Solution: Create mock services
class MockHadithService: HadithServiceProtocol {
    func getHadiths() -> AnyPublisher<HadithResponse, Error> {
        return Just(mockHadithResponse)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}
```

**Problem:** No offline testing
```swift
// Solution: Add network condition testing
class NetworkConditionTests: XCTestCase {
    func testSlowNetwork() {
        // Use Network Link Conditioner or similar tools
        // Test app behavior with slow/limited connectivity
    }
}
```

---

## 6. Implementation Checklist

Before going live, ensure you have:

- [ ] Configured network security settings
- [ ] Implemented secure token storage
- [ ] Added proper error handling
- [ ] Created comprehensive test suite
- [ ] Tested on different network conditions
- [ ] Verified authentication flow
- [ ] Tested all API endpoints
- [ ] Implemented proper loading states
- [ ] Added retry mechanisms
- [ ] Configured proper timeouts
- [ ] Tested memory usage
- [ ] Verified offline behavior
- [ ] Added proper logging
- [ ] Implemented analytics tracking
- [ ] Tested on different iOS versions
- [ ] Verified accessibility features

This guide provides a solid foundation for integrating your iOS app with the Hadith backend. Follow these steps systematically, and you'll have a robust, secure, and well-tested integration.
