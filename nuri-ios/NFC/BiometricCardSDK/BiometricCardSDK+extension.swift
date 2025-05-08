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

//Private Biometric command ID
enum BioCmdID{
    case INITCARD
    case ENROLL
    case QUALIFY
    case CHECK_CONNECTION
    case DELETE_FINGER
}

//private card status
struct CardStatus{
    var API_Version                 :Int    = 0
    var uid                         :String = ""
    var totalFingersEnroll          :Int    = 1
    var f1_NumOfEnrolledTouches     :Int    = 0
    var f1_TopupEnrolledTouches     :Int    = 0
    var f1_NumOfTouchesLeftToEnroll :Int    = 6
    var f1_QualifyTouchesLeft       :Int    = 0
    var f1_QualifyPassesLeft        :Int    = 0
    var f1_BiometricMode            :Int    = 0
    var f1_TopupTouchesLeftToEnroll :Int    = 6
    var f1_TopupAttemptsLeft        :Int    = 20
    var f2_NumOfEnrolledTouches     :Int    = 0
    var f2_TopupEnrolledTouches     :Int    = 0
    var f2_NumOfTouchesLeftToEnroll :Int    = 6
    var f2_QualifyTouchesLeft       :Int    = 0
    var f2_QualifyPassesLeft        :Int    = 0
    var f2_BiometricMode            :Int    = 0
    var f2_TopupTouchesLeftToEnroll :Int    = 6
    var f2_TopupAttemptsLeft        :Int    = 20
    var fingerToEnrollNext          :Int    = 1
    var numOfQualifyTouchesLeft     :Int    = 0
    var numOfQualifyPassesLeft      :Int    = 0
    var numOfReenrollAttemptsLeft   :Int    = 0
    var mode                        :Int    = 0
    var topupTouchesLeftToEnroll    :Int    = 6
    var topupAttemptsLeft           :Int    = 20
}

//Private Biometric error code
let AUTH_FAILED      :(UInt8, UInt8) = (0x63, 0x00)
let FlASH_WRITE_ERROR:(UInt8, UInt8) = (0x65, 0x02)
let COMM_ERROR       :(UInt8, UInt8) = (0x67, 0x41)
let ERR_CALIB        :(UInt8, UInt8) = (0x67, 0x43)
let NFC_TRANS_ERROR  :(UInt8, UInt8) = (0x67, 0x44)
let CMD_ABORTED      :(UInt8, UInt8) = (0x67, 0x46)
let BAD_QUALITY      :(UInt8, UInt8) = (0x67, 0x47)
let USER_TIMEOUT     :(UInt8, UInt8) = (0x67, 0x48)
let CMD_TIMEOUT      :(UInt8, UInt8) = (0x67, 0x49)
let WRONG_STATE      :(UInt8, UInt8) = (0x69, 0x85)
let CMD_NOT_ALLOWED  :(UInt8, UInt8) = (0x69, 0x86)
let FUNC_NOT_SUPPORT :(UInt8, UInt8) = (0x6A, 0x81)
let RECORD_NOT_FOUND :(UInt8, UInt8) = (0x6A, 0x83)
let NO_SPACE         :(UInt8, UInt8) = (0x6A, 0x84)
let CMD_NOT_SUPPORT  :(UInt8, UInt8) = (0x6D, 0x00)
let SENSOR_NO_POWER  :(UInt8, UInt8) = (0x6F, 0x87)
let SE_NO_POWER      :(UInt8, UInt8) = (0x6F, 0x88)
let SUCCESS          :(UInt8, UInt8) = (0x90, 0x00)

extension BiometricCardSDK {

