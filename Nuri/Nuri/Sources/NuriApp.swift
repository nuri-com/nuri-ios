import SwiftUI
import StrigaAPI

@main
struct NuriApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("isUserLoggedIn") var isUserLoggedIn: Bool = false
    @State private var hasSyncedOnLaunch = false

    init() {
        // Don't initialize wallet on app start to avoid creating keychain entries
        print("🔑 [NuriApp] App started")
        // BitcoinWalletService will be initialized when Bitcoin tab is accessed
        
        // Uncomment to force logout for testing
        // UserDefaults.standard.set(false, forKey: "isUserLoggedIn")
        // print("🔓 [NuriApp] Login state reset to: \(UserDefaults.standard.bool(forKey: "isUserLoggedIn"))")
        
        // Don't clear cache on app start - let the wallet service handle it
        // This prevents losing cached balance data
        print("💾 [NuriApp] Preserving cached wallet data on app start")
        
        // Log device info for debugging
        #if targetEnvironment(simulator)
        print("🖥️ [NuriApp] Running on Simulator")
        #else
        print("📱 [NuriApp] Running on Physical Device")
        #endif
        
        // Configure Striga
        configureStriga()
    }
    
    private func configureStriga() {
        // Configure Striga with centralized credentials
        StrigaService.shared.configuration = StrigaCredentials.current
        
        #if DEBUG
        print("🔧 [NuriApp] Configured Striga for sandbox environment")
        print("🔧 [NuriApp] API URL: \(StrigaCredentials.current.url)")
        print("🔧 [NuriApp] Application ID: \(StrigaCredentials.current.applicationId ?? "Not set")")
        #else
        print("🔧 [NuriApp] Configured Striga for production environment")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isUserLoggedIn {
                    MainTabBar()
                        .onAppear {
                            print("📱 [NuriApp] Showing MainTabBar (user logged in)")
                            print("📊 [NuriApp] Current login state: \(isUserLoggedIn)")
                            
                            // Sync Striga data for logged-in users on app launch (only once)
                            if !hasSyncedOnLaunch {
                                hasSyncedOnLaunch = true
                                Task {
                                    await syncStrigaDataForLoggedInUser()
                                }
                            }
                        }
                } else {
                    WelcomeView()
                        .onAppear {
                            print("👋 [NuriApp] Showing WelcomeView (user not logged in)")
                            print("📊 [NuriApp] Current login state: \(isUserLoggedIn)")
                            print("🔐 [NuriApp] Ready for passkey authentication")
                        }
                }
            }
            .onAppear {
                print("🔍 [NuriApp] View appeared - isUserLoggedIn = \(isUserLoggedIn)")
                print("📝 [NuriApp] UserDefaults value = \(UserDefaults.standard.bool(forKey: "isUserLoggedIn"))")
            }
        }
    }
    
    @MainActor
    private func syncStrigaDataForLoggedInUser() async {
        // Check if we have a Striga user ID to sync
        guard let userId = UserSettings().strigaUserId else {
            print("[NuriApp] No Striga user ID found, skipping sync")
            return
        }
        
        print("[NuriApp:syncStrigaDataForLoggedInUser:84] Syncing Striga data for logged-in user: \(userId)")
        
        // Validate cached data first
        let isValid = await StrigaSyncService.shared.validateCachedData()
        
        if !isValid {
            print("[NuriApp:syncStrigaDataForLoggedInUser:90] Cached data invalid, performing full sync")
            let syncSuccess = await StrigaSyncService.shared.syncUserData(userId: userId)
            
            if syncSuccess {
                print("[NuriApp] ✅ Successfully synced Striga data")
            } else {
                print("[NuriApp:syncStrigaDataForLoggedInUser:96] ⚠️ Failed to sync Striga data - user may need to complete setup")
                
                // Check if user needs card/wallet creation
                await checkAndCreateCardIfNeeded(userId: userId)
            }
        } else {
            print("[NuriApp] ✅ Cached data is valid, no sync needed")
        }
    }
    
    @MainActor
    private func checkAndCreateCardIfNeeded(userId: String) async {
        print("[NuriApp:checkAndCreateCardIfNeeded:108] Checking if user needs card/wallet creation")
        
        var userResponse: GetUserResponse? = nil
        var userName = "Nuri User"
        var kycApproved = false
        
        // Try to get user details, but proceed even if it fails
        do {
            let getUserInput = GetUser(userId: userId)
            userResponse = try await StrigaService.shared.getUser(getUserInput)
            userName = "\(userResponse!.firstName) \(userResponse!.lastName)"
            kycApproved = userResponse!.KYC.status == "APPROVED"
            
            print("[NuriApp] User details:")
            print("  - Name: \(userName)")
            print("  - Email: \(userResponse!.email)")
            print("  - KYC Status: \(userResponse!.KYC.status)")
            print("  - Mobile verified: \(userResponse!.mobile != nil)")
            
            guard kycApproved else {
                print("[NuriApp] KYC not approved (\(userResponse!.KYC.status)), skipping auto-creation")
                if let reasons = userResponse!.KYC.rejectionReasons, !reasons.isEmpty {
                    print("[NuriApp] KYC rejection reasons: \(reasons.joined(separator: ", "))")
                }
                return
            }
        } catch {
            print("[NuriApp:checkAndCreateCardIfNeeded:133] Failed to get user details: \(error)")
            print("[NuriApp:checkAndCreateCardIfNeeded:134] Will proceed with card creation anyway...")
            // If the user endpoint fails, we'll still try to create cards
            // This handles cases where the user exists but the endpoint is problematic
            kycApproved = true
        }
        
        print("[NuriApp] ✅ User has approved KYC")
        
        // We no longer create wallets or cards here
        // CardView will handle wallet+card creation atomically when needed
        print("[NuriApp] Skipping automatic wallet/card creation - will be handled by CardView")
        
        // Just perform a sync to ensure user data is cached
        await StrigaSyncService.shared.syncUserData(userId: userId)
        
        // Start auto-conversion monitoring for approved users with cards
        if StrigaSession.shared.cardId != nil {
            print("[NuriApp] Starting auto-conversion monitoring")
            await AutoConversionService.shared.startMonitoring()
        }
    }
}
