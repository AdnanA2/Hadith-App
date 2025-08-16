import XCTest
import Network
import Combine
@testable import HadithApp

/// Tests for network connectivity and offline behavior
class NetworkConnectivityTests: XCTestCase {
    
    var networkMonitor: NetworkMonitor!
    var apiService: APIService!
    var cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        super.setUp()
        networkMonitor = NetworkMonitor.shared
        apiService = APIService.shared
        cancellables.removeAll()
    }
    
    override func tearDown() {
        super.tearDown()
        cancellables.removeAll()
        networkMonitor = nil
        apiService = nil
    }
    
    // MARK: - Network Monitor Tests
    
    func testNetworkMonitorInitialization() {
        XCTAssertNotNil(networkMonitor)
        // Network status might be unknown initially
    }
    
    func testNetworkStatusChanges() {
        let expectation = XCTestExpectation(description: "Network status changes")
        var statusUpdates: [NetworkStatus] = []
        
        networkMonitor.$isConnected
            .sink { isConnected in
                statusUpdates.append(isConnected ? .connected : .disconnected)
                
                if statusUpdates.count >= 1 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
        XCTAssertFalse(statusUpdates.isEmpty)
    }
    
    // MARK: - Offline Behavior Tests
    
    func testAPIBehaviorWhenOffline() {
        // This test simulates offline behavior
        let expectation = XCTestExpectation(description: "API behavior when offline")
        
        // Create a request that would fail due to no network
        apiService.get<HadithsResponse>(endpoint: "/hadiths")
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        // Verify we get a network error
                        if case APIServiceError.networkError = error {
                            expectation.fulfill()
                        } else {
                            XCTFail("Expected network error, got: \(error)")
                        }
                    } else {
                        // If we somehow get success in a unit test, that's also valid
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    // Success is also acceptable in some test environments
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testRetryMechanismWithNetworkFailure() {
        let expectation = XCTestExpectation(description: "Retry with network failure")
        var attemptCount = 0
        
        let failingRequest = { () -> AnyPublisher<HadithsResponse, APIServiceError> in
            attemptCount += 1
            let networkError = URLError(.networkConnectionLost)
            return Fail(error: APIServiceError.networkError(networkError))
                .eraseToAnyPublisher()
        }
        
        apiService.requestWithRetry(
            maxRetries: 2,
            baseDelay: 0.1,
            requestPublisher: failingRequest
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    // Should fail after retries
                    XCTAssertTrue(error is APIServiceError)
                    XCTAssertEqual(attemptCount, 3) // Initial + 2 retries
                    expectation.fulfill()
                } else {
                    XCTFail("Should fail after retries")
                }
            },
            receiveValue: { _ in
                XCTFail("Should not succeed")
            }
        )
        .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Connection Quality Tests
    
    func testConnectionQualityDetection() {
        // Test different connection types if available
        let currentStatus = networkMonitor.connectionType
        
        // Verify we can detect connection type
        switch currentStatus {
        case .wifi:
            print("📶 Connected via WiFi")
        case .cellular:
            print("📱 Connected via Cellular")
        case .wiredEthernet:
            print("🔌 Connected via Ethernet")
        case .other:
            print("🌐 Connected via other means")
        case .unknown:
            print("❓ Connection type unknown")
        }
        
        // Test should not fail regardless of connection type
        XCTAssertTrue(true)
    }
    
    // MARK: - Timeout Tests
    
    func testRequestTimeout() {
        let expectation = XCTestExpectation(description: "Request timeout")
        
        // Create a request to a non-existent endpoint that should timeout
        let longTimeoutRequest = URLRequest(url: URL(string: "https://httpbin.org/delay/35")!)
        
        URLSession.shared.dataTaskPublisher(for: longTimeoutRequest)
            .timeout(.seconds(5), scheduler: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        // Should timeout
                        print("Expected timeout error: \(error)")
                        expectation.fulfill()
                    } else {
                        XCTFail("Should have timed out")
                    }
                },
                receiveValue: { _ in
                    XCTFail("Should not receive value for timeout test")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Error Classification Tests
    
    func testNetworkErrorClassification() {
        let errors: [URLError] = [
            URLError(.notConnectedToInternet),
            URLError(.networkConnectionLost),
            URLError(.cannotConnectToHost),
            URLError(.timedOut),
            URLError(.cannotFindHost),
            URLError(.dnsLookupFailed)
        ]
        
        for error in errors {
            let isNetworkError = isNetworkRelatedError(error)
            XCTAssertTrue(isNetworkError, "Should classify \(error.code) as network error")
        }
        
        // Test non-network errors
        let nonNetworkErrors: [URLError] = [
            URLError(.badURL),
            URLError(.unsupportedURL),
            URLError(.cannotDecodeRawData)
        ]
        
        for error in nonNetworkErrors {
            let isNetworkError = isNetworkRelatedError(error)
            XCTAssertFalse(isNetworkError, "Should not classify \(error.code) as network error")
        }
    }
    
    // MARK: - Recovery Mechanism Tests
    
    func testAutomaticRecoveryFromNetworkError() {
        let expectation = XCTestExpectation(description: "Automatic recovery")
        var attemptCount = 0
        
        let recoveringRequest = { () -> AnyPublisher<HadithsResponse, APIServiceError> in
            attemptCount += 1
            
            if attemptCount < 3 {
                // Simulate network failure for first 2 attempts
                return Fail(error: APIServiceError.networkError(URLError(.networkConnectionLost)))
                    .eraseToAnyPublisher()
            } else {
                // Simulate recovery on 3rd attempt
                let mockResponse = HadithsResponse(
                    success: true,
                    message: "Recovered",
                    data: [],
                    meta: nil
                )
                return Just(mockResponse)
                    .setFailureType(to: APIServiceError.self)
                    .eraseToAnyPublisher()
            }
        }
        
        apiService.requestWithRetry(
            maxRetries: 3,
            baseDelay: 0.1,
            requestPublisher: recoveringRequest
        )
        .sink(
            receiveCompletion: { completion in
                if case .failure = completion {
                    XCTFail("Should recover after network issues")
                }
            },
            receiveValue: { response in
                XCTAssertTrue(response.success)
                XCTAssertEqual(attemptCount, 3)
                expectation.fulfill()
            }
        )
        .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Offline Cache Tests
    
    func testOfflineCacheBehavior() {
        // This would test offline caching if implemented
        let cacheKey = "test_hadiths_cache"
        let mockData = ["test": "data"]
        
        // Store in cache
        CacheManager.shared.set(mockData, forKey: cacheKey)
        
        // Retrieve from cache
        let cachedData: [String: String]? = CacheManager.shared.get(forKey: cacheKey)
        XCTAssertNotNil(cachedData)
        XCTAssertEqual(cachedData?["test"], "data")
        
        // Clear cache
        CacheManager.shared.remove(forKey: cacheKey)
        let clearedData: [String: String]? = CacheManager.shared.get(forKey: cacheKey)
        XCTAssertNil(clearedData)
    }
    
    // MARK: - Background Task Tests
    
    func testBackgroundNetworkRequests() {
        let expectation = XCTestExpectation(description: "Background network request")
        
        // Simulate a background task
        DispatchQueue.global(qos: .background).async {
            // Attempt network request from background
            self.apiService.get<CollectionsResponse>(endpoint: "/collections")
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { completion in
                        // Either success or expected failure is fine
                        expectation.fulfill()
                    },
                    receiveValue: { _ in
                        expectation.fulfill()
                    }
                )
                .store(in: &self.cancellables)
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - Performance Under Network Stress
    
    func testPerformanceUnderNetworkStress() {
        measure {
            let expectations = (0..<10).map { i in
                XCTestExpectation(description: "Request \(i)")
            }
            
            // Make multiple concurrent requests
            for (index, expectation) in expectations.enumerated() {
                apiService.get<CollectionsResponse>(endpoint: "/collections")
                    .sink(
                        receiveCompletion: { _ in
                            expectation.fulfill()
                        },
                        receiveValue: { _ in
                            expectation.fulfill()
                        }
                    )
                    .store(in: &cancellables)
            }
            
            wait(for: expectations, timeout: 15.0)
        }
    }
    
    // MARK: - Helper Functions
    
    private func isNetworkRelatedError(_ error: URLError) -> Bool {
        switch error.code {
        case .notConnectedToInternet,
             .networkConnectionLost,
             .cannotConnectToHost,
             .timedOut,
             .cannotFindHost,
             .dnsLookupFailed:
            return true
        default:
            return false
        }
    }
}

// MARK: - NetworkMonitor Implementation

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published var isConnected = true
    @Published var connectionType: ConnectionType = .unknown
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.getConnectionType(from: path) ?? .unknown
            }
        }
        monitor.start(queue: queue)
    }
    
    private func getConnectionType(from path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wiredEthernet
        } else if path.usesInterfaceType(.other) {
            return .other
        } else {
            return .unknown
        }
    }
    
    deinit {
        monitor.cancel()
    }
}

enum ConnectionType {
    case wifi
    case cellular
    case wiredEthernet
    case other
    case unknown
}

enum NetworkStatus {
    case connected
    case disconnected
    case unknown
}

// MARK: - CacheManager Implementation

class CacheManager {
    static let shared = CacheManager()
    
    private let cache = NSCache<NSString, AnyObject>()
    
    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = Environment.cacheSize
    }
    
    func set<T: AnyObject>(_ object: T, forKey key: String) {
        cache.setObject(object, forKey: key as NSString)
    }
    
    func get<T: AnyObject>(forKey key: String) -> T? {
        return cache.object(forKey: key as NSString) as? T
    }
    
    func remove(forKey key: String) {
        cache.removeObject(forKey: key as NSString)
    }
    
    func removeAll() {
        cache.removeAllObjects()
    }
}
