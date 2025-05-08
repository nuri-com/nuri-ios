import SwiftUI
import CoreNFC

@available(iOS 15.0, *)
public class NFCReader: NSObject, ObservableObject, ResponseDelegate {

    private var biometrickCard: BiometricCardSDK?

    public func read() {
        biometrickCard = BiometricCardSDK.card
        biometrickCard?.delegate = self
        biometrickCard?.InitCard("123")
        biometrickCard?.Enroll(true, "123")
    }

    public func UpdateResponse( _ resp:RespData? ) {
        
    }
}
