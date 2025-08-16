import Foundation
import Combine

/// Base protocol for all API services to eliminate repetitive response handling
protocol BaseService {
    associatedtype ServiceError: Error
    
    var apiService: APIService { get }
    var logger: Logger { get }
}

extension BaseService {
    var apiService: APIService { APIService.shared }
    var logger: Logger { Logger.shared }
    
    /// Standard response handler for all API calls
    /// - Parameters:
    ///   - publisher: The API publisher
    ///   - context: Context for logging
    ///   - errorMapper: Function to map API errors to service errors
    /// - Returns: Publisher with mapped errors
    func handleResponse<T: Codable>(
        _ publisher: AnyPublisher<T, APIServiceError>,
        context: String,
        errorMapper: @escaping (APIServiceError) -> ServiceError
    ) -> AnyPublisher<T, ServiceError> {
        return publisher
            .handleEvents(
                receiveSubscription: { _ in
                    self.logger.debug("🔄 \(context) - Request started")
                },
                receiveOutput: { _ in
                    self.logger.debug("✅ \(context) - Request completed")
                },
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        self.logger.error("❌ \(context) - Request failed: \(error)")
                    }
                }
            )
            .mapError(errorMapper)
            .eraseToAnyPublisher()
    }
    
    /// Standard authentication response handler
    /// - Parameters:
    ///   - publisher: The API publisher
    ///   - context: Context for logging
    ///   - errorMapper: Function to map API errors to service errors
    /// - Returns: Publisher with mapped errors
    func handleAuthResponse<T: Codable>(
        _ publisher: AnyPublisher<T, APIServiceError>,
        context: String,
        errorMapper: @escaping (APIServiceError) -> ServiceError
    ) -> AnyPublisher<T, ServiceError> {
        return publisher
            .handleEvents(
                receiveSubscription: { _ in
                    self.logger.debug("🔐 \(context) - Auth request started")
                },
                receiveOutput: { _ in
                    self.logger.debug("✅ \(context) - Auth request completed")
                },
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        self.logger.error("❌ \(context) - Auth request failed: \(error)")
                    }
                }
            )
            .mapError(errorMapper)
            .eraseToAnyPublisher()
    }
}
