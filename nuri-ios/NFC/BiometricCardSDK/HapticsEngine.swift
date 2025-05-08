import Foundation
import CoreHaptics
import UIKit
import AVKit

import AVFoundation

@available(iOS 13.0, *)
class HapticsEngine {
    private var engine: CHHapticEngine?
    private var engineNeedsStart = true
    public var keepLooping = true;
    public var player: AVAudioPlayer?
    public var player2: AVAudioPlayer?
    
    private lazy var supportsHaptics: Bool = {
        return CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }()
    
    func playSuccess() {
        guard let url = Bundle.main.url(forResource: "success", withExtension: "mp3") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.mp3.rawValue)
            guard let player = player else { return }
            player.play()

        } catch let error {
            print(error.localizedDescription)
        }
    }
    func playTimer() {
        guard let url = Bundle.main.url(forResource: "timer", withExtension: "mp3") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player2 = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.mp3.rawValue)
            guard let player2 = player2 else { return }
            player2.play()
        } catch let error {
            print(error.localizedDescription)
        }
    }
    
    func playTick(_ intensity: Float) {
        if supportsHaptics {
            do {
                let intensityParameter = CHHapticEventParameter(parameterID: .hapticIntensity,
                                                                value: intensity)
                let sharpnessParameter = CHHapticEventParameter(parameterID: .hapticSharpness,
                                                                value: 0.5)
                let event = CHHapticEvent(eventType: .hapticTransient,
                                          parameters: [intensityParameter, sharpnessParameter],
                                          relativeTime: 0)
                
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                let player = try engine?.makePlayer(with: pattern)
                try player?.start(atTime: CHHapticTimeImmediate)
            } catch let error {
                print("Error creating a haptic transient pattern: \(error)")
            }
        }
    }
    
    func playContinuousTick(_ intensity: Float) {
        keepLooping = true
        
        DispatchQueue.global(qos: .userInteractive).async {
            if self.supportsHaptics {
                do {
                    let intensityParameter = CHHapticEventParameter(parameterID: .hapticIntensity,
                                                                    value: intensity)
                    
                    let sharpnessParameter = CHHapticEventParameter(parameterID: .hapticSharpness,
                                                                    value: 0.5)
                    
                    let event = CHHapticEvent(eventType: .hapticTransient,
                                              parameters: [intensityParameter, sharpnessParameter],
                                              relativeTime: 0)
                    
                    let pattern = try CHHapticPattern(events: [event], parameters: [])
                    
                    let player = try self.engine?.makePlayer(with: pattern)
                    
                    while self.keepLooping {
                        try player?.start(atTime: CHHapticTimeImmediate)
                        let delayBetweenRepetitions = 0.5
                        Thread.sleep(forTimeInterval: delayBetweenRepetitions)
                    }
                } catch let error {
                    print("Error creating or playing the haptic pattern: \(error)")
                }
            }
        }
    }
    
    func stopLoop() {
        keepLooping = false;
    }
    
    func stop() {
        guard supportsHaptics else {
            return
        }
        
        player2?.stop()
        
        engine?.stop(completionHandler: { [weak self] error in
            if let error = error {
                print("Haptic Engine Shutdown Error: \(error)")
                return
            }
            self?.engineNeedsStart = true
        })
    }
    
    func start() {
        guard supportsHaptics && engineNeedsStart else {
            return
        }
        
        engine?.start(completionHandler: { [weak self] error in
            if let error = error {
                print("Haptic Engine Start Error: \(error)")
                return
            }
            self?.engineNeedsStart = false
        })
    }
    
    func create() {
        guard supportsHaptics else {
            return
        }
        
        do {
            engine = try CHHapticEngine()
            engine!.playsHapticsOnly = true
            engine!.stoppedHandler = { [weak self] reason in
                print("CHHapticEngine stop handler: The engine stopped for reason: \(reason.rawValue)")
                self?.engineNeedsStart = true
            }
            engine!.resetHandler = { [weak self] in
                print("Reset Handler: Restarting the engine.")
                do {
                    try self?.engine?.start()
                    self?.engineNeedsStart = false
                    
                } catch {
                    print("Failed to start the engine with error: \(error)")
                }
            }
        } catch {
            print("CHHapticEngine error: \(error)")
        }
    }
}
