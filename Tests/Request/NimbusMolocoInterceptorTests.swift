//
//  NimbusMolocoInterceptorTests.swift
//  Nimbus
//  Created on 6/2/25
//  Copyright © 2025 Nimbus Advertising Solutions Inc. All rights reserved.
//

@testable import NimbusMolocoKit
@testable import NimbusKit
import MolocoSDK
import Testing

@Suite("Moloco request interceptor tests")
struct NimbusMolocoInterceptorTests {
    
    let interceptor = NimbusMolocoRequestInterceptor(bridge: MockMolocoRequestBridge())
    
    @Test func bidTokenAndRenderInfoGetsSet() async throws {
        let info = try NimbusRequest(from: await Nimbus.bannerAd(position: "test", size: .banner).adRequest!.request)
        let deltas = try await interceptor.modifyRequest(request: info)
        
        #expect(deltas.count == 1)
        #expect(deltas[0].key == "moloco_buyeruid")
        #expect(deltas[0].target == .user)
        #expect(deltas[0].value as? String == "unitTestBuyerUID")
    }
    
    @Test func molocoBidTokenGetsInsertedIntoRequest() async throws {
        var request = try await Nimbus.rewardedAd(position: "position").adRequest!.request
        request.interceptors = [interceptor]
        
        try await request.modifyRequestWithExtras(
            configuration: Nimbus.configuration,
            vendorId: "",
            appVersion: "1.0.0"
        )
        
        #expect(request.user?.ext?.extras["moloco_buyeruid"] as? String == "unitTestBuyerUID")
    }
    
    @MainActor private func createNimbusAd(network: String) -> NimbusResponse {
        NimbusResponse(id: "", bid: .init(mtype: .static, adm: "", price: 0, ext: .init(omp: .init(buyer: network, buyerPlacementId: nil))))
    }
}

final class MockMolocoRequestBridge: MolocoRequestBridgeType {
    func bidToken() async throws -> String {
        "unitTestBuyerUID"
    }
}
