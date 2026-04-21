//
//  MolocoExtension.swift
//  Nimbus
//  Created on 7/7/25
//  Copyright © 2025 Nimbus Advertising Solutions Inc. All rights reserved.
//

import NimbusKit
import MolocoSDK
import UIKit

/// Nimbus extension for Moloco.
///
/// Enables Moloco rendering when included in `Nimbus.initialize(...)`.
/// Supports dynamic enable/disable at runtime.
///
/// ### Notes:
///   - Instantiate within the `Nimbus.initialize` block; the extension is installed and enabled automatically.
///   - Disable rendering with `MolocoExtension.disable()`.
///   - Re-enable rendering with `MolocoExtension.enable()`.
public struct MolocoExtension: NimbusRequestExtension, NimbusRenderExtension {
    @_documentation(visibility: internal)
    public var interceptor: any NimbusRequest.Interceptor
    
    @_documentation(visibility: internal)
    public var enabled = true
    
    @_documentation(visibility: internal)
    public var network: String { "molocosdk" }
    
    @_documentation(visibility: internal)
    public var controllerType: AdController.Type { NimbusMolocoAdController.self }
    
    /// Creates a Moloco extension.
    ///
    /// - Parameter appKey: Moloco App Key. If provided, Nimbus initializes the Moloco SDK automatically.
    ///
    /// ##### Usage
    /// ```swift
    /// Nimbus.initialize(publisher: "<publisher>", apiKey: "<apiKey>") {
    ///     MolocoExtension() // Enables Moloco rendering
    /// }
    /// ```
    public init(appKey: String? = nil) {
        self.interceptor = NimbusMolocoRequestInterceptor()
        
        guard let appKey, !Moloco.shared.isInitialized else {
            Nimbus.Log.lifecycle.debug("Skipping Moloco SDK initialization, appKey was not provided or SDK is already initialized")
            return
        }
        
        MolocoSDK.Moloco.shared.initialize(params: .init(appKey: appKey, mediation: Nimbus.sdkName)) { done, error in
            if let error {
                Nimbus.Log.lifecycle.error("Moloco SDK initialization failed: \(error)")
            } else {
                Nimbus.Log.lifecycle.debug("Moloco SDK initialization completed")
            }
        }
    }
    
    @_documentation(visibility: internal)
    public func coppaDidChange(coppa: Bool) {
        MolocoRequestBridge.set(coppa: coppa)
    }
}

public extension MolocoExtension {
    /// The UIView returned from this method should have all of the data set from the native ad
    /// on children views such as the call to action, image data, title, etc.
    /// The view returned from this method should NOT be attached to the container passed in as
    /// it will be attached at a later time during the rendering process.
    ///
    /// Nimbus uses MolocoNativeAd.delegate and fires events (impression, click) as NimbusEvent. You may
    /// listen set AdController.delegate and listen to didReceiveNimbusEvent() and didReceiveNimbusError() instead.
    ///
    /// - Parameters:
    ///   - container: The container the layout will be attached to
    ///   - assets: Moloco native ad assets
    ///
    /// - Returns: Your custom UIView. DO NOT attach the view to the hierarchy yourself.
    ///
    @MainActor
    @preconcurrency
    static var nativeAdViewProvider: ((_ container: UIView, _ assets: MolocoNativeAdAssests) -> MolocoNativeAdViewType)?
}
