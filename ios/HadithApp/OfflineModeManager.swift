import Foundation
import Combine
import Network

/// Manages offline functionality and data synchronization
class OfflineModeManager: ObservableObject {
    static let shared = OfflineModeManager()
    
    // MARK: - Published Properties
    
    @Published var isOffline = false
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    
    // MARK: - Configuration
    
    private struct Config {
        static let enabled = Environment.offlineModeEnabled
        static let syncInterval: TimeInterval = 24 * 3600 // 24 hours
        static let maxOfflineData = 100 * 1024 * 1024 // 100MB
        static let essentialDataExpiry: TimeInterval = 7 * 24 * 3600 // 7 days
    }
    
    // MARK: - Properties
    
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "offline.network")
    private let syncQueue = DispatchQueue(label: "offline.sync", attributes: .concurrent)
    
    private var cancellables = Set<AnyCancellable>()
    private var pendingOperations: [OfflineOperation] = []
    private var syncTimer: Timer?
    
    private let cacheManager = AdvancedCacheManager.shared
    private let logger = Logger.shared
    
    // MARK: - Initialization
    
    private init() {
        setupNetworkMonitoring()
        setupSyncTimer()
        loadPendingOperations()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasOffline = self?.isOffline ?? false
                self?.isOffline = path.status != .satisfied
                
                if wasOffline && !self!.isOffline {
                    // Just came back online
                    self?.handleNetworkReconnection()
                }
                
                self?.logger.info("🌐 Network status: \(self?.isOffline == true ? "offline" : "online")")
            }
        }
        
        networkMonitor.start(queue: networkQueue)
    }
    
    private func setupSyncTimer() {
        guard Config.enabled else { return }
        
        syncTimer = Timer.scheduledTimer(withTimeInterval: Config.syncInterval, repeats: true) { [weak self] _ in
            if !self!.isOffline {
                self?.performBackgroundSync()
            }
        }
    }
    
    // MARK: - Offline Data Management
    
    /// Cache essential data for offline use
    func cacheEssentialData() {
        guard Config.enabled else { return }
        
        logger.info("📦 Caching essential data for offline use")
        syncStatus = .syncing
        
        let group = DispatchGroup()
        
        // Cache daily hadith
        group.enter()
        cacheDailyHadith { [weak self] in
            self?.logger.debug("✅ Cached daily hadith")
            group.leave()
        }
        
        // Cache collections
        group.enter()
        cacheCollections { [weak self] in
            self?.logger.debug("✅ Cached collections")
            group.leave()
        }
        
        // Cache user favorites
        if AuthenticationManager.shared.isAuthenticated {
            group.enter()
            cacheFavorites { [weak self] in
                self?.logger.debug("✅ Cached favorites")
                group.leave()
            }
        }
        
        // Cache recent hadiths
        group.enter()
        cacheRecentHadiths { [weak self] in
            self?.logger.debug("✅ Cached recent hadiths")
            group.leave()
        }
        
        group.notify(queue: .main) {
            self.syncStatus = .completed
            self.lastSyncDate = Date()
            self.logger.info("✅ Essential data cached successfully")
        }
    }
    
    /// Get cached data when offline
    func getCachedData<T: Codable>(forKey key: String, type: T.Type) -> T? {
        return cacheManager.get(forKey: key, type: type)
    }
    
    /// Store data for offline access
    func storeForOfflineAccess<T: Codable>(_ data: T, forKey key: String) {
        let expiration = Date().addingTimeInterval(Config.essentialDataExpiry)
        cacheManager.set(data, forKey: key, expiration: expiration)
    }
    
    // MARK: - Offline Operations Queue
    
    /// Queue an operation to be performed when back online
    func queueOperation(_ operation: OfflineOperation) {
        syncQueue.async(flags: .barrier) {
            self.pendingOperations.append(operation)
            self.savePendingOperations()
            
            self.logger.info("📋 Queued offline operation: \(operation.type)")
        }
    }
    
    /// Process all pending operations
    func processPendingOperations() {
        guard !isOffline else {
            logger.warning("⚠️ Cannot process pending operations while offline")
            return
        }
        
        syncQueue.async(flags: .barrier) {
            let operations = self.pendingOperations
            self.pendingOperations.removeAll()
            
            DispatchQueue.main.async {
                self.syncStatus = .syncing
            }
            
            let group = DispatchGroup()
            
            for operation in operations {
                group.enter()
                self.executeOperation(operation) { success in
                    if !success {
                        // Re-queue failed operations
                        self.pendingOperations.append(operation)
                    }
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                self.syncStatus = .completed
                self.savePendingOperations()
                self.logger.info("✅ Processed \(operations.count) pending operations")
            }
        }
    }
    
    // MARK: - Sync Management
    
    /// Perform full data synchronization
    func performFullSync() -> AnyPublisher<Void, Error> {
        guard !isOffline else {
            return Fail(error: OfflineError.noNetworkConnection)
                .eraseToAnyPublisher()
        }
        
        logger.info("🔄 Starting full sync")
        syncStatus = .syncing
        
        return Publishers.Zip4(
            syncDailyHadith(),
            syncCollections(),
            syncFavorites(),
            syncUserData()
        )
        .map { _ in () }
        .handleEvents(
            receiveOutput: { [weak self] _ in
                DispatchQueue.main.async {
                    self?.syncStatus = .completed
                    self?.lastSyncDate = Date()
                    self?.logger.info("✅ Full sync completed")
                }
            },
            receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    DispatchQueue.main.async {
                        self?.syncStatus = .failed(error)
                        self?.logger.error("❌ Full sync failed: \(error)")
                    }
                }
            }
        )
        .eraseToAnyPublisher()
    }
    
    /// Perform background sync of essential data
    private func performBackgroundSync() {
        guard !isOffline else { return }
        
        logger.info("🔄 Starting background sync")
        
        performFullSync()
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        self.logger.warning("⚠️ Background sync failed: \(error)")
                    }
                },
                receiveValue: { _ in
                    self.logger.info("✅ Background sync completed")
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Network Recovery
    
    private func handleNetworkReconnection() {
        logger.info("🌐 Network reconnected - processing pending operations")
        
        // Process pending operations
        processPendingOperations()
        
        // Perform background sync if needed
        if shouldPerformSync() {
            performBackgroundSync()
        }
    }
    
    private func shouldPerformSync() -> Bool {
        guard let lastSync = lastSyncDate else { return true }
        return Date().timeIntervalSince(lastSync) > Config.syncInterval
    }
    
    // MARK: - Data Caching Methods
    
    private func cacheDailyHadith(completion: @escaping () -> Void) {
        HadithService.shared.getDailyHadith()
            .sink(
                receiveCompletion: { _ in completion() },
                receiveValue: { [weak self] response in
                    self?.storeForOfflineAccess(response, forKey: "daily_hadith")
                    completion()
                }
            )
            .store(in: &cancellables)
    }
    
    private func cacheCollections(completion: @escaping () -> Void) {
        HadithService.shared.getCollections()
            .sink(
                receiveCompletion: { _ in completion() },
                receiveValue: { [weak self] response in
                    self?.storeForOfflineAccess(response, forKey: "collections")
                    completion()
                }
            )
            .store(in: &cancellables)
    }
    
    private func cacheFavorites(completion: @escaping () -> Void) {
        HadithService.shared.getFavorites()
            .sink(
                receiveCompletion: { _ in completion() },
                receiveValue: { [weak self] response in
                    self?.storeForOfflineAccess(response, forKey: "favorites")
                    completion()
                }
            )
            .store(in: &cancellables)
    }
    
    private func cacheRecentHadiths(completion: @escaping () -> Void) {
        HadithService.shared.getHadiths(page: 1, pageSize: 50)
            .sink(
                receiveCompletion: { _ in completion() },
                receiveValue: { [weak self] response in
                    self?.storeForOfflineAccess(response, forKey: "recent_hadiths")
                    completion()
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Sync Publishers
    
    private func syncDailyHadith() -> AnyPublisher<Void, Error> {
        return HadithService.shared.getDailyHadith()
            .map { [weak self] response in
                self?.storeForOfflineAccess(response, forKey: "daily_hadith")
            }
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
    
    private func syncCollections() -> AnyPublisher<Void, Error> {
        return HadithService.shared.getCollections()
            .map { [weak self] response in
                self?.storeForOfflineAccess(response, forKey: "collections")
            }
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
    
    private func syncFavorites() -> AnyPublisher<Void, Error> {
        guard AuthenticationManager.shared.isAuthenticated else {
            return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        
        return HadithService.shared.getFavorites()
            .map { [weak self] response in
                self?.storeForOfflineAccess(response, forKey: "favorites")
            }
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
    
    private func syncUserData() -> AnyPublisher<Void, Error> {
        guard AuthenticationManager.shared.isAuthenticated else {
            return Just(()).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        
        return AuthenticationManager.shared.getCurrentUser()
            .map { [weak self] response in
                self?.storeForOfflineAccess(response, forKey: "user_data")
            }
            .mapError { $0 as Error }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Operation Execution
    
    private func executeOperation(_ operation: OfflineOperation, completion: @escaping (Bool) -> Void) {
        switch operation.type {
        case .addFavorite:
            executeFavoriteOperation(operation, completion: completion)
        case .removeFavorite:
            executeRemoveFavoriteOperation(operation, completion: completion)
        case .updateProfile:
            executeProfileUpdateOperation(operation, completion: completion)
        case .syncData:
            performFullSync()
                .sink(
                    receiveCompletion: { result in
                        completion(result == .finished)
                    },
                    receiveValue: { _ in }
                )
                .store(in: &cancellables)
        }
    }
    
    private func executeFavoriteOperation(_ operation: OfflineOperation, completion: @escaping (Bool) -> Void) {
        guard let hadithId = operation.data["hadith_id"] as? String else {
            completion(false)
            return
        }
        
        let notes = operation.data["notes"] as? String
        
        HadithService.shared.addFavorite(hadithId: hadithId, notes: notes)
            .sink(
                receiveCompletion: { result in
                    completion(result == .finished)
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    private func executeRemoveFavoriteOperation(_ operation: OfflineOperation, completion: @escaping (Bool) -> Void) {
        guard let favoriteId = operation.data["favorite_id"] as? Int else {
            completion(false)
            return
        }
        
        HadithService.shared.removeFavorite(by: favoriteId)
            .sink(
                receiveCompletion: { result in
                    completion(result == .finished)
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    private func executeProfileUpdateOperation(_ operation: OfflineOperation, completion: @escaping (Bool) -> Void) {
        guard let updateData = operation.data["update"] as? [String: Any] else {
            completion(false)
            return
        }
        
        let userUpdate = UserUpdate(
            full_name: updateData["full_name"] as? String,
            password: updateData["password"] as? String
        )
        
        AuthenticationManager.shared.updateProfile(userUpdate)
            .sink(
                receiveCompletion: { result in
                    completion(result == .finished)
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Persistence
    
    private func loadPendingOperations() {
        let key = "pending_offline_operations"
        
        if let data = UserDefaults.standard.data(forKey: key) {
            do {
                pendingOperations = try JSONDecoder().decode([OfflineOperation].self, from: data)
                logger.info("📋 Loaded \(pendingOperations.count) pending operations")
            } catch {
                logger.error("❌ Failed to load pending operations: \(error)")
            }
        }
    }
    
    private func savePendingOperations() {
        let key = "pending_offline_operations"
        
        do {
            let data = try JSONEncoder().encode(pendingOperations)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            logger.error("❌ Failed to save pending operations: \(error)")
        }
    }
    
    // MARK: - Cleanup
    
    func clearOfflineData() {
        cacheManager.clearAll()
        pendingOperations.removeAll()
        savePendingOperations()
        lastSyncDate = nil
        
        logger.info("🗑️ Cleared all offline data")
    }
    
    deinit {
        networkMonitor.cancel()
        syncTimer?.invalidate()
    }
}

// MARK: - Supporting Types

enum SyncStatus: Equatable {
    case idle
    case syncing
    case completed
    case failed(Error)
    
    static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing), (.completed, .completed):
            return true
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}

struct OfflineOperation: Codable {
    let id: UUID
    let type: OperationType
    let data: [String: Any]
    let timestamp: Date
    
    enum OperationType: String, Codable {
        case addFavorite = "add_favorite"
        case removeFavorite = "remove_favorite"
        case updateProfile = "update_profile"
        case syncData = "sync_data"
    }
    
    enum CodingKeys: String, CodingKey {
        case id, type, data, timestamp
    }
    
    init(id: UUID = UUID(), type: OperationType, data: [String: Any], timestamp: Date = Date()) {
        self.id = id
        self.type = type
        self.data = data
        self.timestamp = timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(OperationType.self, forKey: .type)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        
        // Decode data as JSON
        let dataContainer = try container.nestedContainer(keyedBy: DynamicKey.self, forKey: .data)
        var decodedData: [String: Any] = [:]
        
        for key in dataContainer.allKeys {
            if let stringValue = try? dataContainer.decode(String.self, forKey: key) {
                decodedData[key.stringValue] = stringValue
            } else if let intValue = try? dataContainer.decode(Int.self, forKey: key) {
                decodedData[key.stringValue] = intValue
            } else if let boolValue = try? dataContainer.decode(Bool.self, forKey: key) {
                decodedData[key.stringValue] = boolValue
            }
        }
        
        data = decodedData
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(timestamp, forKey: .timestamp)
        
        // Encode data as JSON
        var dataContainer = container.nestedContainer(keyedBy: DynamicKey.self, forKey: .data)
        
        for (key, value) in data {
            let codingKey = DynamicKey(stringValue: key)!
            
            if let stringValue = value as? String {
                try dataContainer.encode(stringValue, forKey: codingKey)
            } else if let intValue = value as? Int {
                try dataContainer.encode(intValue, forKey: codingKey)
            } else if let boolValue = value as? Bool {
                try dataContainer.encode(boolValue, forKey: codingKey)
            }
        }
    }
}

struct DynamicKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
    }
    
    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = "\(intValue)"
    }
}

enum OfflineError: Error, LocalizedError {
    case noNetworkConnection
    case offlineModeDisabled
    case syncFailed(Error)
    case dataNotAvailable
    
    var errorDescription: String? {
        switch self {
        case .noNetworkConnection:
            return "No network connection available"
        case .offlineModeDisabled:
            return "Offline mode is disabled"
        case .syncFailed(let error):
            return "Sync failed: \(error.localizedDescription)"
        case .dataNotAvailable:
            return "Data not available offline"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noNetworkConnection:
            return "Please check your internet connection and try again"
        case .offlineModeDisabled:
            return "Enable offline mode in settings"
        case .syncFailed:
            return "Try syncing again when you have a stable connection"
        case .dataNotAvailable:
            return "This data requires an internet connection"
        }
    }
}

// MARK: - Convenience Extensions

extension OfflineModeManager {
    /// Check if specific data is available offline
    func isDataAvailableOffline(forKey key: String) -> Bool {
        return getCachedData(forKey: key, type: Data.self) != nil
    }
    
    /// Get offline data size
    func getOfflineDataSize() -> Int {
        let stats = cacheManager.getStatistics()
        return stats.diskSizeBytes
    }
    
    /// Queue favorite operation for offline processing
    func queueFavoriteOperation(hadithId: String, notes: String? = nil) {
        let operation = OfflineOperation(
            type: .addFavorite,
            data: [
                "hadith_id": hadithId,
                "notes": notes ?? ""
            ]
        )
        queueOperation(operation)
    }
    
    /// Queue unfavorite operation for offline processing
    func queueUnfavoriteOperation(favoriteId: Int) {
        let operation = OfflineOperation(
            type: .removeFavorite,
            data: ["favorite_id": favoriteId]
        )
        queueOperation(operation)
    }
}
