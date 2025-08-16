import Foundation
import UIKit
import Combine

/// Advanced caching system with memory and disk caching, image support, and automatic cleanup
class AdvancedCacheManager {
    static let shared = AdvancedCacheManager()
    
    // MARK: - Cache Configuration
    
    private struct CacheConfig {
        static let memoryLimit = Environment.cacheSize
        static let diskLimit = Environment.cacheSize * 2
        static let imageMemoryLimit = Environment.imageCacheSize
        static let maxAge = Environment.maxCacheAge
        static let cleanupInterval: TimeInterval = 24 * 3600 // 24 hours
    }
    
    // MARK: - Cache Instances
    
    private let memoryCache = NSCache<NSString, CacheItem>()
    private let imageMemoryCache = NSCache<NSString, UIImage>()
    private let diskCache: DiskCache
    private let cacheQueue = DispatchQueue(label: "cache.queue", attributes: .concurrent)
    private var cleanupTimer: Timer?
    
    // MARK: - Initialization
    
    private init() {
        self.diskCache = DiskCache()
        setupCaches()
        startPeriodicCleanup()
        observeMemoryWarnings()
    }
    
    private func setupCaches() {
        // Memory cache configuration
        memoryCache.totalCostLimit = CacheConfig.memoryLimit
        memoryCache.countLimit = 1000
        
        // Image memory cache configuration
        imageMemoryCache.totalCostLimit = CacheConfig.imageMemoryLimit
        imageMemoryCache.countLimit = 200
        
        if Environment.isDebug {
            print("🗄️ Cache initialized - Memory: \(CacheConfig.memoryLimit / 1024 / 1024)MB, Images: \(CacheConfig.imageMemoryLimit / 1024 / 1024)MB")
        }
    }
    
    // MARK: - Generic Data Caching
    
    /// Store data in cache
    /// - Parameters:
    ///   - data: Data to cache
    ///   - key: Cache key
    ///   - expiration: Optional expiration date
    func set<T: Codable>(_ data: T, forKey key: String, expiration: Date? = nil) {
        cacheQueue.async(flags: .barrier) {
            do {
                let encodedData = try JSONEncoder().encode(data)
                let cacheItem = CacheItem(
                    data: encodedData,
                    expiration: expiration ?? Date().addingTimeInterval(CacheConfig.maxAge),
                    size: encodedData.count
                )
                
                // Store in memory cache
                self.memoryCache.setObject(cacheItem, forKey: key as NSString, cost: encodedData.count)
                
                // Store in disk cache
                self.diskCache.set(cacheItem, forKey: key)
                
                if Environment.isDebug {
                    print("💾 Cached data for key: \(key) (\(encodedData.count) bytes)")
                }
            } catch {
                if Environment.isDebug {
                    print("❌ Failed to cache data for key: \(key) - \(error)")
                }
            }
        }
    }
    
    /// Retrieve data from cache
    /// - Parameters:
    ///   - key: Cache key
    ///   - type: Expected data type
    /// - Returns: Cached data if found and not expired
    func get<T: Codable>(forKey key: String, type: T.Type) -> T? {
        return cacheQueue.sync {
            // Check memory cache first
            if let cacheItem = memoryCache.object(forKey: key as NSString) {
                if cacheItem.isValid {
                    do {
                        let data = try JSONDecoder().decode(type, from: cacheItem.data)
                        if Environment.isDebug {
                            print("🎯 Cache hit (memory) for key: \(key)")
                        }
                        return data
                    } catch {
                        if Environment.isDebug {
                            print("❌ Failed to decode cached data for key: \(key) - \(error)")
                        }
                    }
                } else {
                    // Remove expired item
                    memoryCache.removeObject(forKey: key as NSString)
                }
            }
            
            // Check disk cache
            if let cacheItem = diskCache.get(forKey: key), cacheItem.isValid {
                do {
                    let data = try JSONDecoder().decode(type, from: cacheItem.data)
                    
                    // Restore to memory cache
                    memoryCache.setObject(cacheItem, forKey: key as NSString, cost: cacheItem.size)
                    
                    if Environment.isDebug {
                        print("🎯 Cache hit (disk) for key: \(key)")
                    }
                    return data
                } catch {
                    if Environment.isDebug {
                        print("❌ Failed to decode cached data from disk for key: \(key) - \(error)")
                    }
                }
            }
            
            if Environment.isDebug {
                print("❌ Cache miss for key: \(key)")
            }
            return nil
        }
    }
    
