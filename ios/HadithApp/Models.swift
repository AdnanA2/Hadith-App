import Foundation

// MARK: - Base Response Models

protocol BaseResponse {
    var success: Bool { get }
    var message: String? { get }
}

struct APIResponse<T: Codable>: Codable, BaseResponse {
    let success: Bool
    let message: String?
    let data: T
}

struct EmptyResponse: Codable, BaseResponse {
    let success: Bool
    let message: String?
}

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

struct TokenData: Codable {
    let access_token: String
    let token_type: String
    let expires_in: Int
}

struct User: Codable, Identifiable {
    let id: Int
    let email: String
    let full_name: String?
    let is_active: Bool
    let is_verified: Bool
    let role: String
    let created_at: String
    let updated_at: String
}

struct AuthResponse: Codable, BaseResponse {
    let success: Bool
    let message: String?
    let data: TokenData
    let user: User
}

struct UserResponse: Codable, BaseResponse {
    let success: Bool
    let message: String?
    let data: User
}

struct UserUpdate: Codable {
    let full_name: String?
    let password: String?
}

// MARK: - Hadith Models

enum HadithGrade: String, Codable, CaseIterable {
    case sahih = "Sahih"
    case hasan = "Hasan"
    case daif = "Da'if"
    case mawdu = "Mawdu'"
    case unknown = "Unknown"
    
    var displayName: String {
        return rawValue
    }
    
    var color: String {
        switch self {
        case .sahih:
            return "green"
        case .hasan:
            return "blue"
        case .daif:
            return "orange"
        case .mawdu:
            return "red"
        case .unknown:
            return "gray"
        }
    }
}

struct Hadith: Codable, Identifiable {
    let id: String
    let collection_id: String
    let chapter_id: String
    let hadith_number: Int
    let arabic_text: String
    let english_text: String
    let narrator: String
    let grade: HadithGrade
    let grade_details: String?
    let refs: [String: String]?
    let tags: [String]?
    let source_url: String?
    let created_at: String
    let updated_at: String
    let collection_name_en: String?
    let collection_name_ar: String?
    let chapter_title_en: String?
    let chapter_title_ar: String?
    let chapter_number: Int?
    let is_favorite: Bool
    
    // Computed properties for display
    var formattedNumber: String {
        return "\(hadith_number)"
    }
    
    var collectionDisplayName: String {
        return collection_name_en ?? "Unknown Collection"
    }
    
    var chapterDisplayName: String {
        return chapter_title_en ?? "Unknown Chapter"
    }
    
    var shortText: String {
        let maxLength = 150
        if english_text.count <= maxLength {
            return english_text
        }
        let truncated = String(english_text.prefix(maxLength))
        return truncated + "..."
    }
}

struct PaginationMeta: Codable {
    let page: Int
    let page_size: Int
    let total_count: Int
    let total_pages: Int
    let has_next: Bool
    let has_prev: Bool
}

struct HadithResponse: Codable, BaseResponse {
    let success: Bool
    let message: String?
    let data: Hadith
}

struct HadithsResponse: Codable, BaseResponse {
    let success: Bool
    let message: String?
    let data: [Hadith]
    let meta: PaginationMeta?
}

struct DailyHadithResponse: Codable, BaseResponse {
    let success: Bool
    let message: String?
    let data: Hadith
    let date: String
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
    
    var displayName: String {
        return name_en
    }
    
    var displayDescription: String {
        return description_en ?? "No description available"
    }
}

struct CollectionResponse: Codable, BaseResponse {
    let success: Bool
    let message: String?
    let data: Collection
}

struct CollectionsResponse: Codable, BaseResponse {
    let success: Bool
    let message: String?
    let data: [Collection]
    let meta: PaginationMeta?
}

// MARK: - Chapter Models

