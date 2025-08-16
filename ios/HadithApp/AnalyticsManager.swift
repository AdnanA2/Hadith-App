import Foundation
import UIKit
import Combine

/// Analytics and logging manager for tracking user behavior and app performance
class AnalyticsManager {
    static let shared = AnalyticsManager()
    
    // MARK: - Configuration
    
    private struct Config {
        static let enabled = Environment.analyticsEnabled
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
    
    private let queue = DispatchQueue(label: "analytics.queue", attributes: .concurrent)
    private let logger = Logger.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        setupAnalytics()
        startFlushTimer()
        observeAppLifecycle()
    }
    
    private func setupAnalytics() {
        guard Config.enabled else {
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
    
    // MARK: - Event Tracking
    
    /// Track a custom event
    /// - Parameters:
    ///   - name: Event name
    ///   - properties: Optional event properties
    func track(_ name: String, properties: [String: Any]? = nil) {
        guard Config.enabled else { return }
        
        queue.async(flags: .barrier) {
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
    ///   - context: Context where error occurred
    ///   - properties: Optional error properties
    func trackError(_ error: Error, context: String? = nil, properties: [String: Any]? = nil) {
        var errorProperties = properties ?? [:]
        errorProperties["error_type"] = String(describing: type(of: error))
        errorProperties["error_description"] = error.localizedDescription
        
        if let context = context {
            errorProperties["error_context"] = context
        }
        
        track("error_occurred", properties: errorProperties)
    }
    
    /// Track performance metrics
    /// - Parameters:
    ///   - metric: Metric name
    ///   - value: Metric value
    ///   - unit: Unit of measurement
    ///   - properties: Optional metric properties
    func trackPerformance(_ metric: String, value: Double, unit: String? = nil, properties: [String: Any]? = nil) {
        var perfProperties = properties ?? [:]
        perfProperties["metric_name"] = metric
        perfProperties["metric_value"] = value
        
        if let unit = unit {
            perfProperties["metric_unit"] = unit
        }
        
        track("performance_metric", properties: perfProperties)
    }
    
    // MARK: - User Properties
    
    /// Set user properties
    /// - Parameter properties: User properties to set
    func setUserProperties(_ properties: [String: Any]) {
        queue.async(flags: .barrier) {
            for (key, value) in properties {
                self.userProperties[key] = value
            }
            
            self.logger.debug("📊 Set user properties: \(properties.keys.joined(separator: ", "))")
        }
    }
    
    /// Set user ID
    /// - Parameter userId: User ID to set
    func setUserId(_ userId: String?) {
        queue.async(flags: .barrier) {
            if let userId = userId {
                self.userProperties["user_id"] = userId
                self.logger.debug("📊 Set user ID: \(userId)")
            } else {
                self.userProperties.removeValue(forKey: "user_id")
                self.logger.debug("📊 Cleared user ID")
            }
        }
    }
    
    // MARK: - Session Management
    
    /// Start a new session
    func startSession() {
        queue.async(flags: .barrier) {
            self.sessionId = UUID().uuidString
            self.sessionStartTime = Date()
            self.lastEventTime = Date()
            
            self.track("session_start", properties: [
                "session_id": self.sessionId
            ])
            
            self.logger.info("📊 Started new session: \(self.sessionId)")
        }
    }
    
    /// End current session
    func endSession() {
        queue.async(flags: .barrier) {
            let sessionDuration = Date().timeIntervalSince(self.sessionStartTime)
            
            self.track("session_end", properties: [
                "session_id": self.sessionId,
                "session_duration": sessionDuration
            ])
            
            self.flush()
            self.logger.info("📊 Ended session: \(self.sessionId) (duration: \(sessionDuration)s)")
        }
    }
    
    /// Check if session should timeout
    private func checkSessionTimeout() {
        let timeSinceLastEvent = Date().timeIntervalSince(lastEventTime)
        
        if timeSinceLastEvent > Config.sessionTimeout {
            endSession()
            startSession()
        }
    }
    
    // MARK: - Data Management
    
    /// Flush events to analytics service
    func flush() {
        queue.async(flags: .barrier) {
            guard !self.eventQueue.isEmpty else { return }
            
            let eventsToFlush = Array(self.eventQueue.prefix(Config.batchSize))
            self.eventQueue.removeFirst(min(Config.batchSize, self.eventQueue.count))
            
            self.sendEvents(eventsToFlush)
        }
    }
    
    /// Clear all queued events
    func clearQueue() {
        queue.async(flags: .barrier) {
            self.eventQueue.removeAll()
            self.logger.info("📊 Cleared analytics queue")
        }
    }
    
    /// Get analytics statistics
    /// - Returns: Analytics statistics
    func getStatistics() -> AnalyticsStatistics {
        return queue.sync {
            return AnalyticsStatistics(
                queuedEvents: eventQueue.count,
                sessionId: sessionId,
                sessionDuration: Date().timeIntervalSince(sessionStartTime),
                userProperties: userProperties.count
            )
        }
    }
    
    // MARK: - Privacy Controls
    
    /// Enable analytics tracking
    func enableTracking() {
        setUserProperties(["analytics_enabled": true])
        logger.info("📊 Analytics tracking enabled")
    }
    
    /// Disable analytics tracking
    func disableTracking() {
        setUserProperties(["analytics_enabled": false])
        clearQueue()
        logger.info("📊 Analytics tracking disabled")
    }
    
    /// Check if tracking is enabled
    /// - Returns: True if tracking is enabled
    func isTrackingEnabled() -> Bool {
        return Config.enabled && (userProperties["analytics_enabled"] as? Bool ?? true)
    }
    
    // MARK: - Private Methods
    
    private func addEvent(_ event: AnalyticsEvent) {
        guard isTrackingEnabled() else { return }
        
        lastEventTime = Date()
        eventQueue.append(event)
        
        // Trim queue if it gets too large
        if eventQueue.count > Config.maxQueueSize {
            eventQueue.removeFirst(eventQueue.count - Config.maxQueueSize)
            logger.warning("📊 Analytics queue trimmed to \(Config.maxQueueSize) events")
        }
        
        // Auto-flush if batch size reached
        if eventQueue.count >= Config.batchSize {
            flush()
        }
    }
    
    private func sendEvents(_ events: [AnalyticsEvent]) {
        // In a real implementation, you would send these to your analytics service
        // For example: Firebase Analytics, Mixpanel, Amplitude, etc.
        
        let eventData = events.map { event in
            var data = event.properties
            data["event_name"] = event.name
            data["timestamp"] = event.timestamp.timeIntervalSince1970
            data["session_id"] = event.sessionId
            data["user_id"] = event.userId ?? "anonymous"
            
            // Add user properties to each event
            for (key, value) in userProperties {
                data["user_\(key)"] = value
            }
            
            return data
        }
        
        if Environment.isDebug {
            logger.debug("📊 Would send \(events.count) events to analytics service")
            for event in events {
                logger.debug("  - \(event.name): \(event.properties)")
            }
        }
        
        // TODO: Implement actual analytics service integration
        // Example implementations:
        
        // Firebase Analytics:
        // for event in events {
        //     Analytics.logEvent(event.name, parameters: event.properties)
        // }
        
        // Custom API:
        // APIService.shared.post(endpoint: "/analytics/events", body: eventData)
        //     .sink(...)
        //     .store(in: &cancellables)
    }
    
    private func getCurrentUserId() -> String? {
        return userProperties["user_id"] as? String
    }
    
    private func startFlushTimer() {
        flushTimer = Timer.scheduledTimer(withTimeInterval: Config.flushInterval, repeats: true) { [weak self] _ in
            self?.flush()
            self?.checkSessionTimeout()
        }
    }
    
    private func observeAppLifecycle() {
        // App became active
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.track("app_became_active")
            }
            .store(in: &cancellables)
        
        // App will resign active
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.track("app_will_resign_active")
                self?.flush()
            }
            .store(in: &cancellables)
        
        // App entered background
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.track("app_entered_background")
                self?.flush()
            }
            .store(in: &cancellables)
        
        // App will terminate
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.track("app_will_terminate")
                self?.endSession()
            }
            .store(in: &cancellables)
        
        // Memory warning
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.track("memory_warning")
            }
            .store(in: &cancellables)
    }
    
    deinit {
        flushTimer?.invalidate()
    }
}

