import Foundation
import Security

/// Certificate pinning implementation for enhanced security
class CertificatePinning: NSObject {
    static let shared = CertificatePinning()
    
    // MARK: - Configuration
    
    private struct PinningConfig {
        static let enabled = Environment.certificatePinningEnabled
        static let allowSelfSigned = Environment.allowSelfSignedCertificates
        static let requireHTTPS = Environment.requireHTTPS
        
        // Add your API domain's certificate hashes here
        static let pinnedCertificates: [String: [String]] = [
            "hadith-api.com": [
                // SHA-256 hash of the certificate's public key
                "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
                // Backup certificate hash
                "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="
            ],
            "dev-hadith-api.com": [
                // Development certificate hashes
                "CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC="
            ]
        ]
    }
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Validate a server trust for certificate pinning
    /// - Parameters:
    ///   - serverTrust: The server trust to validate
    ///   - domain: The domain being connected to
    /// - Returns: True if the certificate is valid and pinned
    func validateServerTrust(_ serverTrust: SecTrust, forDomain domain: String) -> Bool {
        guard PinningConfig.enabled else {
            if Environment.isDebug {
                print("🔓 Certificate pinning disabled")
            }
            return true // Allow all certificates when pinning is disabled
        }
        
        // Check if we have pinned certificates for this domain
        guard let pinnedHashes = PinningConfig.pinnedCertificates[domain] else {
            if Environment.isDebug {
                print("⚠️ No pinned certificates found for domain: \(domain)")
            }
            return !PinningConfig.requireHTTPS // Allow if HTTPS not required
        }
        
        // Evaluate the server trust
        var secresult = SecTrustResultType.invalid
        let status = SecTrustEvaluate(serverTrust, &secresult)
        
        guard status == errSecSuccess else {
            if Environment.isDebug {
                print("❌ Trust evaluation failed with status: \(status)")
            }
            return false
        }
        
        // Allow self-signed certificates in debug mode
        if PinningConfig.allowSelfSigned && Environment.isDebug {
            if Environment.isDebug {
                print("🔓 Allowing self-signed certificates in debug mode")
            }
            return true
        }
        
        // Check if the result is acceptable
        let acceptableResults: [SecTrustResultType] = [
            .unspecified, // Certificate is valid
            .proceed      // User explicitly accepted
        ]
        
        guard acceptableResults.contains(secresult) else {
            if Environment.isDebug {
                print("❌ Trust result not acceptable: \(secresult)")
            }
            return false
        }
        
        // Extract and validate certificate chain
        return validateCertificateChain(serverTrust, againstPinnedHashes: pinnedHashes)
    }
    
    /// Create a URLSession with certificate pinning
    /// - Returns: URLSession configured with certificate pinning
    func createPinnedURLSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Environment.requestTimeout
        config.timeoutIntervalForResource = Environment.resourceTimeout
        
        return URLSession(
            configuration: config,
            delegate: self,
            delegateQueue: nil
        )
    }
    
    // MARK: - Private Methods
    
    private func validateCertificateChain(_ serverTrust: SecTrust, againstPinnedHashes pinnedHashes: [String]) -> Bool {
        let certificateCount = SecTrustGetCertificateCount(serverTrust)
        
        if Environment.isDebug {
            print("🔍 Validating certificate chain with \(certificateCount) certificates")
        }
        
        // Check each certificate in the chain
        for i in 0..<certificateCount {
            guard let certificate = SecTrustGetCertificateAtIndex(serverTrust, i) else {
                continue
            }
            
            let publicKeyHash = extractPublicKeyHash(from: certificate)
            
            if pinnedHashes.contains(publicKeyHash) {
                if Environment.isDebug {
                    print("✅ Certificate pinning validation successful")
                }
                return true
            }
        }
        
        if Environment.isDebug {
            print("❌ No pinned certificate found in chain")
        }
        
        return false
    }
    
    private func extractPublicKeyHash(from certificate: SecCertificate) -> String {
        guard let publicKey = SecCertificateCopyKey(certificate) else {
            return ""
        }
        
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) else {
            return ""
        }
        
        let data = publicKeyData as Data
        let hash = SHA256.hash(data: data)
        return Data(hash).base64EncodedString()
    }
    
    private func extractCertificateData(from certificate: SecCertificate) -> Data? {
        return SecCertificateCopyData(certificate) as Data?
    }
}

// MARK: - URLSessionDelegate

extension CertificatePinning: URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        
        // Only handle server trust challenges
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            if Environment.isDebug {
                print("❌ No server trust available")
            }
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        let domain = challenge.protectionSpace.host
        
        if validateServerTrust(serverTrust, forDomain: domain) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            if Environment.isDebug {
                print("❌ Certificate pinning validation failed for domain: \(domain)")
            }
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

// MARK: - Certificate Management

extension CertificatePinning {
    /// Load certificate from bundle
    /// - Parameter filename: Certificate filename in bundle
    /// - Returns: Certificate data if found
    func loadCertificateFromBundle(filename: String) -> Data? {
        guard let path = Bundle.main.path(forResource: filename, ofType: "cer"),
              let certificateData = NSData(contentsOfFile: path) else {
            if Environment.isDebug {
                print("⚠️ Certificate file not found: \(filename).cer")
            }
            return nil
        }
        
        return certificateData as Data
    }
    
