import Foundation
import StrigaAPI

/// Centralized Striga credentials configuration
enum StrigaCredentials {
    /// Sandbox configuration with all necessary credentials
    static let sandbox = StrigaConfiguration(
        url: "https://www.sandbox.striga.com/api/",
        key: "_TbS1cXGStMmYBJtcoYSA7we2lQUky_6TMo-aGLvWJM=",
        secret: "43jBa65VEoLC5O4O48pDruayz5Q43IlhgyGbkYPcMHE=",
        uiSecret: "N8UziFzjqP616Rk3+6uRGe1nDJ3TOxnUZzWrqadQalw=",
        applicationId: "3856e737-52d9-4266-a195-0fcfe8e16600"
    )
    
    /// Production configuration (to be added when ready)
    static let production: StrigaConfiguration? = nil
    
    /// Get the appropriate configuration based on build settings
    static var current: StrigaConfiguration {
        // For now, always use sandbox
        // In the future, this could check build configuration or environment
        return sandbox
    }
}