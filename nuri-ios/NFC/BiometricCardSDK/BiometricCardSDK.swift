/******************************************************************************
 Copyright (c) 2023 IDEX Biometrics ASA. All Rights Reserved.
 www.idexbiometrics.com

 IDEX Biometrics ASA is the owner of this software and all intellectual
 property rights in and to the software. The software may only be used together
 with IDEX fingerprint sensors, unless otherwise permitted by IDEX Biometrics
 ASA in writing.

 This copyright notice must not be altered or removed from the software.

 DISCLAIMER OF WARRANTY/LIMITATION OF REMEDIES: unless otherwise agreed, IDEX
 Biometrics ASA has no obligation to support this software, and the software is
 provided "AS IS", with no express or implied warranties of any kind, and IDEX
 Biometrics ASA is not to be liable for any damages, any relief, or for any
 claim by any third party, arising from use of this software.

 Image capture and processing logic is defined and controlled by IDEX
 Biometrics ASA in order to maximize FAR/FRR performance.
******************************************************************************/

import CoreNFC


public let FIELD_STRENGTH = Array(0...100)

//default field strength threshold in percentage. App can choose different threshold.
public let FS_FULL    = 20
public let FS_HIGH    = 16
public let FS_MIDDLE  = 13
public let FS_LOW     = 10

/**
 Return code from SDK
 */
public enum RETURN_CODES{
    case NFC_DISABLED
    case INITIALIZE
    case ENROLL_CODE_NEEDED
    case ENROLL
    case QUALIFY
    case VERIFY
    case ENROLL_ACTIVE
    case BAD_COVERAGE
    case QUAL_ACTIVE
    case QUAL_NO_MATCH
    case NOT_POSSIBLE
    case FIELD_STRENGTH
    case DISCONNECTED
    case TERMINATED
}


/**
 Response Data for UI update.
 */
public class RespData : ObservableObject{
    public var fingersTotal         :Int            = 1
    public var fingerCurrent        :Int            = 0
    public var touchTotal           :Int            = 6
    public var touchCompleted       :Int            = 0
    public var returnCode           :RETURN_CODES   = .ENROLL_CODE_NEEDED
    public var strengthPercent      :Int            = 0
    public var qualTotal            :Int            = 0
    public var enrollCodeTryLimit   :Int            = 0
}

/**
 Callback handled by the UI provided by the SDK, this is periodically called to provide the UI with an update on current RF connection and return codes.
 - Parameter resp: RespData.
 - Returns:void
 */
public protocol ResponseDelegate : AnyObject{
    func UpdateResponse( _ resp:RespData? )
}

/**
 Biometric card public class. handle all the biometric commands and NFC tag read and write functions
 */
public class BiometricCardSDK : NSObject, NFCTagReaderSessionDelegate{
    var readerSession   : NFCTagReaderSession?
    var command         : BioCmdID      = .INITCARD
    var current         : Int           = 0
    var finger          : Int           = 0
    var touch           : Int           = 0
    var progress        : Int           = 0
    var enrollCode      : Data          = Data()
    var resetBio        : Bool          = false
    var uid             : String        = ""
    var CLA             : UInt8         = 0x00
    var fingerID        : Int           = 0
    var enrollAppletAID : [UInt8]       = [ 0x49, 0x44, 0x45, 0x58, 0x5F, 0x4C, 0x5F, 0x01, 0x01 ]
    var IBAAppletAID    : [UInt8]       = [ 0xA0, 0x00, 0x00, 0x09, 0x05, 0x01, 0x00, 0x01, 0x01 ]

    // Intantiate haptics engine
    var engine          : HapticsEngine = HapticsEngine()

    var logger:SDKLog       = SDKLog()
    var resp:RespData       = RespData()
    var status:CardStatus   = CardStatus()
    
    // Set init nfc action sheet message
    var alertMessage    : String        = "Align the arrow on your card with the arrow on the screen."

    public weak var delegate:ResponseDelegate?

    //Singleton to keep Biometric Enrollment Code in one session
    public static let  card = BiometricCardSDK()
    
    private override init(){
      // create engine
      engine.create()
    }


    /**
     Get called when NFC Tag reader become active
     - Parameter session: NFC Tag reader session
     - Returns:
            void
     */
    public func tagReaderSessionDidBecomeActive( _ session: NFCTagReaderSession ) {
        logger.write("Reader  did  become active.")
        engine.start()
        engine.playContinuousTick(1)
        engine.playTimer()
    }

    /**
     Get called when start a new NFC Tag Reader session
     - Parameter
        session: NFC Tag reader session
        tags: NFC tags, Enroll Applet AID
     - Returns:
            void
     */
    public func tagReaderSession( _ session: NFCTagReaderSession, didDetect tags: [NFCTag] ) {
        var tag: NFCTag? = nil
        logger.write("tagReaderSession()")
        //print(tags)
        for nfcTag in tags {
            //print(nfcTag)
            tag = nfcTag
            engine.stop()
            session.connect(to: tag!) { (error: Error?) in
                if error != nil {
                    self.logger.write("Card get disconnected.")
                    self.engine.start()
                    self.engine.playContinuousTick(1)
                    self.engine.playTimer()
                    session.invalidate(errorMessage: "Connection error. Please try again...")
                    return
                }

                if case let .iso7816(sTag) = nfcTag {
                    Task {
                        self.CLA = 0x00
                        var (sw1, sw2) = await self.SelectApplet( sTag, self.enrollAppletAID )
                        if (sw1, sw2) == SUCCESS {
                            self.logger.write("Select Enroll Applet.")
                        } else {
                            (sw1, sw2) = await self.SelectApplet( sTag, self.IBAAppletAID )
                            if (sw1, sw2) == SUCCESS {
                                self.logger.write("Select IBA Applet.")
                            } else {
                                self.CLA = 0xED
                                self.logger.write("Select SE-SDK.")
                            }
                        }
                        self.Dispatch( sTag )
                    }
                }
            }
        }
    }

