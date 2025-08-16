import Foundation

enum Environment {
    // MARK: - API Configuration
    static let baseURL: String = {
        // Try to get from Info.plist first (for different environments)
        if let url = Bundle.main.infoDictionary?["API_BASE_URL"] as? String {
            return url
        }
        
        #if DEBUG
        return "https://dev-hadith-api.com/api/v1"
        #else
        return "https://hadith-api.com/api/v1"
        #endif
    }()
    
    static let apiVersion = "v1"
    static let websocketURL: String = {
        return baseURL.replacingOccurrences(of: "http", with: "ws") + "/ws"
    }()
    
    // MARK: - Debug Configuration
    #if DEBUG
    static let isDebug = true
    static let logLevel = "debug"
    static let enableNetworkLogging = true
    #else
    static let isDebug = false
    static let logLevel = "info"
    static let enableNetworkLogging = false
    #endif
    
    // MARK: - App Configuration
    static let appName = "Hadith App"
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.hadithapp.hadith"
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    // MARK: - Network Configuration
    static let requestTimeout: TimeInterval = 30.0
    static let resourceTimeout: TimeInterval = 60.0
    static let maxRetryAttempts = 3
    static let retryDelay: TimeInterval = 1.0
    
    // MARK: - Cache Configuration
    static let cacheSize = 50 * 1024 * 1024 // 50MB
    static let cacheDuration: TimeInterval = 3600 // 1 hour
    static let imageCacheSize = 100 * 1024 * 1024 // 100MB for images
    static let maxCacheAge: TimeInterval = 7 * 24 * 3600 // 1 week
    
    // MARK: - Security Configuration
    static let certificatePinningEnabled = !isDebug
    static let allowSelfSignedCertificates = isDebug
    static let requireHTTPS = true
    
    // MARK: - Analytics Configuration
    static let analyticsEnabled = !isDebug
    static let crashReportingEnabled = true
    static let performanceMonitoringEnabled = true
    
    // MARK: - Feature Flags
    static let biometricAuthEnabled = true
    static let offlineModeEnabled = true
    static let pushNotificationsEnabled = true
    static let shareExtensionEnabled = true
    
    // MARK: - UI Configuration
    static let animationDuration: TimeInterval = 0.3
    static let hapticFeedbackEnabled = true
    static let darkModeSupported = true
    
    // MARK: - Pagination Configuration
    static let defaultPageSize = 20
    static let maxPageSize = 100
    static let prefetchThreshold = 5 // Items before end to trigger next page load
}

// MARK: - Environment Helper Functions
extension Environment {
    static func getConfigValue(for key: String) -> String? {
        return Bundle.main.infoDictionary?[key] as? String
    }
    
    static var isTestEnvironment: Bool {
        return NSClassFromString("XCTest") != nil
    }
    
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}