    internal func BeginReaderSession( _ id:BioCmdID ) {
        logger.write("BeginReaderSession: \(NFCTagReaderSession.readingAvailable).")
        if NFCTagReaderSession.readingAvailable{
            command = id;
            readerSession?.invalidate()
            readerSession = NFCTagReaderSession(pollingOption: NFCTagReaderSession.PollingOption.iso14443, delegate: self, queue: nil)
            readerSession?.alertMessage = alertMessage
            readerSession?.begin()

            if let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                logger.write("Build Number: \(buildNumber).")
            }
        } else {
            resp.returnCode = .NFC_DISABLED
            delegate?.UpdateResponse( resp )
        }
    }
    
    internal func SetAlertMessageInt( _ message:String ) {
        readerSession?.alertMessage = message
        logger.write("AlertMessage: \(message).")
    }

    internal func Dispatch( _ nfcTag:NFCISO7816Tag ) {
        switch command {
        case .INITCARD:
            InitCard(nfcTag)
            break;

        case .ENROLL:
            Enroll(nfcTag)
            break

        case .QUALIFY:
            Qualify(nfcTag)
            break

        case .CHECK_CONNECTION:
            CheckConnection(nfcTag)
            break

        case .DELETE_FINGER:
            DeleteFinger(fingerID)
            break

        }
    }

    internal func InitCard( _ nfcTag:NFCISO7816Tag ) {
        logger.write("InitCard().")
        Task{
            var (sw1, sw2) = await VerifyEnrollCode( nfcTag, enrollCode )
            if ( (sw1, sw2) == SUCCESS || (sw1, sw2) == CMD_NOT_SUPPORT ) {
                (sw1, sw2, _) = await GetCardStatus( nfcTag )
                if (sw1, sw2) == SUCCESS {
                    delegate?.UpdateResponse( resp )
                    (sw1, sw2, _) = await GetCurrent( nfcTag )
                }
                readerSession?.invalidate()
                engine.stop()
            }
        }
    }

    internal func CheckConnection( _ nfcTag:NFCISO7816Tag ) {
        logger.write("CheckConnection().")

        Task{
            var sw1:UInt8 = 0
            var sw2:UInt8 = 0
            while (true) {
                (sw1, sw2, _) = await GetCurrent( nfcTag )
                if (sw1, sw2) == NFC_TRANS_ERROR {
                    break
                }
            }
        }
    }

    internal func SelectApplet( _ nfcTag:NFCISO7816Tag, _ aID:[UInt8] ) async -> (UInt8, UInt8) {
        var sw1:UInt8 = 0
        var sw2:UInt8 = 0
        let selectApplet = NFCISO7816APDU.init(instructionClass: 0x00, instructionCode: 0xA4, p1Parameter: 0x04, p2Parameter: 0x00, data: Data( aID ), expectedResponseLength: 0x02)
        ( _, sw1, sw2, _ ) = await SendCommand( nfcTag, selectApplet )

        print(String(format:"Select Applet: 0x%02X%02X", sw1, sw2))

        return (sw1, sw2)
    }

    internal func ParserEnrollCode( _ code:String ) -> Data {
        var i:Int = 0
        var parserCode:Data = .init( [0x20 + UInt8(code.count)] ) //4 Bites Control Field 0b0010 + 4 Bits Biometric Enrollment Code Length
        let array:[Int] = code.compactMap{ $0.hexDigitValue }
        while ( i < (array.count / 2) ) {
            let digit:UInt8 = UInt8( (array[i * 2] << 4) | array[i * 2 + 1] )
            parserCode.append( digit )
            i = i + 1
        }

        i = 8 - code.count / 2 - 1
        if ( (array.count % 2) == 1 ) {
            i = i - 1
            parserCode.append( UInt8( (array.last! << 4) | 0x0F ) ) //last Byte
        }

        while ( i > 0 )
        {
            parserCode.append( 0xFF ) //Filter value of 0b1111
            i = i - 1
        }

//        for d:UInt8 in parserCode{
//            print(String(format:"%02X",d))
//        }
        return parserCode
    }

    internal func VerifyEnrollCode( _ nfcTag:NFCISO7816Tag, _ code:Data ) async -> (UInt8, UInt8) {
        //print("VerifyEnrollCode() Async")
        var sw1:UInt8 = 0
        var sw2:UInt8 = 0
        var restartPolling = false
        let verifyEnrollCode = NFCISO7816APDU.init(instructionClass: 0x00, instructionCode: 0x20, p1Parameter: 0x00, p2Parameter: 0x80, data: code, expectedResponseLength: 0x02)
        ( _, sw1, sw2, restartPolling ) =  await SendCommand( nfcTag, verifyEnrollCode )
        if restartPolling {
            return (sw1, sw2)
        }

        if ( (sw1, sw2) == SUCCESS || (sw1, sw2) == CMD_NOT_SUPPORT ) {
            //Verify success or No Biometric Enrollment Code
        } else {
            resp.returnCode = .ENROLL_CODE_NEEDED
            resp.enrollCodeTryLimit = Int(sw2 & 0x0F)
            delegate?.UpdateResponse( resp )
            readerSession?.invalidate()
            engine.stop()
        }

        logger.write(String(format:"Verify Biometric Enrollment Code: 0x%02X%02X.", sw1, sw2))

        return (sw1, sw2)
    }

    internal func SingleEnroll( _ nfcTag:NFCISO7816Tag, _ enrollData:Data ) async -> (UInt8, UInt8, Bool) {
        //print("SingleEnroll() async")
        var sw1:UInt8 = 0
        var sw2:UInt8 = 0
        var data:Data = .init()
        var restartPolling = false
        let singleEnroll = NFCISO7816APDU.init(instructionClass: 0x00, instructionCode: 0x59, p1Parameter: 0x03, p2Parameter: 0x00, data: enrollData, expectedResponseLength: 0x02)
        ( data, sw1, sw2, restartPolling ) =  await SendCommand( nfcTag, singleEnroll )
        if ( (sw1, sw2) == SUCCESS ) {
            engine.start()
            resp.touchCompleted = Int(data[0])
            resp.touchTotal = touch
            resp.fingerCurrent = finger
            resp.fingersTotal = status.totalFingersEnroll
            resp.returnCode = .ENROLL_ACTIVE
            delegate?.UpdateResponse( resp )
            engine.playSuccess()
            engine.playTick(1)
        } else if ( (sw1, sw2) == BAD_QUALITY ) {
            resp.returnCode = .BAD_COVERAGE
            delegate?.UpdateResponse( resp )
        } else if ( (sw1, sw2) == WRONG_STATE ) {
            resp.returnCode = .NOT_POSSIBLE
            delegate?.UpdateResponse( resp )
            readerSession?.invalidate(errorMessage: alertMessage)
        }

        logger.write(String(format:"SingleEnroll() finger: \(finger), touch completed: \(resp.touchCompleted), return: 0x%02X%02X.", sw1, sw2))

        return (sw1, sw2, restartPolling)
    }

    internal func FingerDetect( _ nfcTag:NFCISO7816Tag ) async -> (UInt8, UInt8, Bool) {
        //print("FingerDetect() async")
        var sw1:UInt8 = 0
        var sw2:UInt8 = 0
        var restartPolling = false
        let fingerDetect = NFCISO7816APDU.init(data:Data.init([0x00, 0x59, 0x03, 0x00, 0x02, 0x38, 0x01]))
        ( _, sw1, sw2, restartPolling ) =  await SendCommand( nfcTag, fingerDetect! )

        //print(String(format:"Finger Detect: 0x%02X%02X", sw1, sw2))

        return (sw1, sw2, restartPolling)
    }

    internal func Enroll( _ nfcTag:NFCISO7816Tag ) {
        //print("Enroll()")
        Task{
            var (sw1, sw2, restartPolling) = await GetCurrent( nfcTag )

            if ( enrollCode[0] == 0x20 ) { //No Enroll code input.
                (sw1, sw2, _) = await GetCardStatus( nfcTag )
                if ( (sw1, sw2) == WRONG_STATE ) { //Enroll code required.
                    return
                }
            } else {
                (sw1, sw2) = await VerifyEnrollCode( nfcTag, enrollCode )
                if ( (sw1, sw2) != SUCCESS && (sw1, sw2) != CMD_NOT_SUPPORT ) {
                    return
                }
                (sw1, sw2, _) = await GetCardStatus( nfcTag )
            }

            if (sw1, sw2) == SUCCESS {
                if ( status.fingerToEnrollNext == 1 ) {
                    touch = status.f1_NumOfEnrolledTouches + status.f1_NumOfTouchesLeftToEnroll
                    progress = status.f1_NumOfEnrolledTouches
                } else { // 2 fingers
                    touch = status.f2_NumOfEnrolledTouches + status.f2_NumOfTouchesLeftToEnroll
                    progress = status.f2_NumOfEnrolledTouches
                }
                finger = status.fingerToEnrollNext

                if ( resetBio ) { //reset biometrics
                    //Prevent users from starting an enroll but not able to complete it.
                    if ( finger <= 1 &&
                         ( ( status.numOfReenrollAttemptsLeft <= 1 && status.API_Version == 0 ) ||
                           ( status.numOfReenrollAttemptsLeft < status.totalFingersEnroll && status.API_Version == 1 ) ) ) {
                        resp.returnCode = .NOT_POSSIBLE
                        delegate?.UpdateResponse( resp )
                        engine.stop()
                        readerSession?.invalidate(errorMessage: alertMessage)
                        return
                    }

                    progress = 0
                    touch = status.f1_NumOfEnrolledTouches + status.f1_NumOfTouchesLeftToEnroll
                    if 1 == status.API_Version {
                        (sw1, sw2) = await DeleteFinger( nfcTag, finger )
                    }
                    if ( 0 == finger ) {
                        finger = 1
                    }
                } else if ( resp.returnCode != .ENROLL ) {
                    delegate?.UpdateResponse( resp )
                    engine.stop()
                    readerSession?.invalidate()
                    return
                }

                logger.write(String(format:"Finger: %d, Touch: %d, Progress: %d.", finger, touch, progress))

                resp.returnCode = .INITIALIZE
                delegate?.UpdateResponse( resp )

                while ( progress < touch ) {
                    //Wait for finger ON
                    while ( progress < touch ) {
                        (sw1, sw2, restartPolling) = await GetCurrent( nfcTag )
                        if restartPolling {
                            return
                        }

                        (sw1, sw2, restartPolling) = await FingerDetect( nfcTag )
                        if (sw1, sw2) == SUCCESS {
                            //print("WFF ON FingerDetect")
                            break
                        } else if ( (sw1, sw2) == ERR_CALIB
                                    || (sw1, sw2) == WRONG_STATE
                                    || (sw1, sw2) == CMD_NOT_ALLOWED) {
                            resp.returnCode = .NOT_POSSIBLE
                            delegate?.UpdateResponse( resp )
                            readerSession?.invalidate(errorMessage: alertMessage)
                            return
                        } else if restartPolling {
                            return
                        }
                    }

                    var flag : UInt8 = 0x18 //by default continue enroll
                    if ( progress == 0 && resetBio ) {
                        flag = 0x1A
                        resetBio = false
                    } else {
                        flag = 0x18
                    }
                    let enrollData:Data = .init( [ flag, UInt8(finger) ] )
                    (sw1, sw2, restartPolling) = await SingleEnroll( nfcTag, enrollData )
                    if ( (sw1, sw2) == SUCCESS ) {
                        progress = progress + 1
                    } else if restartPolling {
                        return
                    }

                    //Wait for finger OFF
                    while ( progress < touch ) {
                        (sw1, sw2, restartPolling) = await FingerDetect( nfcTag )
                        if (sw1, sw2) == SUCCESS {
                            //Finger Detected. continue waiting
                        } else if restartPolling {
                            return
                        } else {
                            //Finger OFF, restart NFC polling to avoid timeout and terminate this thread.
                            readerSession!.restartPolling()
                            logger.write("restartPolling to avoid timeout.")
                            return
                        }

                        (sw1, sw2, restartPolling) = await GetCurrent( nfcTag )
                        if restartPolling {
                            return
                        }
                    }
                }
                if progress == touch {
                    (sw1, sw2, _) = await GetCardStatus( nfcTag )
                    if (sw1, sw2) == SUCCESS {
                        delegate?.UpdateResponse( resp )
                    }
                    readerSession?.invalidate()
                    engine.stop()
                }
            }
        }
    }

    internal func SingleQualify( _ nfcTag:NFCISO7816Tag ) async -> (UInt8, UInt8, Bool) {
        //print("SingleQualify() async")
        var sw1:UInt8 = 0
        var sw2:UInt8 = 0
        var restartPolling = false
        let singleQualify = NFCISO7816APDU.init(data:Data.init([0x00, 0x59, 0x00, 0x00, 0x01, 0x14]))
        ( _, sw1, sw2, restartPolling ) = await SendCommand( nfcTag, singleQualify! )
        if ( (sw1, sw2) == SUCCESS) {
            resp.qualTotal -= 1 // Qual Pass 1 time, so reduce 1.
            resp.returnCode = .QUAL_ACTIVE
            engine.playSuccess()
            engine.playTick(1)
            delegate?.UpdateResponse( resp )
        } else if ( (sw1, sw2) == AUTH_FAILED ) {
           resp.returnCode = .QUAL_NO_MATCH
           delegate?.UpdateResponse( resp )
        } else if ( (sw1, sw2) == BAD_QUALITY ) {
           resp.returnCode = .BAD_COVERAGE
           delegate?.UpdateResponse( resp )
        }

        logger.write(String(format:"Single Qualify: 0x%02X%02X.", sw1, sw2))

        return (sw1, sw2, restartPolling)
    }
    
    internal func Qualify( _ nfcTag:NFCISO7816Tag ) {
        //print("Qualify()")
        Task{
            var restartPolling : Bool = false
            var (sw1, sw2) = await VerifyEnrollCode( nfcTag, enrollCode )
            if ( (sw1, sw2) == SUCCESS || (sw1, sw2) == CMD_NOT_SUPPORT ) {
                (sw1, sw2, restartPolling) = await GetCurrent( nfcTag )
                (sw1, sw2, restartPolling) = await GetCardStatus( nfcTag )
                if (sw1, sw2) == SUCCESS {
                    if ( resp.returnCode != .QUALIFY) {
                        delegate?.UpdateResponse( resp )
                        readerSession?.invalidate(errorMessage: alertMessage)
                        return
                    }

                    resp.returnCode = .INITIALIZE
                    delegate!.UpdateResponse( resp )

                    while ( resp.qualTotal > 0 ) {
                        while( resp.qualTotal > 0 ) { //Wait for finger ON
                            (sw1, sw2, restartPolling) = await GetCurrent( nfcTag )
                            if restartPolling {
                                return
                            }

                            (sw1, sw2, restartPolling) = await FingerDetect( nfcTag )
                            if (sw1, sw2) == SUCCESS {
                                //print("WFF ON, Finger Detected")
                                break
                            } else if ( (sw1, sw2) == ERR_CALIB
                                        || (sw1, sw2) == WRONG_STATE
                                        || (sw1, sw2) == CMD_NOT_ALLOWED) {
                                resp.returnCode = .NOT_POSSIBLE
                                delegate?.UpdateResponse( resp )
                                readerSession?.invalidate(errorMessage: alertMessage)
                                return
                            } else if restartPolling {
                                return
                            }
                        }

                        (sw1, sw2, restartPolling) = await SingleQualify( nfcTag )
                        if ( (sw1, sw2) == SUCCESS ) {
                        } else if restartPolling {
                            return
                        }

                        //Wait for finger OFF
                        while ( resp.qualTotal > 0 ) {
                            (sw1, sw2, restartPolling) = await FingerDetect( nfcTag )
                            if (sw1, sw2) == SUCCESS {
                                //Finger Detected. continue waiting
                            } else if restartPolling {
                                return
                            } else {
                                //Finger OFF, restart NFC polling to avoid timeout and terminate this thread.
                                readerSession!.restartPolling()
                                logger.write("restartPolling to avoid timeout.")
                                return
                            }

                            (sw1, sw2, restartPolling) = await GetCurrent( nfcTag )
                            if restartPolling {
                                return
                            }
                        }
                    }

                    (sw1, sw2, restartPolling) = await GetCardStatus( nfcTag )
                    if (sw1, sw2) == SUCCESS {
                        delegate?.UpdateResponse( resp )
                    }
                    readerSession?.invalidate()
                    engine.stop()
                }
            }
        }
    }


    internal func GetCurrent( _ nfcTag:NFCISO7816Tag ) async -> (UInt8, UInt8, Bool) {
        //print("GetCurrent async")
        var sw1:UInt8 = 0
        var sw2:UInt8 = 0
        var data:Data = .init()
        var restartPolling = false
        let getCurrent = NFCISO7816APDU.init(data:Data.init([0x00, 0x59, 0x01, 0x00, 0x01, 0x00]))
        ( data, sw1, sw2, restartPolling ) = await SendCommand( nfcTag, getCurrent! )
        if ( (sw1, sw2) == SUCCESS ){
            engine.stop()
            current = Int(data[1]) * 0x100 + Int(data[0]);
            if (current > 0) {
                resp.strengthPercent = FIELD_STRENGTH[current/300]
                resp.returnCode = .FIELD_STRENGTH
                delegate?.UpdateResponse( resp )
            }
        }
        //logger.write(String(format:"Get Current return: 0x%02X%02X.", sw1, sw2))

        return (sw1, sw2, restartPolling)
    }

    internal func GetCardStatus( _ nfcTag:NFCISO7816Tag ) async -> (UInt8, UInt8, Bool) {
        //print("GetCardStatus() async")
        var sw1:UInt8 = 0
        var sw2:UInt8 = 0
        var data:Data = .init()
        var restartPolling = false
        let getStatus = NFCISO7816APDU.init(data:Data.init([0x00, 0x59, 0x04, 0x00, 0x01, 0x00]))
        ( data, sw1, sw2, restartPolling ) = await SendCommand( nfcTag, getStatus! )
        if ( (sw1, sw2) == SUCCESS ) {
            var i:Int = 1
            status.API_Version = Int(data[0])
            status.uid.removeAll()
            if ( 0 == status.API_Version ) {
                while ( i < 31 ) {
                    status.uid += String(format:"%02X", data[i])
                    i += 1
                }
                status.totalFingersEnroll  = Int(data[i])
                i += 1
                status.f1_NumOfEnrolledTouches  = Int(data[i])
                i += 1
                status.f1_NumOfTouchesLeftToEnroll = Int(data[i])
                i += 1
                status.f1_TopupEnrolledTouches = Int(data[i])
                i += 1
                if ( status.totalFingersEnroll > 1 ) {
                    status.f2_NumOfEnrolledTouches = Int(data[i])
                    i += 1
                    status.f2_NumOfTouchesLeftToEnroll = Int(data[i])
                    i += 1
                    status.f2_TopupEnrolledTouches = Int(data[i])
                    i += 1
                } else {
                    status.f2_NumOfEnrolledTouches = 0
                    status.f2_NumOfTouchesLeftToEnroll = 0
                    status.f2_TopupEnrolledTouches = 0
                }
                status.fingerToEnrollNext = Int(data[i])
                i += 1
                status.numOfQualifyTouchesLeft = Int(data[i])
                i += 1
                status.numOfQualifyPassesLeft = Int(data[i])
                i += 1
                status.numOfReenrollAttemptsLeft = Int(data[i])
                i += 1
                status.mode = Int(data[i])
                i += 1
                status.topupTouchesLeftToEnroll = Int(data[i])
                i += 1
                status.topupAttemptsLeft = Int(data[i])

                //Enroll :0, Verify(topup):1, Veify: 2
                if ( status.mode == 0 ){
                    if ( status.f1_NumOfTouchesLeftToEnroll > 0 || status.f2_NumOfTouchesLeftToEnroll > 0 ) {
                        if ( status.fingerToEnrollNext == 1 ) {
                            resp.touchCompleted = status.f1_NumOfEnrolledTouches
                            resp.touchTotal = status.f1_NumOfTouchesLeftToEnroll + status.f1_NumOfEnrolledTouches
                        } else {
                            resp.touchCompleted = status.f2_NumOfEnrolledTouches
                            resp.touchTotal = status.f2_NumOfTouchesLeftToEnroll  + status.f2_NumOfEnrolledTouches
                        }

                        resp.returnCode = .ENROLL
                    } else {
                        resp.touchTotal = status.f1_NumOfTouchesLeftToEnroll + status.f1_NumOfEnrolledTouches
                        resp.touchCompleted = resp.touchTotal
                        if status.numOfQualifyPassesLeft > 0 && status.numOfQualifyTouchesLeft == 0 {
                            resp.returnCode = .NOT_POSSIBLE
                        } else {
                            resp.returnCode = .QUALIFY
                        }
                    }
                } else if ( status.mode == 1 || status.mode == 2 ) {
                    resp.returnCode = .VERIFY
                    resp.touchTotal = status.f1_NumOfTouchesLeftToEnroll + status.f1_NumOfEnrolledTouches
                    resp.touchCompleted = resp.touchTotal
                }
                resp.fingerCurrent = status.fingerToEnrollNext
                resp.fingersTotal = status.totalFingersEnroll
                resp.qualTotal = status.numOfQualifyPassesLeft
                
                logger.write("mode: \(status.mode).")
                logger.write("numOfReenrollAttemptsLeft: \(status.numOfReenrollAttemptsLeft).")
                logger.write("numOfQualifyTouchesLeft: \(status.numOfQualifyTouchesLeft).")
                logger.write("numOfQualifyPassesLeft: \(status.numOfQualifyPassesLeft).")

            } else if ( 1 == status.API_Version ) {
                while (i < 31){
                    status.uid += String(format:"%02X", data[i])
                    i += 1
                }
                status.totalFingersEnroll  = Int(data[i])
                i += 1
                status.f1_NumOfEnrolledTouches  = Int(data[i])
                i += 1
                status.f1_NumOfTouchesLeftToEnroll = Int(data[i])
                i += 1
                status.f1_TopupEnrolledTouches = Int(data[i])
                i += 1
                status.f1_QualifyTouchesLeft = Int(data[i])
                i += 1
                status.f1_QualifyPassesLeft = Int(data[i])
                i += 1
                status.f1_BiometricMode = Int(data[i])
                i += 1
                status.f1_TopupTouchesLeftToEnroll = Int(data[i])
                i += 1
                status.f1_TopupAttemptsLeft = Int(data[i])
                i += 1
                if ( status.totalFingersEnroll > 1 ) {
                    status.f2_NumOfEnrolledTouches  = Int(data[i])
                    i += 1
                    status.f2_NumOfTouchesLeftToEnroll = Int(data[i])
                    i += 1
                    status.f2_TopupEnrolledTouches = Int(data[i])
                    i += 1
                    status.f2_QualifyTouchesLeft = Int(data[i])
                    i += 1
                    status.f2_QualifyPassesLeft = Int(data[i])
                    i += 1
                    status.f2_BiometricMode = Int(data[i])
                    i += 1
                    status.f2_TopupTouchesLeftToEnroll = Int(data[i])
                    i += 1
                    status.f2_TopupAttemptsLeft = Int(data[i])
                    i += 1
                } else {
                    status.f2_NumOfEnrolledTouches  = 0
                    status.f2_NumOfTouchesLeftToEnroll = 0
                    status.f2_TopupEnrolledTouches = 0
                    status.f2_QualifyTouchesLeft = 0
                    status.f2_QualifyPassesLeft = 0
                    status.f2_BiometricMode = 0
                    status.f2_TopupTouchesLeftToEnroll = 0
                    status.f2_TopupAttemptsLeft = 0
                }
                status.numOfReenrollAttemptsLeft = Int(data[i])
                i += 1
                status.fingerToEnrollNext = Int(data[i])
                i += 1
                status.mode =  Int(data[i])

                //Enroll: 0, Qualify: 1, Verify(topup): 2, Veify: 3, Qualify Failed: 4.
                if ( status.fingerToEnrollNext == 0 ) {
                    resp.touchTotal  = status.f1_NumOfEnrolledTouches
                    resp.touchCompleted = resp.touchTotal
                    resp.qualTotal = 0
                    if  ( status.f1_BiometricMode == 2 || status.f1_BiometricMode == 3 ) {
                        resp.returnCode = .VERIFY
                    } else if  ( status.f2_BiometricMode == 2 || status.f2_BiometricMode == 3 ) {
                        resp.returnCode = .VERIFY
                    } else if ( status.f1_BiometricMode == 4 && status.f2_BiometricMode == 4) {
                        resp.returnCode = .NOT_POSSIBLE
                    } else {
                        logger.write("Should not reach to here!")
                    }
                } else if ( status.fingerToEnrollNext == 1 ) {
                    resp.qualTotal = status.f1_QualifyPassesLeft
                    resp.touchTotal = status.f1_NumOfTouchesLeftToEnroll + status.f1_NumOfEnrolledTouches
                    if ( status.f1_BiometricMode == 0 ) {
                        resp.returnCode = .ENROLL
                        resp.touchCompleted = status.f1_NumOfEnrolledTouches
                    } else if  ( status.f1_BiometricMode == 1 ) {
                        resp.returnCode = .QUALIFY
                        resp.touchCompleted = resp.touchTotal
                    } else {
                        logger.write("Should not reach to here!")
                    }
                } else if ( status.fingerToEnrollNext == 2 ) {
                    resp.qualTotal = status.f2_QualifyPassesLeft
                    resp.touchTotal = status.f2_NumOfTouchesLeftToEnroll  + status.f2_NumOfEnrolledTouches
                    if ( status.f2_BiometricMode == 0 ) {
                        resp.returnCode = .ENROLL
                        resp.touchCompleted = status.f2_NumOfEnrolledTouches
                    }  else if ( status.f2_BiometricMode == 1 ) {
                        resp.touchCompleted = resp.touchTotal
                        resp.returnCode = .QUALIFY
                    } else {
                        logger.write("Should not reach to here!")
                    }
                }

                resp.fingerCurrent = status.fingerToEnrollNext
                resp.fingersTotal = status.totalFingersEnroll

                logger.write(String(format:"API_Version                : %d", status.API_Version))
                logger.write(String(format:"uid                        : "  + status.uid))
                logger.write(String(format:"totalFingersEnroll         : %d", status.totalFingersEnroll))

                logger.write(String(format:"f1_NumOfEnrolledTouches    : %d", status.f1_NumOfEnrolledTouches))
                logger.write(String(format:"f1_NumOfTouchesLeftToEnroll: %d", status.f1_NumOfTouchesLeftToEnroll))
                logger.write(String(format:"f1_TopupEnrolledTouches    : %d", status.f1_TopupEnrolledTouches))
                logger.write(String(format:"f1_QualifyTouchesLeft      : %d", status.f1_QualifyTouchesLeft))
                logger.write(String(format:"f1_QualifyPassesLeft       : %d", status.f1_QualifyPassesLeft))
                logger.write(String(format:"f1_BiometricMode           : %d", status.f1_BiometricMode))
                logger.write(String(format:"f1_TopupTouchesLeftToEnroll: %d", status.f1_TopupTouchesLeftToEnroll))
                logger.write(String(format:"f1_TopupAttemptsLeft       : %d", status.f1_TopupAttemptsLeft))

                logger.write(String(format:"f2_NumOfEnrolledTouches    : %d", status.f2_NumOfEnrolledTouches))
                logger.write(String(format:"f2_NumOfTouchesLeftToEnroll: %d", status.f2_NumOfTouchesLeftToEnroll))
                logger.write(String(format:"f2_TopupEnrolledTouches    : %d", status.f2_TopupEnrolledTouches))
                logger.write(String(format:"f2_QualifyTouchesLeft      : %d", status.f2_QualifyTouchesLeft))
                logger.write(String(format:"f2_QualifyPassesLeft       : %d", status.f2_QualifyPassesLeft))
                logger.write(String(format:"f2_BiometricMode           : %d", status.f2_BiometricMode))
                logger.write(String(format:"f2_TopupTouchesLeftToEnroll: %d", status.f2_TopupTouchesLeftToEnroll))
                logger.write(String(format:"f2_TopupAttemptsLeft       : %d", status.f2_TopupAttemptsLeft))

                logger.write(String(format:"numOfReenrollAttemptsLeft  : %d", status.numOfReenrollAttemptsLeft))
                logger.write(String(format:"fingerToEnrollNext         : %d", status.fingerToEnrollNext))
                logger.write(String(format:"mode                       : %d", status.mode))

            } else {
                logger.write("GetCardStatus, Invalidated API version!")
            }
        } else if ( (sw1, sw2) == WRONG_STATE ){
            resp.returnCode = .ENROLL_CODE_NEEDED
            resp.enrollCodeTryLimit = -1
            delegate?.UpdateResponse( resp )
            readerSession?.invalidate()
            engine.stop()
        }

        logger.write(String(format:"Get Status return: 0x%02X%02X.", sw1, sw2))

        return (sw1, sw2, restartPolling)
    }

    internal func DeleteFinger( _ nfcTag:NFCISO7816Tag, _ id:Int ) async -> (UInt8, UInt8) {
        //print("DeleteFinger async")
        var sw1:UInt8 = 0
        var sw2:UInt8 = 0

        let deleteFinger = NFCISO7816APDU.init(data:Data.init([CLA, 0x59, 0x02, 0x00, 0x01, UInt8(id)]))
        ( _, sw1, sw2, _ ) = await SendCommand(nfcTag, deleteFinger!)

        return (sw1, sw2)
    }

    internal func SendCommand ( _ nfcTag:NFCISO7816Tag, _ apdu:NFCISO7816APDU ) async ->(Data, UInt8, UInt8, Bool) {
        var sw1:UInt8 = 0
        var sw2:UInt8 = 0
        var data:Data = .init()
        var restartPolling:Bool = false
        do {
            (data, sw1, sw2) =  try await nfcTag.sendCommand( apdu: apdu )

            //print(String(format:"sendCommand return: 0x%02X%02X", sw1, sw2))
        } catch {
            (sw1, sw2) = NFC_TRANS_ERROR
            logger.write("sendCommand Error: \(error.localizedDescription).")
        }

        if ( (sw1, sw2) == NFC_TRANS_ERROR ||
             (sw1, sw2) == COMM_ERROR ||
             (sw1, sw2) == CMD_TIMEOUT ||
             (sw1, sw2) == SENSOR_NO_POWER ||
             (sw1, sw2) == SE_NO_POWER  ||
             (sw1, sw2) == CMD_ABORTED )
        {
            resp.returnCode = .DISCONNECTED
            delegate?.UpdateResponse( resp )
            readerSession?.restartPolling()

            engine.start()
            engine.playContinuousTick(1)
            engine.playTimer()

            restartPolling = true
        }

        return (data, sw1, sw2, restartPolling)
    }


}
