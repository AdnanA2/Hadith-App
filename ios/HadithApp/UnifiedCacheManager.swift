import Foundation
import UIKit
import Combine

/// Unified cache manager with simplified design and better performance
class UnifiedCacheManager {
    static let shared = UnifiedCacheManager()
    
    // MARK: - Configuration
    
    private struct Config {
        static let memoryLimit = Environment.cacheSize
        static let maxAge = Environment.maxCacheAge
        static let cleanupInterval: TimeInterval = 24 * 3600 // 24 hours
    }
    
    // MARK: - Cache Instances
    
    private let memoryCache = NSCache<NSString, CacheItem>()
    private let diskCache: DiskCache
    private let cacheQueue = DispatchQueue(label: "cache.queue", attributes: .concurrent)
    private var cleanupTimer: Timer?
    
    // MARK: - Initialization
    
    private init() {
        self.diskCache = DiskCache()
        setupCache()
        startPeriodicCleanup()
        observeMemoryWarnings()
    }
    
    private func setupCache() {
        memoryCache.totalCostLimit = Config.memoryLimit
        memoryCache.countLimit = 1000
        
        if Environment.isDebug {
            Logger.shared.info("🗄️ Unified cache initialized - Memory: \(Config.memoryLimit / 1024 / 1024)MB")
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
                    expiration: expiration ?? Date().addingTimeInterval(Config.maxAge),
                    size: encodedData.count
                )
                
                self.memoryCache.setObject(cacheItem, forKey: key as NSString, cost: encodedData.count)
                self.diskCache.set(cacheItem, forKey: key)
                
                Logger.shared.debug("💾 Cached data for key: \(key) (\(encodedData.count) bytes)")
            } catch {
                Logger.shared.error("❌ Failed to cache data for key: \(key) - \(error)")
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
            if let cacheItem = memoryCache.object(forKey: key as NSString), cacheItem.isValid {
                return decodeData(cacheItem.data, type: type, source: "memory", key: key)
            }
            
            // Check disk cache
            if let cacheItem = diskCache.get(forKey: key), cacheItem.isValid {
                // Add to memory cache
                memoryCache.setObject(cacheItem, forKey: key as NSString, cost: cacheItem.size)
                return decodeData(cacheItem.data, type: type, source: "disk", key: key)
            }
            
            Logger.shared.debug("❌ Cache miss for key: \(key)")
            return nil
        }
    }
    
    /// Remove data from cache
    /// - Parameter key: Cache key
    func remove(forKey key: String) {
        cacheQueue.async(flags: .barrier) {
            self.memoryCache.removeObject(forKey: key as NSString)
            self.diskCache.remove(forKey: key)
            Logger.shared.debug("🗑️ Removed cache for key: \(key)")
        }
    }
    
    /// Clear all cached data
    func clearAll() {
        cacheQueue.async(flags: .barrier) {
            self.memoryCache.removeAllObjects()
            self.diskCache.clearAll()
            Logger.shared.info("🧹 Cleared all cache data")
        }
    }
    
    // MARK: - Image Caching (Simplified)
    
    /// Store image in cache
    /// - Parameters:
    ///   - image: Image to cache
    ///   - key: Cache key
    func setImage(_ image: UIImage, forKey key: String) {
        cacheQueue.async(flags: .barrier) {
            guard let data = image.jpegData(compressionQuality: 0.8) else {
                Logger.shared.error("❌ Failed to encode image for key: \(key)")
                return
            }
            
            let cacheItem = CacheItem(
                data: data,
                expiration: Date().addingTimeInterval(Config.maxAge),
                size: data.count
            )
            
            self.memoryCache.setObject(cacheItem, forKey: key as NSString, cost: data.count)
            self.diskCache.set(cacheItem, forKey: key)
            
            Logger.shared.debug("🖼️ Cached image for key: \(key) (\(data.count) bytes)")
        }
    }
    
    /// Retrieve image from cache
    /// - Parameter key: Cache key
    /// - Returns: Cached image if found
    func getImage(forKey key: String) -> UIImage? {
        return cacheQueue.sync {
            // Check memory cache first
            if let cacheItem = memoryCache.object(forKey: key as NSString), cacheItem.isValid {
                if let image = UIImage(data: cacheItem.data) {
                    Logger.shared.debug("🎯 Image cache hit (memory) for key: \(key)")
                    return image
                }
            }
            
            // Check disk cache
            if let cacheItem = diskCache.get(forKey: key), cacheItem.isValid {
                if let image = UIImage(data: cacheItem.data) {
                    memoryCache.setObject(cacheItem, forKey: key as NSString, cost: cacheItem.size)
                    Logger.shared.debug("🎯 Image cache hit (disk) for key: \(key)")
                    return image
                }
            }
            
            Logger.shared.debug("❌ Image cache miss for key: \(key)")
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    private func decodeData<T: Codable>(_ data: Data, type: T.Type, source: String, key: String) -> T? {
        do {
            let decoded = try JSONDecoder().decode(type, from: data)
            Logger.shared.debug("🎯 Cache hit (\(source)) for key: \(key)")
            return decoded
        } catch {
            Logger.shared.error("❌ Failed to decode cached data for key: \(key) - \(error)")
            return nil
        }
    }
    
    private func startPeriodicCleanup() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: Config.cleanupInterval, repeats: true) { [weak self] _ in
            self?.performCleanup()
        }
    }
    
    private func performCleanup() {
        cacheQueue.async(flags: .barrier) {
            let beforeCount = self.memoryCache.totalCostLimit
            self.memoryCache.removeAllObjects()
            self.diskCache.cleanup()
            Logger.shared.info("🧹 Cache cleanup completed")
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
            self.memoryCache.removeAllObjects()
            Logger.shared.warning("⚠️ Memory warning - cleared memory cache")
        }
    }
}

// MARK: - Cache Item

private struct CacheItem {
    let data: Data
    let expiration: Date
    let size: Int
    
    var isValid: Bool {
        return Date() < expiration
    }
}

// MARK: - Disk Cache (Simplified)

private class DiskCache {
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    init() {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("HadithCache")
        
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func set(_ item: CacheItem, forKey key: String) {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        let cacheData = CacheData(item: item, key: key)
        
        do {
            let data = try JSONEncoder().encode(cacheData)
            try data.write(to: fileURL)
        } catch {
            Logger.shared.error("❌ Failed to write to disk cache: \(error)")
        }
    }
    
    func get(forKey key: String) -> CacheItem? {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        
        guard let data = try? Data(contentsOf: fileURL),
              let cacheData = try? JSONDecoder().decode(CacheData.self, from: data),
              cacheData.item.isValid else {
            return nil
        }
        
        return cacheData.item
    }
    
    func remove(forKey key: String) {
        let fileURL = cacheDirectory.appendingPathComponent(key)
        try? fileManager.removeItem(at: fileURL)
    }
    
    func clearAll() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func cleanup() {
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        
        for fileURL in files {
            if let data = try? Data(contentsOf: fileURL),
               let cacheData = try? JSONDecoder().decode(CacheData.self, from: data),
               !cacheData.item.isValid {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
}

private struct CacheData: Codable {
    let item: CacheItem
    let key: String
}
