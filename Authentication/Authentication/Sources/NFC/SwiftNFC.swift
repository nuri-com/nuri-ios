import SwiftUI
import CoreNFC

@available(iOS 15.0, *)
public class NFCReader: NSObject, ObservableObject, ResponseDelegate {

    private var biometricCard: BiometricCardSDK?

    public func read() {
        biometricCard = BiometricCardSDK.card
        biometricCard?.delegate = self
        biometricCard?.InitCard("123")
        biometricCard?.Enroll(true, "123")
    }

    public func UpdateResponse( _ resp:RespData? ) {
        guard let response = resp else { return }
        let message = String(repeating: "✅ ", count: response.touchCompleted)
            + String(repeating: "👍 ", count: response.touchTotal - response.touchCompleted)
        biometricCard?.setAlertMessage(message)
        
        if response.returnCode == .VERIFY {
            print("Verified! 🎉")
        }
    }
}
