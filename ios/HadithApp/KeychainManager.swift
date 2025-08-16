import Security
import Foundation

/// Secure storage manager for tokens and sensitive data using iOS Keychain
class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.hadithapp.hadith"
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Save a token to the keychain
    /// - Parameters:
    ///   - token: The token string to save
    ///   - key: The key to associate with the token
    /// - Throws: KeychainError if the operation fails
    func saveToken(_ token: String, forKey key: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete any existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    /// Retrieve a token from the keychain
    /// - Parameter key: The key associated with the token
    /// - Returns: The token string if found, nil otherwise
    /// - Throws: KeychainError if the operation fails
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
        
        guard status != errSecItemNotFound else {
            return nil // Item not found is not an error
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.readFailed(status)
        }
        
        guard let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        
        return token
    }
    
    /// Delete a token from the keychain
    /// - Parameter key: The key associated with the token to delete
    /// - Throws: KeychainError if the operation fails
    func deleteToken(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        // Success or item not found are both acceptable outcomes
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
    
    /// Check if a token exists in the keychain
    /// - Parameter key: The key to check for
    /// - Returns: true if the token exists, false otherwise
    func hasToken(forKey key: String) -> Bool {
        do {
            return try getToken(forKey: key) != nil
        } catch {
            return false
        }
    }
    
    /// Clear all tokens stored by this app
    /// - Throws: KeychainError if the operation fails
    func clearAllTokens() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        // Success or item not found are both acceptable outcomes
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

// MARK: - KeychainError

enum KeychainError: Error, LocalizedError {
    case saveFailed(OSStatus)
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to keychain. Status: \(status)"
        case .readFailed(let status):
            return "Failed to read from keychain. Status: \(status)"
        case .deleteFailed(let status):
            return "Failed to delete from keychain. Status: \(status)"
        case .invalidData:
            return "Invalid data format"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .saveFailed, .readFailed, .deleteFailed:
            return "Please try again. If the problem persists, try restarting the app."
        case .invalidData:
            return "The data format is not supported."
        }
    }
}

// MARK: - Keychain Keys

extension KeychainManager {
    enum Keys {
        static let accessToken = "access_token"
        static let refreshToken = "refresh_token"
        static let userEmail = "user_email"
    }
}