    // MARK: - Image Caching
    
    /// Cache an image
    /// - Parameters:
    ///   - image: Image to cache
    ///   - key: Cache key (usually URL string)
    func setImage(_ image: UIImage, forKey key: String) {
        cacheQueue.async(flags: .barrier) {
            // Store in memory cache
            let imageSizeBytes = self.estimateImageSize(image)
            self.imageMemoryCache.setObject(image, forKey: key as NSString, cost: imageSizeBytes)
            
            // Store in disk cache
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                let cacheItem = CacheItem(
                    data: imageData,
                    expiration: Date().addingTimeInterval(CacheConfig.maxAge),
                    size: imageData.count
                )
                self.diskCache.set(cacheItem, forKey: "image_\(key)")
                
                if Environment.isDebug {
                    print("🖼️ Cached image for key: \(key) (\(imageData.count) bytes)")
                }
            }
        }
    }
    
    /// Retrieve cached image
    /// - Parameter key: Cache key
    /// - Returns: Cached image if found
    func getImage(forKey key: String) -> UIImage? {
        return cacheQueue.sync {
            // Check memory cache first
            if let image = imageMemoryCache.object(forKey: key as NSString) {
                if Environment.isDebug {
                    print("🎯 Image cache hit (memory) for key: \(key)")
                }
                return image
            }
            
            // Check disk cache
            if let cacheItem = diskCache.get(forKey: "image_\(key)"), cacheItem.isValid {
                if let image = UIImage(data: cacheItem.data) {
                    // Restore to memory cache
                    let imageSizeBytes = estimateImageSize(image)
                    imageMemoryCache.setObject(image, forKey: key as NSString, cost: imageSizeBytes)
                    
                    if Environment.isDebug {
                        print("🎯 Image cache hit (disk) for key: \(key)")
                    }
                    return image
                }
            }
            
            if Environment.isDebug {
                print("❌ Image cache miss for key: \(key)")
            }
            return nil
        }
    }
    
    /// Load image from URL with caching
    /// - Parameter url: Image URL
    /// - Returns: Publisher that emits cached or downloaded image
    func loadImage(from url: URL) -> AnyPublisher<UIImage, Error> {
        let key = url.absoluteString
        
        // Check cache first
        if let cachedImage = getImage(forKey: key) {
            return Just(cachedImage)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // Download and cache
        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .compactMap { UIImage(data: $0) }
            .handleEvents(receiveOutput: { [weak self] image in
                self?.setImage(image, forKey: key)
            })
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Cache Management
    
    /// Remove item from cache
    /// - Parameter key: Cache key
    func remove(forKey key: String) {
        cacheQueue.async(flags: .barrier) {
            self.memoryCache.removeObject(forKey: key as NSString)
            self.imageMemoryCache.removeObject(forKey: key as NSString)
            self.diskCache.remove(forKey: key)
            self.diskCache.remove(forKey: "image_\(key)")
            
            if Environment.isDebug {
                print("🗑️ Removed cache for key: \(key)")
            }
        }
    }
    
    /// Clear all cached data
    func clearAll() {
        cacheQueue.async(flags: .barrier) {
            self.memoryCache.removeAllObjects()
            self.imageMemoryCache.removeAllObjects()
            self.diskCache.clearAll()
            
            if Environment.isDebug {
                print("🗑️ Cleared all cache")
            }
        }
    }
    
    /// Clear expired items
    func clearExpired() {
        cacheQueue.async(flags: .barrier) {
            self.diskCache.clearExpired()
            
            if Environment.isDebug {
                print("🧹 Cleared expired cache items")
            }
        }
    }
    
    /// Get cache statistics
    /// - Returns: Cache usage statistics
    func getStatistics() -> CacheStatistics {
        return cacheQueue.sync {
            let diskStats = diskCache.getStatistics()
            
            return CacheStatistics(
                memoryItemCount: memoryCache.totalCount,
                imageMemoryItemCount: imageMemoryCache.totalCount,
                diskItemCount: diskStats.itemCount,
                diskSizeBytes: diskStats.sizeBytes,
                memorySizeBytes: 0 // NSCache doesn't provide this
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func estimateImageSize(_ image: UIImage) -> Int {
        let pixelCount = Int(image.size.width * image.size.height * image.scale * image.scale)
        return pixelCount * 4 // 4 bytes per pixel (RGBA)
    }
    
    private func startPeriodicCleanup() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: CacheConfig.cleanupInterval, repeats: true) { [weak self] _ in
            self?.clearExpired()
        }
    }
    
    private func observeMemoryWarnings() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }
    
    private func handleMemoryWarning() {
        cacheQueue.async(flags: .barrier) {
            // Clear memory caches on memory warning
            self.memoryCache.removeAllObjects()
            self.imageMemoryCache.removeAllObjects()
            
            if Environment.isDebug {
                print("⚠️ Memory warning - cleared memory caches")
            }
        }
    }
    
    deinit {
        cleanupTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Cache Item

private class CacheItem: NSObject {
    let data: Data
    let expiration: Date
    let size: Int
    let createdAt: Date
    
    init(data: Data, expiration: Date, size: Int) {
        self.data = data
        self.expiration = expiration
        self.size = size
        self.createdAt = Date()
        super.init()
    }
    
    var isValid: Bool {
        return Date() < expiration
    }
    
    var age: TimeInterval {
        return Date().timeIntervalSince(createdAt)
    }
}

// MARK: - Disk Cache

private class DiskCache {
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let metadataFile: URL
    private var metadata: [String: CacheMetadata] = [:]
    
    init() {
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cachesDirectory.appendingPathComponent("HadithAppCache")
        metadataFile = cacheDirectory.appendingPathComponent("metadata.plist")
        
        createCacheDirectoryIfNeeded()
        loadMetadata()
    }
    
    func set(_ item: CacheItem, forKey key: String) {
        let fileURL = cacheDirectory.appendingPathComponent(key.sha256)
        
        do {
            try item.data.write(to: fileURL)
            
            metadata[key] = CacheMetadata(
                filename: key.sha256,
                expiration: item.expiration,
                size: item.size,
                createdAt: item.createdAt
            )
            
            saveMetadata()
        } catch {
            if Environment.isDebug {
                print("❌ Failed to write cache file: \(error)")
            }
        }
    }
    
    func get(forKey key: String) -> CacheItem? {
        guard let meta = metadata[key] else { return nil }
        
        let fileURL = cacheDirectory.appendingPathComponent(meta.filename)
        
        do {
            let data = try Data(contentsOf: fileURL)
            return CacheItem(data: data, expiration: meta.expiration, size: meta.size)
        } catch {
            // File might have been deleted, clean up metadata
            metadata.removeValue(forKey: key)
            saveMetadata()
            return nil
        }
    }
    
    func remove(forKey key: String) {
        guard let meta = metadata[key] else { return }
        
        let fileURL = cacheDirectory.appendingPathComponent(meta.filename)
        try? fileManager.removeItem(at: fileURL)
        
        metadata.removeValue(forKey: key)
        saveMetadata()
    }
    
    func clearAll() {
        try? fileManager.removeItem(at: cacheDirectory)
        createCacheDirectoryIfNeeded()
        metadata.removeAll()
        saveMetadata()
    }
    
    func clearExpired() {
        let now = Date()
        var expiredKeys: [String] = []
        
        for (key, meta) in metadata {
            if now >= meta.expiration {
                expiredKeys.append(key)
            }
        }
        
        for key in expiredKeys {
            remove(forKey: key)
        }
    }
    
    func getStatistics() -> DiskCacheStatistics {
        let itemCount = metadata.count
        let sizeBytes = metadata.values.reduce(0) { $0 + $1.size }
        
        return DiskCacheStatistics(itemCount: itemCount, sizeBytes: sizeBytes)
    }
    
    private func createCacheDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    private func loadMetadata() {
        guard fileManager.fileExists(atPath: metadataFile.path) else { return }
        
        do {
            let data = try Data(contentsOf: metadataFile)
            let decoder = PropertyListDecoder()
            metadata = try decoder.decode([String: CacheMetadata].self, from: data)
        } catch {
            if Environment.isDebug {
                print("⚠️ Failed to load cache metadata: \(error)")
            }
        }
    }
    
    private func saveMetadata() {
        do {
            let encoder = PropertyListEncoder()
            let data = try encoder.encode(metadata)
            try data.write(to: metadataFile)
        } catch {
            if Environment.isDebug {
                print("❌ Failed to save cache metadata: \(error)")
            }
        }
    }
}

// MARK: - Supporting Types

private struct CacheMetadata: Codable {
    let filename: String
    let expiration: Date
    let size: Int
    let createdAt: Date
}

struct CacheStatistics {
    let memoryItemCount: Int
    let imageMemoryItemCount: Int
    let diskItemCount: Int
    let diskSizeBytes: Int
    let memorySizeBytes: Int
    
    var totalSizeMB: Double {
        return Double(diskSizeBytes + memorySizeBytes) / 1024.0 / 1024.0
    }
    
    var diskSizeMB: Double {
        return Double(diskSizeBytes) / 1024.0 / 1024.0
    }
}

struct DiskCacheStatistics {
    let itemCount: Int
    let sizeBytes: Int
}

// MARK: - String Extensions

private extension String {
    var sha256: String {
        let data = Data(self.utf8)
        let hash = data.withUnsafeBytes { bytes in
            return SHA256.hash(data: Data(bytes))
        }
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Image Loading Extensions

extension AdvancedCacheManager {
    /// Create an image loading publisher with retry logic
    /// - Parameters:
    ///   - url: Image URL
    ///   - maxRetries: Maximum retry attempts
    /// - Returns: Publisher that emits image with retry logic
    func loadImageWithRetry(from url: URL, maxRetries: Int = 2) -> AnyPublisher<UIImage, Error> {
        loadImage(from: url)
            .retry(maxRetries)
            .eraseToAnyPublisher()
    }
    
    /// Preload images from URLs
    /// - Parameter urls: Array of image URLs to preload
    func preloadImages(_ urls: [URL]) {
        for url in urls {
            loadImage(from: url)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            if Environment.isDebug {
                                print("⚠️ Failed to preload image \(url): \(error)")
                            }
                        }
                    },
                    receiveValue: { _ in
                        if Environment.isDebug {
                            print("✅ Preloaded image: \(url)")
                        }
                    }
                )
                .store(in: &Set<AnyCancellable>())
        }
    }
}

// MARK: - Cache Warming

extension AdvancedCacheManager {
    /// Warm up cache with essential data
    func warmUpCache() {
        // This could preload daily hadith, collections, etc.
        if Environment.isDebug {
            print("🔥 Warming up cache...")
        }
        
        // Example: Preload collections
        // HadithService.shared.getCollections()
        //     .sink(...) { collections in
        //         self.set(collections, forKey: "collections")
        //     }
    }
    
    /// Smart cache eviction based on usage patterns
    func performSmartEviction() {
        // This could implement LRU or other intelligent eviction strategies
        // For now, just clear expired items
        clearExpired()
    }
}

// MARK: - SHA-256 Implementation

import CryptoKit

private struct SHA256 {
    static func hash(data: Data) -> Data {
        let digest = CryptoKit.SHA256.hash(data: data)
        return Data(digest)
    }
}
