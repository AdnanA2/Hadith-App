import Foundation
import Combine

/// Service for managing hadith-related API operations
class HadithService {
    static let shared = HadithService()
    
    private let apiService = APIService.shared
    
    private init() {}
    
    // MARK: - Hadith Endpoints
    
    /// Get hadiths with search and filtering options
    /// - Parameter searchParams: Search and filter parameters
    /// - Returns: Publisher with hadiths response or error
    func getHadiths(
        searchParams: HadithSearchParams = HadithSearchParams()
    ) -> AnyPublisher<HadithsResponse, HadithServiceError> {
        let queryItems = searchParams.toQueryItems()
        
        return apiService.get<HadithsResponse>(endpoint: "/hadiths", queryItems: queryItems)
            .mapError { HadithServiceError.from(apiError: $0) }
            .eraseToAnyPublisher()
    }
    
    /// Get hadiths with individual parameters (convenience method)
    /// - Parameters:
    ///   - query: Search query string
    ///   - collectionId: Filter by collection ID
    ///   - chapterId: Filter by chapter ID
    ///   - grade: Filter by hadith grade
    ///   - narrator: Filter by narrator name
    ///   - page: Page number for pagination
    ///   - pageSize: Number of items per page
    /// - Returns: Publisher with hadiths response or error
    func getHadiths(
        query: String? = nil,
        collectionId: String? = nil,
        chapterId: String? = nil,
        grade: HadithGrade? = nil,
        narrator: String? = nil,
        page: Int = 1,
        pageSize: Int = 20
    ) -> AnyPublisher<HadithsResponse, HadithServiceError> {
        let searchParams = HadithSearchParams(
            query: query,
            collectionId: collectionId,
            chapterId: chapterId,
            grade: grade,
            narrator: narrator,
            page: page,
            pageSize: pageSize
        )
        
        return getHadiths(searchParams: searchParams)
    }
    
    /// Get the daily hadith
    /// - Parameter date: Optional date in YYYY-MM-DD format (defaults to today)
    /// - Returns: Publisher with daily hadith response or error
    func getDailyHadith(date: String? = nil) -> AnyPublisher<DailyHadithResponse, HadithServiceError> {
        var queryItems: [URLQueryItem] = []
        
        if let date = date {
            queryItems.append(URLQueryItem(name: "date_param", value: date))
        }
        
        return apiService.get<DailyHadithResponse>(endpoint: "/hadiths/daily", queryItems: queryItems)
            .mapError { HadithServiceError.from(apiError: $0) }
            .eraseToAnyPublisher()
    }
    
    /// Get a random hadith
    /// - Parameters:
    ///   - collectionId: Optional collection ID filter
    ///   - grade: Optional grade filter
    ///   - excludeFavorites: Whether to exclude user's favorites
    /// - Returns: Publisher with hadith response or error
    func getRandomHadith(
        collectionId: String? = nil,
        grade: HadithGrade? = nil,
        excludeFavorites: Bool = false
    ) -> AnyPublisher<HadithResponse, HadithServiceError> {
        var queryItems: [URLQueryItem] = []
        
        if let collectionId = collectionId {
            queryItems.append(URLQueryItem(name: "collection_id", value: collectionId))
        }
        
        if let grade = grade {
            queryItems.append(URLQueryItem(name: "grade", value: grade.rawValue))
        }
        
        if excludeFavorites {
            queryItems.append(URLQueryItem(name: "exclude_favorites", value: "true"))
        }
        
        return apiService.get<HadithResponse>(endpoint: "/hadiths/random", queryItems: queryItems)
            .mapError { HadithServiceError.from(apiError: $0) }
            .eraseToAnyPublisher()
    }
    
    /// Get a specific hadith by ID
    /// - Parameter id: The hadith ID
    /// - Returns: Publisher with hadith response or error
    func getHadith(by id: String) -> AnyPublisher<HadithResponse, HadithServiceError> {
        return apiService.get<HadithResponse>(endpoint: "/hadiths/\(id)")
            .mapError { HadithServiceError.from(apiError: $0) }
            .eraseToAnyPublisher()
    }
    
