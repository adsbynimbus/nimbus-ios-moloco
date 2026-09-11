//
//  MolocoRequestBridge.swift
//  Nimbus
//  Created on 5/28/25
//  Copyright © 2025 Nimbus Advertising Solutions Inc. All rights reserved.
//

import MolocoSDK
import NimbusKit

protocol MolocoRequestBridgeType: Sendable {
    func bidToken() async throws -> String
}

final class MolocoRequestBridge: MolocoRequestBridgeType {
    init() {}
    
    @inlinable
    static func set(coppa: Bool) {
        MolocoPrivacySettings.isAgeRestrictedUser = coppa
    }
    
    @concurrent func bidToken() async throws -> String {
        try await withUnsafeThrowingContinuation { continuation in
            Moloco.shared.getBidToken(params: .init(mediation: Nimbus.sdkName)) { bidToken, error in
                guard let bidToken, error == nil else {
                    continuation.resume(throwing: NimbusError.moloco(
                        stage: .request,
                        detail: "Couldn't fetch bid token")
                    )
                    return
                }
                
                continuation.resume(returning: bidToken)
            }
        }
    }
}
