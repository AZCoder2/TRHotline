//
//  ProviderDelegate.swift
//  TRHotline
//
//  Created by Tom Ranalli on 4/14/17.
//  Copyright © 2017 Latitude23. All rights reserved.
//

import Foundation
import AVFoundation
import CallKit

import os.log

class ProviderDelegate: NSObject {
    
    // Storage for both provider and call manager
    fileprivate let callManager: CallManager
    fileprivate let provider: CXProvider
    
    init(callManager: CallManager) {
        self.callManager = callManager
        
        // Initialize the provider with the appropriate CXProviderConfiguration
        provider = CXProvider(configuration: type(of: self).providerConfiguration)
        
        super.init()
        
        // Set delegate
        provider.setDelegate(self, queue: nil)
    }
    
    // Customize call
    static var providerConfiguration: CXProviderConfiguration {
        let providerConfiguration = CXProviderConfiguration(localizedName: "Hotline")
        
        providerConfiguration.supportsVideo = true
        providerConfiguration.maximumCallsPerCallGroup = 1
        providerConfiguration.supportedHandleTypes = [.phoneNumber]
        
        return providerConfiguration
    }
    
    func reportIncomingCall(uuid: UUID,
                            handle: String,
                            hasVideo: Bool = false,
                            completion: ((NSError?) -> Void)?) {
        
        os_log("Entering reportIncomingCall", log: OSLog.default, type: .debug)
        
        // Prepare call update for system with metadata
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .phoneNumber, value: handle)
        update.hasVideo = hasVideo
        
        // Notify system of incoming call
        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            if error == nil {
                
                // Completion handler - success
                os_log("Incoming call detected", log: OSLog.default, type: .debug)
                let call = Call(uuid: uuid, handle: handle)
                self.callManager.add(call: call)
            }
            
            // Completion handler - failure
            os_log("Failed incoming call", log: OSLog.default, type: .debug)
            completion?(error as NSError?)
        }
    }
}

extension ProviderDelegate: CXProviderDelegate {
    
    // Clean up on provider clean-up
    func providerDidReset(_ provider: CXProvider) {
        stopAudio()
        
        for call in callManager.calls {
            call.end()
        }
        
        callManager.removeAllCalls()
    }
    
    // Process answer call action
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        
        // Get refererence to call manager with related UUID
        guard let call = callManager.callWithUUID(uuid: action.callUUID) else {
            action.fail()
            return
        }
        
        // Configure audio session by activating session at higher priority
        configureAudioSession()
        
        // Answer indicates call is now active
        call.answer()
        
        // Fail or fulfill
        action.fulfill()
    }
    
    // Begin processing audio
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        startAudio()
    }
    
    // Process end call action
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        
        // Get reference to call manager with related UID
        guard let call = callManager.callWithUUID(uuid: action.callUUID) else {
            action.fail()
            return
        }
        
        // End audio
        stopAudio()
        
        // End call
        call.end()
        
        // Fail or fulfill
        action.fulfill()
        
        // Dispose of call
        callManager.remove(call: call)
    }
    
    // Process a held call
    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        guard let call = callManager.callWithUUID(uuid: action.callUUID) else {
            action.fail()
            return
        }
        
        // Update state of call based on on-hold flag
        call.state = action.isOnHold ? .held : .active
        
        // If on hold, stop audio, otherwise start audio
        if call.state == .held {
            stopAudio()
        } else {
            startAudio()
        }
        
        // Fail or fulfill
        action.fulfill()
    }
}