    /// Get hadiths from a specific collection
    /// - Parameters:
    ///   - collectionId: The collection ID
    ///   - page: Page number for pagination
    ///   - pageSize: Number of items per page
    ///   - grade: Optional grade filter
    /// - Returns: Publisher with hadiths response or error
    func getHadithsByCollection(
        collectionId: String,
        page: Int = 1,
        pageSize: Int = 20,
        grade: HadithGrade? = nil
    ) -> AnyPublisher<HadithsResponse, HadithServiceError> {
        var queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "page_size", value: "\(pageSize)")
        ]
        
        if let grade = grade {
            queryItems.append(URLQueryItem(name: "grade", value: grade.rawValue))
        }
        
        return apiService.get<HadithsResponse>(endpoint: "/hadiths/collection/\(collectionId)", queryItems: queryItems)
            .mapError { HadithServiceError.from(apiError: $0) }
            .eraseToAnyPublisher()
    }
    
    /// Get hadiths from a specific chapter
    /// - Parameters:
    ///   - chapterId: The chapter ID
    ///   - page: Page number for pagination
    ///   - pageSize: Number of items per page
    /// - Returns: Publisher with hadiths response or error
    func getHadithsByChapter(
        chapterId: String,
        page: Int = 1,
        pageSize: Int = 20
    ) -> AnyPublisher<HadithsResponse, HadithServiceError> {
        let queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "page_size", value: "\(pageSize)")
        ]
        
        return apiService.get<HadithsResponse>(endpoint: "/hadiths/chapter/\(chapterId)", queryItems: queryItems)
            .mapError { HadithServiceError.from(apiError: $0) }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Collection Endpoints
    
    /// Get all collections
    /// - Parameters:
    ///   - page: Page number for pagination
    ///   - pageSize: Number of items per page
    /// - Returns: Publisher with collections response or error
    func getCollections(
        page: Int = 1,
        pageSize: Int = 20
    ) -> AnyPublisher<CollectionsResponse, HadithServiceError> {
        let queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "page_size", value: "\(pageSize)")
        ]
        
        return apiService.get<CollectionsResponse>(endpoint: "/collections", queryItems: queryItems)
            .mapError { HadithServiceError.from(apiError: $0) }
            .eraseToAnyPublisher()
    }
    
    /// Get a specific collection by ID
    /// - Parameter id: The collection ID
    /// - Returns: Publisher with collection response or error
    func getCollection(by id: String) -> AnyPublisher<CollectionResponse, HadithServiceError> {
        return apiService.get<CollectionResponse>(endpoint: "/collections/\(id)")
            .mapError { HadithServiceError.from(apiError: $0) }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Favorite Endpoints
    
    /// Get user's favorite hadiths
    /// - Parameters:
    ///   - page: Page number for pagination
    ///   - pageSize: Number of items per page
    ///   - collectionId: Optional collection filter
    /// - Returns: Publisher with favorites response or error
    func getFavorites(
        page: Int = 1,
        pageSize: Int = 20,
        collectionId: String? = nil
    ) -> AnyPublisher<FavoritesResponse, HadithServiceError> {
        var queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "page_size", value: "\(pageSize)")
        ]
        
        if let collectionId = collectionId {
            queryItems.append(URLQueryItem(name: "collection_id", value: collectionId))
        }
        
        return apiService.get<FavoritesResponse>(endpoint: "/favorites", queryItems: queryItems)
            .mapError { HadithServiceError.from(apiError: $0) }
            .eraseToAnyPublisher()
    }
    
    /// Add a hadith to favorites
    /// - Parameters:
    ///   - hadithId: The hadith ID to favorite
    ///   - notes: Optional notes about the favorite
    /// - Returns: Publisher with favorite response or error
    func addFavorite(hadithId: String, notes: String? = nil) -> AnyPublisher<FavoriteResponse, HadithServiceError> {
        let request = AddFavoriteRequest(hadith_id: hadithId, notes: notes)
        
        return apiService.post<AddFavoriteRequest, FavoriteResponse>(endpoint: "/favorites", body: request)
            .mapError { HadithServiceError.from(apiError: $0) }
            .eraseToAnyPublisher()
    }
    
    /// Remove a favorite by ID
    /// - Parameter id: The favorite ID to remove
    /// - Returns: Publisher with empty response or error
    func removeFavorite(by id: Int) -> AnyPublisher<EmptyResponse, HadithServiceError> {
        return apiService.delete<EmptyResponse>(endpoint: "/favorites/\(id)")
            .mapError { HadithServiceError.from(apiError: $0) }
            .eraseToAnyPublisher()
    }
    
    /// Toggle favorite status for a hadith
    /// - Parameter hadithId: The hadith ID to toggle
    /// - Returns: Publisher with favorite response or error
    func toggleFavorite(hadithId: String) -> AnyPublisher<FavoriteResponse, HadithServiceError> {
        return apiService.post<EmptyRequest, FavoriteResponse>(
            endpoint: "/favorites/hadith/\(hadithId)",
            body: EmptyRequest()
        )
        .mapError { HadithServiceError.from(apiError: $0) }
        .eraseToAnyPublisher()
    }
    
    // MARK: - Convenience Methods
    
    /// Search hadiths by text
    /// - Parameters:
    ///   - query: Search query
    ///   - page: Page number
    ///   - pageSize: Items per page
    /// - Returns: Publisher with search results
    func searchHadiths(
        query: String,
        page: Int = 1,
        pageSize: Int = 20
    ) -> AnyPublisher<HadithsResponse, HadithServiceError> {
        return getHadiths(query: query, page: page, pageSize: pageSize)
    }
    
    /// Get hadiths by grade
    /// - Parameters:
    ///   - grade: Hadith grade to filter by
    ///   - page: Page number
    ///   - pageSize: Items per page
    /// - Returns: Publisher with filtered results
    func getHadithsByGrade(
        grade: HadithGrade,
        page: Int = 1,
        pageSize: Int = 20
    ) -> AnyPublisher<HadithsResponse, HadithServiceError> {
        return getHadiths(grade: grade, page: page, pageSize: pageSize)
    }
    
    /// Get hadiths by narrator
    /// - Parameters:
    ///   - narrator: Narrator name to filter by
    ///   - page: Page number
    ///   - pageSize: Items per page
    /// - Returns: Publisher with filtered results
    func getHadithsByNarrator(
        narrator: String,
        page: Int = 1,
        pageSize: Int = 20
    ) -> AnyPublisher<HadithsResponse, HadithServiceError> {
        return getHadiths(narrator: narrator, page: page, pageSize: pageSize)
    }
}

