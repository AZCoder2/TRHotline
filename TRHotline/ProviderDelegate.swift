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
    
    func reportIncomingCall(uuid: UUID, handle: String, hasVideo: Bool = false, completion: ((NSError?) -> Void)?) {
        
        // Prepare call update for system with metadata
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .phoneNumber, value: handle)
        update.hasVideo = hasVideo
        
        // Notify system of incoming call
        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            if error == nil {
                
                // Completion handler - succcess
                let call = Call(uuid: uuid, handle: handle)
                self.callManager.add(call: call)
            }
            
            // Completion handler - failure
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
}
