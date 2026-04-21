//
//  NimbusMolocoInterceptor.swift
//  Nimbus
//  Created on 5/28/25
//  Copyright © 2025 Nimbus Advertising Solutions Inc. All rights reserved.
//

import Foundation
import NimbusKit

final class NimbusMolocoRequestInterceptor {
    
    /// Bridge that communicates with Moloco SDK
    private let bridge: MolocoRequestBridgeType
    
    init(bridge: MolocoRequestBridgeType = MolocoRequestBridge()) {
        self.bridge = bridge
    }
}

extension NimbusMolocoRequestInterceptor: NimbusRequest.Interceptor {
    public func modifyRequest(request: NimbusRequest) async throws -> [NimbusRequest.Delta] {
        let bidToken = try await bridge.bidToken()
        try Task.checkCancellation()
        
        return [.init(target: .user, key: "moloco_buyeruid", value: bidToken)]
    }
}