// MARK: - HadithServiceError

enum HadithServiceError: Error, LocalizedError, Identifiable {
    case notFound(String)
    case networkError(String)
    case authenticationRequired
    case serverError(String)
    case validationError(String)
    case unknown(String)
    
    var id: String {
        switch self {
        case .notFound:
            return "not_found"
        case .networkError:
            return "network_error"
        case .authenticationRequired:
            return "authentication_required"
        case .serverError:
            return "server_error"
        case .validationError:
            return "validation_error"
        case .unknown:
            return "unknown_error"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .notFound(let message):
            return "Not found: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .authenticationRequired:
            return "Authentication required"
        case .serverError(let message):
            return "Server error: \(message)"
        case .validationError(let message):
            return "Validation error: \(message)"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .notFound:
            return "The requested item could not be found"
        case .networkError:
            return "Please check your internet connection and try again"
        case .authenticationRequired:
            return "Please log in to access this feature"
        case .serverError:
            return "Please try again later"
        case .validationError:
            return "Please check your input and try again"
        case .unknown:
            return "Please try again"
        }
    }
    
    static func from(apiError: APIServiceError) -> HadithServiceError {
        switch apiError {
        case .notFound(let message):
            return .notFound(message)
        case .networkError(let error):
            return .networkError(error.localizedDescription)
        case .authenticationError, .authorizationError:
            return .authenticationRequired
        case .serverError(_, let message), .httpError(_, let message):
            return .serverError(message)
        case .validationError(let message, _):
            return .validationError(message)
        default:
            return .unknown(apiError.localizedDescription)
        }
    }
}

// MARK: - Cache Support

extension HadithService {
    /// Cache manager for hadiths (simple in-memory cache)
    private class HadithCache {
        private var cache: [String: Any] = [:]
        private let cacheQueue = DispatchQueue(label: "hadith.cache", attributes: .concurrent)
        
        func get<T>(key: String, type: T.Type) -> T? {
            return cacheQueue.sync {
                return cache[key] as? T
            }
        }
        
        func set<T>(key: String, value: T) {
            cacheQueue.async(flags: .barrier) {
                self.cache[key] = value
            }
        }
        
        func clear() {
            cacheQueue.async(flags: .barrier) {
                self.cache.removeAll()
            }
        }
    }
    
    private static let cache = HadithCache()
    
    /// Get daily hadith with caching
    func getCachedDailyHadith(date: String? = nil) -> AnyPublisher<DailyHadithResponse, HadithServiceError> {
        let cacheKey = "daily_hadith_\(date ?? "today")"
        
        // Check cache first
        if let cachedResponse = Self.cache.get(key: cacheKey, type: DailyHadithResponse.self) {
            return Just(cachedResponse)
                .setFailureType(to: HadithServiceError.self)
                .eraseToAnyPublisher()
        }
        
        // Fetch from API and cache
        return getDailyHadith(date: date)
            .handleEvents(receiveOutput: { response in
                Self.cache.set(key: cacheKey, value: response)
            })
            .eraseToAnyPublisher()
    }
    
    /// Clear all cached data
    func clearCache() {
        Self.cache.clear()
    }
}
