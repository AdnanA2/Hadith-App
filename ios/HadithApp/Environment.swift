import Foundation

enum Environment {
    // MARK: - API Configuration
    static let baseURL = "https://your-hadith-api.com/api/v1"
    static let apiVersion = "v1"
    
    // MARK: - Debug Configuration
    #if DEBUG
    static let isDebug = true
    static let logLevel = "debug"
    #else
    static let isDebug = false
    static let logLevel = "info"
    #endif
    
    // MARK: - App Configuration
    static let appName = "Hadith App"
    static let bundleIdentifier = "com.hadithapp.hadith"
    
    // MARK: - Network Configuration
    static let requestTimeout: TimeInterval = 30.0
    static let resourceTimeout: TimeInterval = 60.0
    
    // MARK: - Cache Configuration
    static let cacheSize = 50 * 1024 * 1024 // 50MB
    static let cacheDuration: TimeInterval = 3600 // 1 hour
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