    /// Extract public key hash from certificate data
    /// - Parameter certificateData: Raw certificate data
    /// - Returns: Base64 encoded SHA-256 hash of public key
    func extractPublicKeyHash(from certificateData: Data) -> String? {
        guard let certificate = SecCertificateCreateWithData(nil, certificateData as CFData) else {
            return nil
        }
        
        return extractPublicKeyHash(from: certificate)
    }
    
    /// Validate a certificate against known good certificates
    /// - Parameters:
    ///   - certificateData: Certificate to validate
    ///   - trustedCertificates: Array of trusted certificate data
    /// - Returns: True if certificate matches one of the trusted certificates
    func validateCertificate(_ certificateData: Data, against trustedCertificates: [Data]) -> Bool {
        let certificateHash = SHA256.hash(data: certificateData)
        let certificateHashData = Data(certificateHash)
        
        for trustedCert in trustedCertificates {
            let trustedHash = SHA256.hash(data: trustedCert)
            let trustedHashData = Data(trustedHash)
            
            if certificateHashData == trustedHashData {
                return true
            }
        }
        
        return false
    }
}

// MARK: - Certificate Pinning Utilities

extension CertificatePinning {
    /// Generate certificate hashes for pinning (development helper)
    /// - Parameter domain: Domain to connect to and extract certificate
    func generateCertificateHashes(for domain: String, completion: @escaping ([String]) -> Void) {
        guard Environment.isDebug else {
            if Environment.isDebug {
                print("⚠️ Certificate hash generation only available in debug mode")
            }
            completion([])
            return
        }
        
        let url = URL(string: "https://\(domain)")!
        let task = URLSession.shared.dataTask(with: url) { _, response, error in
            if let error = error {
                print("❌ Failed to connect to \(domain): \(error)")
                completion([])
                return
            }
            
            // In a real implementation, you would extract the certificate
            // from the response and generate the hash
            print("ℹ️ Connected to \(domain) successfully")
            completion([])
        }
        
        task.resume()
    }
    
    /// Validate current certificate pinning configuration
    /// - Returns: Array of validation issues
    func validatePinningConfiguration() -> [String] {
        var issues: [String] = []
        
        if !PinningConfig.enabled && !Environment.isDebug {
            issues.append("Certificate pinning is disabled in production")
        }
        
        if PinningConfig.allowSelfSigned && !Environment.isDebug {
            issues.append("Self-signed certificates are allowed in production")
        }
        
        for (domain, hashes) in PinningConfig.pinnedCertificates {
            if hashes.isEmpty {
                issues.append("No certificate hashes configured for domain: \(domain)")
            }
            
            if hashes.count < 2 {
                issues.append("Only one certificate hash configured for domain: \(domain) (backup recommended)")
            }
            
            for hash in hashes {
                if hash.count != 44 { // Base64 encoded SHA-256 is 44 characters
                    issues.append("Invalid certificate hash format for domain: \(domain)")
                }
            }
        }
        
        return issues
    }
}

// MARK: - SHA-256 Implementation

import CryptoKit

extension CertificatePinning {
    private struct SHA256 {
        static func hash(data: Data) -> Data {
            let digest = CryptoKit.SHA256.hash(data: data)
            return Data(digest)
        }
    }
}

// MARK: - Error Types

enum CertificatePinningError: Error, LocalizedError {
    case noCertificateFound
    case invalidCertificate
    case pinningValidationFailed
    case noTrustedCertificates
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .noCertificateFound:
            return "No certificate found for validation"
        case .invalidCertificate:
            return "Invalid certificate format"
        case .pinningValidationFailed:
            return "Certificate pinning validation failed"
        case .noTrustedCertificates:
            return "No trusted certificates configured"
        case .networkError(let error):
            return "Network error during certificate validation: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noCertificateFound, .invalidCertificate:
            return "Please check your network connection and try again"
        case .pinningValidationFailed:
            return "This may indicate a security issue. Please check your connection and try again"
        case .noTrustedCertificates:
            return "Please update the app to the latest version"
        case .networkError:
            return "Please check your internet connection and try again"
        }
    }
}

// MARK: - Configuration Validation

#if DEBUG
extension CertificatePinning {
    /// Development helper to test certificate pinning
    func testCertificatePinning() {
        let issues = validatePinningConfiguration()
        
        if issues.isEmpty {
            print("✅ Certificate pinning configuration is valid")
        } else {
            print("⚠️ Certificate pinning configuration issues:")
            for issue in issues {
                print("  - \(issue)")
            }
        }
        
        // Test connection to each pinned domain
        for domain in PinningConfig.pinnedCertificates.keys {
            testConnection(to: domain)
        }
    }
    
    private func testConnection(to domain: String) {
        guard let url = URL(string: "https://\(domain)") else {
            print("❌ Invalid URL for domain: \(domain)")
            return
        }
        
        let session = createPinnedURLSession()
        let task = session.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Connection failed to \(domain): \(error.localizedDescription)")
            } else if let httpResponse = response as? HTTPURLResponse {
                print("✅ Connection successful to \(domain): \(httpResponse.statusCode)")
            }
        }
        
        task.resume()
    }
}
#endif
