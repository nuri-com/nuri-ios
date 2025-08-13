import Foundation

/// Centralized debug logging service for better tracking
@MainActor
class DebugLogger {
    static let shared = DebugLogger()
    
    private init() {}
    
    enum LogLevel: String {
        case info = "ℹ️"
        case success = "✅"
        case warning = "⚠️"
        case error = "❌"
        case api = "🌐"
        case data = "💾"
        case flow = "🔄"
    }
    
    enum Component: String {
        case app = "App"
        case cardView = "CardView"
        case cardViewActive = "CardViewActive"
        case securityView = "SecurityView"
        case strigaSync = "StrigaSync"
        case session = "Session"
        case userSettings = "UserSettings"
        case api = "API"
        case autoConversion = "AutoConvert"
    }
    
    func log(_ level: LogLevel, _ component: Component, _ message: String, file: String = #file, line: Int = #line) {
        let fileName = URL(fileURLWithPath: file).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        let timestamp = Date().timeIntervalSince1970
        print("\(level.rawValue) [\(component.rawValue):\(fileName):\(line)] \(message)")
    }
    
    func logDataState(_ component: Component) {
        print("\n" + String(repeating: "=", count: 60))
        print("📊 DATA STATE CHECK - \(component.rawValue)")
        print(String(repeating: "-", count: 60))
        
        // Check UserSettings
        let settings = UserSettings()
        print("💾 UserSettings:")
        print("  • userId: \(settings.strigaUserId ?? "nil")")
        print("  • cardId: \(settings.strigaCardId ?? "nil")")
        print("  • walletId: \(settings.strigaWalletId ?? "nil")")
        
        // Check StrigaSession
        print("🔐 StrigaSession:")
        print("  • userId: \(StrigaSession.shared.userId ?? "nil")")
        print("  • cardId: \(StrigaSession.shared.cardId ?? "nil")")
        print("  • name: \(StrigaSession.shared.name ?? "nil")")
        print("  • firstName: \(StrigaSession.shared.firstName ?? "nil")")
        print("  • lastName: \(StrigaSession.shared.lastName ?? "nil")")
        
        print(String(repeating: "=", count: 60) + "\n")
    }
    
    func logAPICall(_ endpoint: String, _ params: [String: Any]? = nil, success: Bool = false, error: String? = nil) {
        if success {
            print("🌐 ✅ API Success: \(endpoint)")
        } else if let error = error {
            print("🌐 ❌ API Failed: \(endpoint)")
            print("     Error: \(error)")
        } else {
            print("🌐 ➡️ API Call: \(endpoint)")
            if let params = params {
                print("     Params: \(params)")
            }
        }
    }
    
    func logFlowEvent(_ event: String, details: String? = nil) {
        print("🔄 Flow: \(event)")
        if let details = details {
            print("     \(details)")
        }
    }
}