struct Chapter: Codable, Identifiable {
    let id: String
    let collection_id: String
    let chapter_number: Int
    let title_en: String
    let title_ar: String
    let description_en: String?
    let description_ar: String?
    let created_at: String
    let updated_at: String
    
    var displayTitle: String {
        return title_en
    }
    
    var formattedNumber: String {
        return "Chapter \(chapter_number)"
    }
}

struct ChapterResponse: Codable, BaseResponse {
    let success: Bool
    let message: String?
    let data: Chapter
}

struct ChaptersResponse: Codable, BaseResponse {
    let success: Bool
    let message: String?
    let data: [Chapter]
    let meta: PaginationMeta?
}

// MARK: - Favorite Models

struct Favorite: Codable, Identifiable {
    let id: Int
    let user_id: Int
    let hadith_id: String
    let notes: String?
    let added_at: String
    let hadith: Hadith
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        
        if let date = formatter.date(from: added_at) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        
        return added_at
    }
}

struct AddFavoriteRequest: Codable {
    let hadith_id: String
    let notes: String?
}

struct FavoriteResponse: Codable, BaseResponse {
    let success: Bool
    let message: String?
    let data: Favorite
}

struct FavoritesResponse: Codable, BaseResponse {
    let success: Bool
    let message: String?
    let data: [Favorite]
    let meta: PaginationMeta?
}

// MARK: - Search and Filter Models

struct HadithSearchParams {
    let query: String?
    let collectionId: String?
    let chapterId: String?
    let grade: HadithGrade?
    let narrator: String?
    let page: Int
    let pageSize: Int
    
    init(
        query: String? = nil,
        collectionId: String? = nil,
        chapterId: String? = nil,
        grade: HadithGrade? = nil,
        narrator: String? = nil,
        page: Int = 1,
        pageSize: Int = 20
    ) {
        self.query = query
        self.collectionId = collectionId
        self.chapterId = chapterId
        self.grade = grade
        self.narrator = narrator
        self.page = page
        self.pageSize = pageSize
    }
    
    func toQueryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        
        if let query = query, !query.isEmpty {
            items.append(URLQueryItem(name: "q", value: query))
        }
        
        if let collectionId = collectionId {
            items.append(URLQueryItem(name: "collection_id", value: collectionId))
        }
        
        if let chapterId = chapterId {
            items.append(URLQueryItem(name: "chapter_id", value: chapterId))
        }
        
        if let grade = grade {
            items.append(URLQueryItem(name: "grade", value: grade.rawValue))
        }
        
        if let narrator = narrator, !narrator.isEmpty {
            items.append(URLQueryItem(name: "narrator", value: narrator))
        }
        
        items.append(URLQueryItem(name: "page", value: "\(page)"))
        items.append(URLQueryItem(name: "page_size", value: "\(pageSize)"))
        
        return items
    }
}

// MARK: - Error Models

struct APIError: Error, LocalizedError {
    let statusCode: Int?
    let message: String
    let details: [String]?
    
    init(statusCode: Int? = nil, message: String, details: [String]? = nil) {
        self.statusCode = statusCode
        self.message = message
        self.details = details
    }
    
    var errorDescription: String? {
        return message
    }
    
    var failureReason: String? {
        if let statusCode = statusCode {
            return "HTTP \(statusCode): \(message)"
        }
        return message
    }
    
    var recoverySuggestion: String? {
        switch statusCode {
        case 401:
            return "Please log in again"
        case 403:
            return "You don't have permission to access this resource"
        case 404:
            return "The requested resource was not found"
        case 500...599:
            return "Server error. Please try again later"
        default:
            return "Please check your internet connection and try again"
        }
    }
}

struct ErrorResponse: Codable {
    let success: Bool
    let message: String
    let details: [String]?
    let error_code: String?
}

// MARK: - Empty Request Model

struct EmptyRequest: Codable {
    // Empty body for endpoints that don't require data
}

// MARK: - Utility Extensions

extension DateFormatter {
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    static let displayDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    static let displayDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
