import Foundation
import Combine
import Network
import UIKit

/// Unified monitoring service for analytics, network status, and app performance
class MonitoringService: ObservableObject {
    static let shared = MonitoringService()
    
    // MARK: - Published Properties
    
    @Published var isOffline = false
    @Published var networkQuality: NetworkQuality = .unknown
    
    // MARK: - Configuration
    
    private struct Config {
        static let analyticsEnabled = Environment.analyticsEnabled
        static let batchSize = 50
        static let flushInterval: TimeInterval = 30.0
        static let maxQueueSize = 1000
        static let sessionTimeout: TimeInterval = 30 * 60 // 30 minutes
    }
    
    // MARK: - Properties
    
    private var eventQueue: [AnalyticsEvent] = []
    private var userProperties: [String: Any] = [:]
    private var sessionId: String = UUID().uuidString
    private var sessionStartTime = Date()
    private var lastEventTime = Date()
    private var flushTimer: Timer?
    
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "monitoring.network")
    private let analyticsQueue = DispatchQueue(label: "monitoring.analytics", attributes: .concurrent)
    private var cancellables = Set<AnyCancellable>()
    
    private let logger = Logger.shared
    
    // MARK: - Initialization
    
    private init() {
        setupMonitoring()
        startFlushTimer()
        observeAppLifecycle()
    }
    
    private func setupMonitoring() {
        setupNetworkMonitoring()
        setupAnalytics()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasOffline = self?.isOffline ?? false
                self?.isOffline = path.status != .satisfied
                self?.networkQuality = self?.determineNetworkQuality(path) ?? .unknown
                
                if wasOffline && !self!.isOffline {
                    self?.handleNetworkReconnection()
                }
                
                self?.logger.info("🌐 Network status: \(self?.isOffline == true ? "offline" : "online") - Quality: \(self?.networkQuality.rawValue ?? "unknown")")
            }
        }
        
        networkMonitor.start(queue: networkQueue)
    }
    
    private func setupAnalytics() {
        guard Config.analyticsEnabled else {
            logger.info("📊 Analytics disabled")
            return
        }
        
        // Set default user properties
        setUserProperties([
            "app_version": Environment.appVersion,
            "build_number": Environment.buildNumber,
            "ios_version": UIDevice.current.systemVersion,
            "device_model": UIDevice.current.model,
            "device_name": UIDevice.current.name,
            "locale": Locale.current.identifier,
            "timezone": TimeZone.current.identifier
        ])
        
        logger.info("📊 Analytics initialized")
    }
    
    // MARK: - Analytics Methods
    
    /// Track a custom event
    /// - Parameters:
    ///   - name: Event name
    ///   - properties: Optional event properties
    func track(_ name: String, properties: [String: Any]? = nil) {
        guard Config.analyticsEnabled else { return }
        
        analyticsQueue.async(flags: .barrier) {
            let event = AnalyticsEvent(
                name: name,
                properties: properties ?? [:],
                timestamp: Date(),
                sessionId: self.sessionId,
                userId: self.getCurrentUserId()
            )
            
            self.addEvent(event)
            self.logger.debug("📊 Tracked event: \(name)")
        }
    }
    
    /// Track screen view
    /// - Parameters:
    ///   - screenName: Name of the screen
    ///   - properties: Optional screen properties
    func trackScreen(_ screenName: String, properties: [String: Any]? = nil) {
        var screenProperties = properties ?? [:]
        screenProperties["screen_name"] = screenName
        
        track("screen_view", properties: screenProperties)
    }
    
    /// Track user action
    /// - Parameters:
    ///   - action: Action name
    ///   - target: Target of the action
    ///   - properties: Optional action properties
    func trackAction(_ action: String, target: String? = nil, properties: [String: Any]? = nil) {
        var actionProperties = properties ?? [:]
        actionProperties["action"] = action
        if let target = target {
            actionProperties["target"] = target
        }
        
        track("user_action", properties: actionProperties)
    }
    
    /// Track error
    /// - Parameters:
    ///   - error: Error to track
    ///   - context: Error context
    ///   - properties: Optional error properties
    func trackError(_ error: Error, context: String? = nil, properties: [String: Any]? = nil) {
        var errorProperties = properties ?? [:]
        errorProperties["error_type"] = String(describing: type(of: error))
        errorProperties["error_message"] = error.localizedDescription
        if let context = context {
            errorProperties["context"] = context
        }
        
        track("error", properties: errorProperties)
    }
    
    /// Set user properties
    /// - Parameter properties: User properties dictionary
    func setUserProperties(_ properties: [String: Any]) {
        analyticsQueue.async(flags: .barrier) {
            self.userProperties.merge(properties) { _, new in new }
        }
    }
    
    // MARK: - Network Monitoring Methods
    
    /// Check if device is online
    /// - Returns: True if online, false otherwise
    func isOnline() -> Bool {
        return !isOffline
    }
    
    /// Get current network quality
    /// - Returns: Network quality level
    func getNetworkQuality() -> NetworkQuality {
        return networkQuality
    }
    
    // MARK: - Private Methods
    
    private func determineNetworkQuality(_ path: NWPath) -> NetworkQuality {
        if path.status != .satisfied {
            return .offline
        }
        
        if path.usesInterfaceType(.wifi) {
            return .excellent
        } else if path.usesInterfaceType(.cellular) {
            return .good
        } else {
            return .fair
        }
    }
    
    private func handleNetworkReconnection() {
        logger.info("🔄 Network reconnected - triggering sync")
        track("network_reconnected")
        
        // Trigger any pending operations
        NotificationCenter.default.post(name: .networkReconnected, object: nil)
    }
    
    private func addEvent(_ event: AnalyticsEvent) {
        analyticsQueue.async(flags: .barrier) {
            self.eventQueue.append(event)
            
            if self.eventQueue.count >= Config.batchSize {
                self.flushEvents()
            }
        }
    }
    
    private func flushEvents() {
        guard !eventQueue.isEmpty else { return }
        
        let eventsToFlush = Array(eventQueue.prefix(Config.batchSize))
        eventQueue.removeFirst(min(Config.batchSize, eventQueue.count))
        
        // In a real app, you would send these to your analytics service
        logger.debug("📊 Flushed \(eventsToFlush.count) analytics events")
    }
    
    private func startFlushTimer() {
        guard Config.analyticsEnabled else { return }
        
        flushTimer = Timer.scheduledTimer(withTimeInterval: Config.flushInterval, repeats: true) { [weak self] _ in
            self?.flushEvents()
        }
    }
    
    private func observeAppLifecycle() {
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppBecameActive()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppWillResignActive()
            }
            .store(in: &cancellables)
    }
    
    private func handleAppBecameActive() {
        // Start new session if needed
        let timeSinceLastEvent = Date().timeIntervalSince(lastEventTime)
        if timeSinceLastEvent > Config.sessionTimeout {
            sessionId = UUID().uuidString
            sessionStartTime = Date()
        }
        
        lastEventTime = Date()
        track("app_opened")
    }
    
    private func handleAppWillResignActive() {
        flushEvents()
        track("app_closed")
    }
    
    private func getCurrentUserId() -> String? {
        return AuthenticationManager.shared.currentUser?.id.description
    }
}

// MARK: - Supporting Types

enum NetworkQuality: String, CaseIterable {
    case offline = "offline"
    case poor = "poor"
    case fair = "fair"
    case good = "good"
    case excellent = "excellent"
    case unknown = "unknown"
}

struct AnalyticsEvent: Codable {
    let name: String
    let properties: [String: String]
    let timestamp: Date
    let sessionId: String
    let userId: String?
}

// MARK: - Notification Names

extension Notification.Name {
    static let networkReconnected = Notification.Name("networkReconnected")
}