// MARK: - Convenience Methods

extension AnalyticsManager {
    /// Track app launch
    func trackAppLaunch() {
        track("app_launch", properties: [
            "launch_time": Date().timeIntervalSince1970,
            "is_first_launch": isFirstLaunch()
        ])
    }
    
    /// Track authentication events
    func trackAuth(_ event: AuthEvent, properties: [String: Any]? = nil) {
        var authProperties = properties ?? [:]
        authProperties["auth_event"] = event.rawValue
        
        track("auth_event", properties: authProperties)
    }
    
    /// Track hadith interactions
    func trackHadith(_ action: HadithAction, hadithId: String? = nil, properties: [String: Any]? = nil) {
        var hadithProperties = properties ?? [:]
        hadithProperties["hadith_action"] = action.rawValue
        
        if let hadithId = hadithId {
            hadithProperties["hadith_id"] = hadithId
        }
        
        track("hadith_interaction", properties: hadithProperties)
    }
    
    /// Track search events
    func trackSearch(query: String, results: Int, properties: [String: Any]? = nil) {
        var searchProperties = properties ?? [:]
        searchProperties["search_query"] = query
        searchProperties["search_results"] = results
        
        track("search_performed", properties: searchProperties)
    }
    
    private func isFirstLaunch() -> Bool {
        let key = "has_launched_before"
        let hasLaunched = UserDefaults.standard.bool(forKey: key)
        
        if !hasLaunched {
            UserDefaults.standard.set(true, forKey: key)
            return true
        }
        
        return false
    }
}

