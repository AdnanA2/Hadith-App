import Foundation

/// Centralized logging system for the Hadith App
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
