import Foundation
import Combine

/// Core API service for handling HTTP requests with authentication and error handling
class APIService {
    static let shared = APIService()
    
    private let baseURL = Environment.baseURL
    private let session: URLSession
    private let keychain = KeychainManager.shared
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Environment.requestTimeout
        config.timeoutIntervalForResource = Environment.resourceTimeout
        config.httpMaximumConnectionsPerHost = 5
        
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Generic HTTP Methods
    
    /// Perform a GET request
    /// - Parameters:
    ///   - endpoint: The API endpoint (e.g., "/hadiths")
    ///   - queryItems: Optional query parameters
    /// - Returns: Publisher with decoded response
    func get<T: Codable>(
        endpoint: String,
        queryItems: [URLQueryItem]? = nil
    ) -> AnyPublisher<T, APIServiceError> {
        guard let url = buildURL(endpoint: endpoint, queryItems: queryItems) else {
            return Fail(error: APIServiceError.invalidURL(endpoint))
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        return addAuthHeader(to: request)
            .flatMap { [weak self] request in
                guard let self = self else {
                    return Fail<T, APIServiceError>(error: APIServiceError.serviceUnavailable)
                        .eraseToAnyPublisher()
                }
                return self.performRequest(request)
            }
            .eraseToAnyPublisher()
    }
    
    /// Perform a POST request
    /// - Parameters:
    ///   - endpoint: The API endpoint
    ///   - body: The request body to encode
    /// - Returns: Publisher with decoded response
    func post<T: Encodable, U: Codable>(
        endpoint: String,
        body: T
    ) -> AnyPublisher<U, APIServiceError> {
        guard let url = buildURL(endpoint: endpoint) else {
            return Fail(error: APIServiceError.invalidURL(endpoint))
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
        } catch {
            return Fail(error: APIServiceError.encodingError(error))
                .eraseToAnyPublisher()
        }
        
        return addAuthHeader(to: request)
            .flatMap { [weak self] request in
                guard let self = self else {
                    return Fail<U, APIServiceError>(error: APIServiceError.serviceUnavailable)
                        .eraseToAnyPublisher()
                }
                return self.performRequest(request)
            }
            .eraseToAnyPublisher()
    }
    
    /// Perform a PUT request
    /// - Parameters:
    ///   - endpoint: The API endpoint
    ///   - body: The request body to encode
    /// - Returns: Publisher with decoded response
    func put<T: Encodable, U: Codable>(
        endpoint: String,
        body: T
    ) -> AnyPublisher<U, APIServiceError> {
        guard let url = buildURL(endpoint: endpoint) else {
            return Fail(error: APIServiceError.invalidURL(endpoint))
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
        } catch {
            return Fail(error: APIServiceError.encodingError(error))
                .eraseToAnyPublisher()
        }
        
        return addAuthHeader(to: request)
            .flatMap { [weak self] request in
                guard let self = self else {
                    return Fail<U, APIServiceError>(error: APIServiceError.serviceUnavailable)
                        .eraseToAnyPublisher()
                }
                return self.performRequest(request)
            }
            .eraseToAnyPublisher()
    }
    
    /// Perform a DELETE request
    /// - Parameter endpoint: The API endpoint
    /// - Returns: Publisher with decoded response
    func delete<T: Codable>(endpoint: String) -> AnyPublisher<T, APIServiceError> {
        guard let url = buildURL(endpoint: endpoint) else {
            return Fail(error: APIServiceError.invalidURL(endpoint))
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        return addAuthHeader(to: request)
            .flatMap { [weak self] request in
                guard let self = self else {
                    return Fail<T, APIServiceError>(error: APIServiceError.serviceUnavailable)
                        .eraseToAnyPublisher()
                }
                return self.performRequest(request)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    
    private func buildURL(endpoint: String, queryItems: [URLQueryItem]? = nil) -> URL? {
        var components = URLComponents(string: baseURL + endpoint)
        components?.queryItems = queryItems
        return components?.url
    }
    
    private func addAuthHeader(to request: URLRequest) -> AnyPublisher<URLRequest, APIServiceError> {
        return Future<URLRequest, APIServiceError> { [weak self] promise in
            guard let self = self else {
                promise(.failure(.serviceUnavailable))
                return
            }
            
            do {
                var request = request
                
                // Add auth header if token exists
                if let token = try self.keychain.getToken(forKey: KeychainManager.Keys.accessToken) {
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                }
                
                // Add additional headers
                request.setValue(Environment.apiVersion, forHTTPHeaderField: "API-Version")
                request.setValue(Environment.bundleIdentifier, forHTTPHeaderField: "User-Agent")
                
                promise(.success(request))
            } catch {
                promise(.failure(.authenticationError("Failed to retrieve auth token")))
            }
        }
        .eraseToAnyPublisher()
    }
    
    private func performRequest<T: Codable>(_ request: URLRequest) -> AnyPublisher<T, APIServiceError> {
        if Environment.isDebug {
            print("🌐 API Request: \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "unknown")")
        }
        
        return session.dataTaskPublisher(for: request)
            .map { data, response in
                if Environment.isDebug {
                    print("🌐 API Response: \(response.url?.absoluteString ?? "unknown") - \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                }
                return (data, response)
            }
            .tryMap { [weak self] data, response in
                try self?.handleResponse(data: data, response: response) ?? data
            }
            .decode(type: T.self, decoder: self.createJSONDecoder())
            .mapError { error in
                if let apiError = error as? APIServiceError {
                    return apiError
                } else if error is DecodingError {
                    return APIServiceError.decodingError(error)
                } else {
                    return APIServiceError.networkError(error)
                }
            }
            .eraseToAnyPublisher()
    }
    
    private func handleResponse(data: Data, response: URLResponse) throws -> Data {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        let statusCode = httpResponse.statusCode
        
        // Handle success status codes
        if 200...299 ~= statusCode {
            return data
        }
        
        // Try to decode error response
        var errorMessage = "Request failed with status \(statusCode)"
        var details: [String]? = nil
        
        if !data.isEmpty {
            do {
                let errorResponse = try createJSONDecoder().decode(ErrorResponse.self, from: data)
                errorMessage = errorResponse.message
                details = errorResponse.details
            } catch {
                // If we can't decode the error response, try to get plain text
                if let plainError = String(data: data, encoding: .utf8) {
                    errorMessage = plainError
                }
            }
        }
        
        // Handle specific status codes
        switch statusCode {
        case 401:
            throw APIServiceError.authenticationError(errorMessage)
        case 403:
            throw APIServiceError.authorizationError(errorMessage)
        case 404:
            throw APIServiceError.notFound(errorMessage)
        case 422:
            throw APIServiceError.validationError(errorMessage, details)
        case 500...599:
            throw APIServiceError.serverError(statusCode, errorMessage)
        default:
            throw APIServiceError.httpError(statusCode, errorMessage)
        }
    }
    
    private func createJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        // Handle flexible date formats
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        decoder.dateDecodingStrategy = .formatted(formatter)
        
        return decoder
    }
}

// MARK: - APIServiceError

enum APIServiceError: Error, LocalizedError, Equatable {
    case invalidURL(String)
    case invalidResponse
    case networkError(Error)
    case encodingError(Error)
    case decodingError(Error)
    case authenticationError(String)
    case authorizationError(String)
    case notFound(String)
    case validationError(String, [String]?)
    case serverError(Int, String)
    case httpError(Int, String)
    case serviceUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidURL(let endpoint):
            return "Invalid URL for endpoint: \(endpoint)"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .authenticationError(let message):
            return "Authentication failed: \(message)"
        case .authorizationError(let message):
            return "Authorization failed: \(message)"
        case .notFound(let message):
            return "Resource not found: \(message)"
        case .validationError(let message, _):
            return "Validation error: \(message)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .httpError(let code, let message):
            return "HTTP error (\(code)): \(message)"
        case .serviceUnavailable:
            return "Service temporarily unavailable"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkError, .serviceUnavailable:
            return "Please check your internet connection and try again"
        case .authenticationError:
            return "Please log in again"
        case .authorizationError:
            return "You don't have permission to access this resource"
        case .serverError:
            return "Please try again later"
        case .validationError(_, let details):
            return details?.joined(separator: ", ")
        default:
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
    
    static func == (lhs: APIServiceError, rhs: APIServiceError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL(let lhsEndpoint), .invalidURL(let rhsEndpoint)):
            return lhsEndpoint == rhsEndpoint
        case (.invalidResponse, .invalidResponse):
            return true
        case (.authenticationError(let lhsMessage), .authenticationError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.authorizationError(let lhsMessage), .authorizationError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.notFound(let lhsMessage), .notFound(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.validationError(let lhsMessage, let lhsDetails), .validationError(let rhsMessage, let rhsDetails)):
            return lhsMessage == rhsMessage && lhsDetails == rhsDetails
        case (.serverError(let lhsCode, let lhsMessage), .serverError(let rhsCode, let rhsMessage)):
            return lhsCode == rhsCode && lhsMessage == rhsMessage
        case (.httpError(let lhsCode, let lhsMessage), .httpError(let rhsCode, let rhsMessage)):
            return lhsCode == rhsCode && lhsMessage == rhsMessage
        case (.serviceUnavailable, .serviceUnavailable):
            return true
        default:
            return false
        }
    }
}

// MARK: - Request Retry Extension

extension APIService {
    /// Retry a request with exponential backoff
    func requestWithRetry<T: Codable>(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        requestPublisher: @escaping () -> AnyPublisher<T, APIServiceError>
    ) -> AnyPublisher<T, APIServiceError> {
        requestPublisher()
            .catch { error -> AnyPublisher<T, APIServiceError> in
                if maxRetries > 0 && self.shouldRetry(error: error) {
                    return Just(())
                        .delay(for: .seconds(baseDelay), scheduler: DispatchQueue.main)
                        .flatMap { _ in
                            self.requestWithRetry(
                                maxRetries: maxRetries - 1,
                                baseDelay: baseDelay * 2,
                                requestPublisher: requestPublisher
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
    
    private func shouldRetry(error: APIServiceError) -> Bool {
        switch error {
        case .networkError, .serverError(500...599, _), .serviceUnavailable:
            return true
        default:
            return false
        }
    }
}
