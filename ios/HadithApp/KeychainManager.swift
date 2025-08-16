import Foundation
import Security

/// Secure storage manager using iOS Keychain
class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.hadithapp.hadith"
    
    private init() {}
    
    // MARK: - Keys
    
    struct Keys {
        static let accessToken = "access_token"
        static let refreshToken = "refresh_token"
        static let userID = "user_id"
        static let biometricEnabled = "biometric_enabled"
    }
    
    // MARK: - Public Methods
    
    /// Save a token securely to the keychain
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
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
        
        if Environment.isDebug {
            print("🔐 Keychain: Successfully saved token for key: \(key)")
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
        
        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let token = String(data: data, encoding: .utf8) else {
                throw KeychainError.invalidData
            }
            
            if Environment.isDebug {
                print("🔐 Keychain: Successfully retrieved token for key: \(key)")
            }
            
            return token
            
        case errSecItemNotFound:
            if Environment.isDebug {
                print("🔐 Keychain: No token found for key: \(key)")
            }
            return nil
            
        default:
            throw KeychainError.readFailed(status)
        }
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
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
        
        if Environment.isDebug {
            print("🔐 Keychain: Successfully deleted token for key: \(key)")
        }
    }
    
    /// Check if a token exists in the keychain
    /// - Parameter key: The key to check
    /// - Returns: True if the token exists, false otherwise
    func tokenExists(forKey key: String) -> Bool {
        do {
            return try getToken(forKey: key) != nil
        } catch {
            return false
        }
    }
    
    /// Clear all stored tokens
    func clearAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
        
        if Environment.isDebug {
            print("🔐 Keychain: Successfully cleared all tokens")
        }
    }
    
    // MARK: - Biometric Authentication Support
    
    /// Save a token with biometric protection
    /// - Parameters:
    ///   - token: The token to save
    ///   - key: The key to associate with the token
    ///   - prompt: The prompt to show for biometric authentication
    /// - Throws: KeychainError if the operation fails
    func saveTokenWithBiometric(_ token: String, forKey key: String, prompt: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        
        let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.biometryAny],
            nil
        )
        
        guard let accessControl = access else {
            throw KeychainError.biometricNotAvailable
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessControl as String: accessControl,
            kSecUseOperationPrompt as String: prompt
        ]
        
        // Delete any existing item
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ] as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
        
        if Environment.isDebug {
            print("🔐 Keychain: Successfully saved token with biometric protection for key: \(key)")
        }
    }
    
    /// Retrieve a token with biometric authentication
    /// - Parameters:
    ///   - key: The key associated with the token
    ///   - prompt: The prompt to show for biometric authentication
    /// - Returns: The token string if found and authenticated
    /// - Throws: KeychainError if the operation fails
    func getTokenWithBiometric(forKey key: String, prompt: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseOperationPrompt as String: prompt
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let token = String(data: data, encoding: .utf8) else {
                throw KeychainError.invalidData
            }
            
            if Environment.isDebug {
                print("🔐 Keychain: Successfully retrieved token with biometric auth for key: \(key)")
            }
            
            return token
            
        case errSecItemNotFound:
            return nil
            
        case errSecUserCancel:
            throw KeychainError.userCancelled
            
        case errSecAuthFailed:
            throw KeychainError.authenticationFailed
            
        default:
            throw KeychainError.readFailed(status)
        }
    }
}

// MARK: - KeychainError

enum KeychainError: Error, LocalizedError {
    case saveFailed(OSStatus)
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)
    case invalidData
    case biometricNotAvailable
    case userCancelled
    case authenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to keychain (status: \(status))"
        case .readFailed(let status):
            return "Failed to read from keychain (status: \(status))"
        case .deleteFailed(let status):
            return "Failed to delete from keychain (status: \(status))"
        case .invalidData:
            return "Invalid data format"
        case .biometricNotAvailable:
            return "Biometric authentication is not available"
        case .userCancelled:
            return "User cancelled biometric authentication"
        case .authenticationFailed:
            return "Biometric authentication failed"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .saveFailed, .readFailed, .deleteFailed:
            return "Please try again or restart the app"
        case .invalidData:
            return "Please check the data format and try again"
        case .biometricNotAvailable:
            return "Please enable Face ID or Touch ID in Settings"
        case .userCancelled:
            return "Please try again and complete the biometric authentication"
        case .authenticationFailed:
            return "Please try again with correct biometric authentication"
        }
    }
}

// MARK: - Keychain Status Extensions

extension KeychainManager {
    /// Get human-readable description for keychain status codes
    static func statusDescription(for status: OSStatus) -> String {
        switch status {
        case errSecSuccess:
            return "Success"
        case errSecItemNotFound:
            return "Item not found"
        case errSecDuplicateItem:
            return "Duplicate item"
        case errSecAuthFailed:
            return "Authentication failed"
        case errSecUserCancel:
            return "User cancelled"
        case errSecNotAvailable:
            return "Service not available"
        case errSecParam:
            return "Invalid parameters"
        case errSecAllocate:
            return "Memory allocation failed"
        case errSecUnimplemented:
            return "Function not implemented"
        case errSecDiskFull:
            return "Disk full"
        case errSecIO:
            return "I/O error"
        default:
            return "Unknown error (\(status))"
        }
    }
}