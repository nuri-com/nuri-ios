import Foundation

public class StrigaRetryHandler {
    
    public enum RetryError: Error {
        case maxAttemptsExceeded(lastError: Error?)
        case ownerMismatch(code: Int, message: String)
    }
    
    public static func withRetry<T>(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 1.0,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Check if it's an owner mismatch error (code 30029)
                if let nsError = error as NSError?,
                   nsError.code == 30029 || nsError.domain.contains("Owner mismatch") {
                    // Don't retry owner mismatch errors - they need user ID fix
                    throw RetryError.ownerMismatch(code: 30029, message: "Owner mismatch - check user ID")
                }
                
                // Check if it's a 404 - might need different endpoint
                if let nsError = error as NSError?,
                   nsError.code == 404 {
                    // Log the error for debugging
                    print("[RetryHandler] 404 error on attempt \(attempt + 1): \(error)")
                }
                
                // Don't retry on last attempt
                if attempt < maxAttempts - 1 {
                    let backoffDelay = initialDelay * pow(2.0, Double(attempt))
                    print("[RetryHandler] Retrying after \(backoffDelay) seconds (attempt \(attempt + 1)/\(maxAttempts))")
                    try await Task.sleep(nanoseconds: UInt64(backoffDelay * 1_000_000_000))
                }
            }
        }
        
        throw RetryError.maxAttemptsExceeded(lastError: lastError)
    }
    
    // Specialized retry for Striga API calls with user ID validation
    public static func withStrigaRetry<T>(
        userId: String?,
        maxAttempts: Int = 3,
        operation: (String) async throws -> T
    ) async throws -> T {
        // Validate user ID first
        guard let validUserId = userId, !validUserId.isEmpty else {
            throw NSError(domain: "StrigaAPI", code: 30029, 
                         userInfo: [NSLocalizedDescriptionKey: "Invalid or missing user ID"])
        }
        
        return try await withRetry(maxAttempts: maxAttempts) {
            try await operation(validUserId)
        }
    }
}