// MARK: - Supporting Types

struct AnalyticsEvent {
    let name: String
    let properties: [String: Any]
    let timestamp: Date
    let sessionId: String
    let userId: String?
}

struct AnalyticsStatistics {
    let queuedEvents: Int
    let sessionId: String
    let sessionDuration: TimeInterval
    let userProperties: Int
}

enum AuthEvent: String {
    case login = "login"
    case logout = "logout"
    case signup = "signup"
    case loginFailed = "login_failed"
    case signupFailed = "signup_failed"
    case tokenRefresh = "token_refresh"
    case tokenExpired = "token_expired"
}

enum HadithAction: String {
    case view = "view"
    case favorite = "favorite"
    case unfavorite = "unfavorite"
    case share = "share"
    case copy = "copy"
    case search = "search"
    case filter = "filter"
}

// MARK: - Logger Implementation

class Logger {
    static let shared = Logger()
    
    private let queue = DispatchQueue(label: "logger.queue")
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    private init() {}
    
    enum Level: String, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        
        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            }
        }
    }
    
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message, file: file, function: function, line: line)
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message, file: file, function: function, line: line)
    }
    
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message, file: file, function: function, line: line)
    }
    
    private func log(_ level: Level, _ message: String, file: String, function: String, line: Int) {
        queue.async {
            let timestamp = self.dateFormatter.string(from: Date())
            let filename = (file as NSString).lastPathComponent
            
            let logMessage = "\(level.emoji) [\(timestamp)] [\(level.rawValue)] [\(filename):\(line)] \(function) - \(message)"
            
            if Environment.isDebug || level == .error {
                print(logMessage)
            }
            
            // In production, you might want to write to a file or send to a logging service
            self.writeToFile(logMessage)
        }
    }
    
    private func writeToFile(_ message: String) {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let logFileURL = documentsPath.appendingPathComponent("app_log.txt")
        let timestampedMessage = message + "\n"
        
        do {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                let fileHandle = try FileHandle(forWritingTo: logFileURL)
                fileHandle.seekToEndOfFile()
                fileHandle.write(timestampedMessage.data(using: .utf8) ?? Data())
                fileHandle.closeFile()
            } else {
                try timestampedMessage.write(to: logFileURL, atomically: true, encoding: .utf8)
            }
        } catch {
            print("Failed to write to log file: \(error)")
        }
    }
}
