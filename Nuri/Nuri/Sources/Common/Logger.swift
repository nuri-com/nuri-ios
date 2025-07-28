import Foundation
import os

/// Enhanced logging system with detailed context information
public struct NuriLogger {
    private let subsystem = "com.nuri.wallet"
    private let category: String
    private let logger: os.Logger
    
    // MARK: - Initialization
    
    public init(category: String) {
        self.category = category
        self.logger = os.Logger(subsystem: subsystem, category: category)
    }
    
    // MARK: - Core Logging
    
    private func log(
        level: OSLogType,
        emoji: String,
        message: String,
        metadata: [String: Any]? = nil,
        file: String,
        function: String,
        line: Int
    ) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        
        // Format: [Category/File:Line] function() → message
        let formattedMessage = "\(emoji) [\(category)/\(fileName):\(line)] \(function) → \(message)"
        
        // Add metadata if provided
        var fullMessage = formattedMessage
        if let metadata = metadata, !metadata.isEmpty {
            let metadataString = metadata.map { "  \($0.key): \($0.value)" }.joined(separator: "\n")
            fullMessage += "\n\(metadataString)"
        }
        
        // Log to os.Logger (this also prints to console in Xcode)
        logger.log(level: level, "\(fullMessage)")
    }
    
    // MARK: - Public Methods
    
    public func debug(
        _ message: String,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .debug, emoji: "🔍", message: message, metadata: metadata, 
            file: file, function: function, line: line)
    }
    
    public func info(
        _ message: String,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .info, emoji: "ℹ️", message: message, metadata: metadata,
            file: file, function: function, line: line)
    }
    
    public func success(
        _ message: String,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .info, emoji: "✅", message: message, metadata: metadata,
            file: file, function: function, line: line)
    }
    
    public func warning(
        _ message: String,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .default, emoji: "⚠️", message: message, metadata: metadata,
            file: file, function: function, line: line)
    }
    
    public func error(
        _ message: String,
        error: Error? = nil,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        var enrichedMetadata = metadata ?? [:]
        if let error = error {
            enrichedMetadata["error"] = "\(error)"
            enrichedMetadata["errorType"] = String(describing: type(of: error))
        }
        
        log(level: .error, emoji: "❌", message: message, metadata: enrichedMetadata,
            file: file, function: function, line: line)
    }
    
    public func network(
        _ message: String,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .info, emoji: "🌐", message: message, metadata: metadata,
            file: file, function: function, line: line)
    }
    
    public func security(
        _ message: String,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .info, emoji: "🔐", message: message, metadata: metadata,
            file: file, function: function, line: line)
    }
}

// MARK: - Global Logger Instances

public struct Log {
    public static let app = NuriLogger(category: "App")
    public static let wallet = NuriLogger(category: "Wallet")
    public static let passkey = NuriLogger(category: "Passkey")
    public static let network = NuriLogger(category: "Network")
    public static let security = NuriLogger(category: "Security")
    public static let ui = NuriLogger(category: "UI")
    public static let state = NuriLogger(category: "State")
    public static let bitcoin = NuriLogger(category: "Bitcoin")
    public static let keychain = NuriLogger(category: "Keychain")
}

// MARK: - Legacy Support (for gradual migration)

public enum Logger {
    public static func debug(_ message: String) {
        Log.app.debug(message)
    }

    public static func info(_ message: String) {
        Log.app.info(message)
    }

    public static func error(_ message: String) {
        Log.app.error(message)
    }
} 