    /**
     Get called when the NFC Tag Reader session is ended
     - Parameter
        session: NFC Tag reader session
        errors: Error of the session invalidated.
     - Returns:
            void
     */
    public func tagReaderSession( _ session: NFCTagReaderSession, didInvalidateWithError error: Error ) {
        logger.write("Reader  did  invalidate.")
        engine.stop()
        resp.returnCode = .TERMINATED
        delegate?.UpdateResponse( resp )
    }

    /**
     Manages opening the interface to the card, selecting the applet, getting the status
     - Parameter code: Biometric Enrollment Code or null.
     - Returns:Async update by delegate
        ENROLL_CODE_NEEDED: The UI should ask for the user for the Biometric Enrollment Code then call initCard() again
        ENROLL: The UI should call enroll()
        QUALIFY: The UI should call qualify()
        VERIFY: The UI should show that the card can be used for biometric payment
        FIELD_STRENGTH: UI should show field strength
        DISCONNECTED: Disconnected with the card
     */
    public func InitCard( _ code:String ){
        //Biometric Enrollment Code length from 2 bytes to 6 bytes)
        if ( code.count != 0 && ( code.count < 2 || code.count > 12 ) ){
            resp.returnCode = .ENROLL_CODE_NEEDED
            delegate?.UpdateResponse( resp )
            logger.write("invalidate Biometric Enrollment Code length: \(code.count).")
            return
        }

        enrollCode = ParserEnrollCode( code )
        BeginReaderSession( BioCmdID.INITCARD )
    }

    /**
     Handles all enrolment.  There should be an associated callback which provides the UI with updates on the next action for the user to take.
     - Parameter reset: reset enrollment, delete all templates from database and enroll new finger.
                 code: the Biometric Enrollment Code, if stored locally by  the UI.
     - Returns:Async update by delegate
         ENROLL_CODE_NEEDED: The UI should ask for the user for the Biometric Enrollment Code then call Enroll() again.
         ENROLL: Continue enroll.
         QUALIFY: The UI should show Enrollment completed and ready for qualify.
         VERIFY: The UI should show Enrollment completed and the card can be used for biometric payment.
         ENROLL_ACTIVE: Enrollment is in processing, one touch completed.
         BAD_COVERAGE: The UI should show bad image coverage.
         NOT_POSSIBLE: The card is not in enroll mode or in wrong state.
         FIELD_STRENGTH: UI should show field strength
         DISCONNECTED: Disconnected with the card.
     */
    public func Enroll( _ reset:Bool, _ code:String ){
        if ( code.count != 0 && ( code.count < 2 || code.count > 12 ) ){
            resp.returnCode = .ENROLL_CODE_NEEDED
            delegate?.UpdateResponse( resp )
            return
        }

        logger.write("Enroll( \(reset), \(code.count) ).")
        resetBio = reset
        enrollCode = ParserEnrollCode( code )
        BeginReaderSession( BioCmdID.ENROLL )
    }

    /**
     Handles the qualification touches
     - Parameter void
     - Returns:Async update by delegate
        ENROLL_CODE_NEEDED: The UI should ask for the user for the Biometric Enrollment Code then call Qualify() again
        ENROLL: The UI should call enroll()
        QUALIFY: The UI should call qualify()
        VERIFY: The UI should show that the card can be used for biometric payment
        QUAL_ACTIVE: Qualify is in processing, one touch qualified.
        BAD_COVERAGE: The UI should show bad image coverage.
        QUAL_NO_MATCH: The UI should show no match in Qualify.
        NOT_POSSIBLE: The card is not in quality mode or in wrong state
        FIELD_STRENGTH: UI should show field strength
        DISCONNECTED: Disconnected with the card
     */
    public func Qualify(){
        BeginReaderSession( BioCmdID.QUALIFY )
    }

    /**
     Detect the card and measure the field strength.
     - Parameter void
     - Returns: Async update by delegate
        FIELD_STRENGTH: UI should show field strength
        DISCONNECTED: Disconnected with the card
     */
    public func CheckConnection(){
        BeginReaderSession( BioCmdID.CHECK_CONNECTION )
    }

    /**
     Set the alert message on NFC Tag scan window.
     - Parameter message: alert message to show on NFC Tag scan window
     - Returns:
        void
     */
    public func setAlertMessage( _ message:String ){
        SetAlertMessageInt( message )
        alertMessage = message
    }

    /**
     Delete finger by ID, 0 - remove all templates, 1, 2 - remove templates for given finger id
     - Parameter id: finger id
     - Returns:
        void
     */
    public func DeleteFinger(_ id:Int)
    {
        fingerID = id
        BeginReaderSession( BioCmdID.DELETE_FINGER )
    }


}
