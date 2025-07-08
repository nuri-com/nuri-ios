import Foundation
import os.log

public enum Logger {
    public static func debug(_ message: String) {
        #if DEBUG
        os_log("%{public}@", log: OSLog.default, type: .debug, message)
        #endif
    }

    public static func info(_ message: String) {
        os_log("%{public}@", log: OSLog.default, type: .info, message)
    }

    public static func error(_ message: String) {
        os_log("%{public}@", log: OSLog.default, type: .error, message)
    }
} 