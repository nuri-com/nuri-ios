import Foundation
import LocalAuthentication
import UIKit

/// Service to handle Face ID/Touch ID authentication
final class AuthenticationService {
    static let shared = AuthenticationService()
    
    private var hasAuthenticatedThisSession = false
    private var authenticationWindow: UIWindow?
    
    private init() {}
    
    /// Check if user has authenticated this session
    var isAuthenticated: Bool {
        return hasAuthenticatedThisSession
    }
    
    /// Authenticate user with Face ID/Touch ID
    func authenticateUser(reason: String = "Authenticate to access your Bitcoin wallet", completion: @escaping (Bool) -> Void) {
        print("🔐 [AuthenticationService] Starting authentication...")
        
        // If already authenticated this session, skip
        if hasAuthenticatedThisSession {
            print("✅ [AuthenticationService] Already authenticated this session")
            completion(true)
            return
        }
        
        let context = LAContext()
        var error: NSError?
        
        // Check if biometric authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("❌ [AuthenticationService] Biometric authentication not available: \(error?.localizedDescription ?? "Unknown error")")
            // Fall back to passcode
            authenticateWithPasscode(reason: reason, completion: completion)
            return
        }
        
        // Show authentication overlay
        showAuthenticationWindow()
        
        // Perform authentication
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                              localizedReason: reason) { [weak self] success, authError in
            DispatchQueue.main.async {
                if success {
                    print("✅ [AuthenticationService] Face ID authentication successful")
                    self?.hasAuthenticatedThisSession = true
                    self?.removeAuthenticationWindow()
                    completion(true)
                } else {
                    print("❌ [AuthenticationService] Face ID authentication failed: \(authError?.localizedDescription ?? "Unknown error")")
                    // Fall back to passcode
                    self?.authenticateWithPasscode(reason: reason, completion: completion)
                }
            }
        }
    }
    
    private func authenticateWithPasscode(reason: String, completion: @escaping (Bool) -> Void) {
        print("🔐 [AuthenticationService] Falling back to passcode authentication...")
        
        let context = LAContext()
        context.evaluatePolicy(.deviceOwnerAuthentication,
                              localizedReason: reason) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ [AuthenticationService] Passcode authentication successful")
                    self?.hasAuthenticatedThisSession = true
                    self?.removeAuthenticationWindow()
                    completion(true)
                } else {
                    print("❌ [AuthenticationService] Passcode authentication failed: \(error?.localizedDescription ?? "Unknown error")")
                    self?.removeAuthenticationWindow()
                    completion(false)
                }
            }
        }
    }
    
    /// Reset authentication state (call when app goes to background)
    func resetAuthentication() {
        hasAuthenticatedThisSession = false
        print("🔐 [AuthenticationService] Authentication state reset")
    }
    
    // MARK: - UI
    
    private func showAuthenticationWindow() {
        guard authenticationWindow == nil,
              let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        
        // Create overlay window
        authenticationWindow = UIWindow(windowScene: windowScene)
        authenticationWindow?.windowLevel = .alert + 1
        authenticationWindow?.backgroundColor = .systemBackground
        
        // Create blur effect
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = authenticationWindow!.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Add lock icon
        let imageView = UIImageView(image: UIImage(systemName: "faceid"))
        imageView.tintColor = .label
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = "Authenticating..."
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let rootViewController = UIViewController()
        rootViewController.view.addSubview(blurView)
        rootViewController.view.addSubview(imageView)
        rootViewController.view.addSubview(label)
        
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: rootViewController.view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: rootViewController.view.centerYAnchor, constant: -40),
            imageView.widthAnchor.constraint(equalToConstant: 60),
            imageView.heightAnchor.constraint(equalToConstant: 60),
            
            label.centerXAnchor.constraint(equalTo: rootViewController.view.centerXAnchor),
            label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
            label.leadingAnchor.constraint(equalTo: rootViewController.view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: rootViewController.view.trailingAnchor, constant: -20)
        ])
        
        authenticationWindow?.rootViewController = rootViewController
        authenticationWindow?.makeKeyAndVisible()
    }
    
    private func removeAuthenticationWindow() {
        authenticationWindow?.isHidden = true
        authenticationWindow = nil
    }
}