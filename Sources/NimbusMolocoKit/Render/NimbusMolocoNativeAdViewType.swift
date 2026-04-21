//
//  NimbusMolocoNativeAdViewType.swift
//  Nimbus
//  Created on 7/7/25
//  Copyright © 2025 Nimbus Advertising Solutions Inc. All rights reserved.
//

import UIKit

/**
 A `UIView` subclass capable of presenting Moloco native ads.
 
 Pass an instance conforming to this protocol to `MolocoExtension.nativeAdViewProvider`
 to render a native Moloco ad.
 */
public protocol MolocoNativeAdViewType: UIView {
    /**
     Array of clickable views.
     
     It's recommended to implement this as a computed property, making
     it very easy to return the views you consider clickable, for instance:
     ```swift
     class MyNativeView: UIView, NimbusMolocoNativeAdViewType {
        let mediaView: UIView
        let installButton: UIButton
        
        var clickableViews: [mediaView, installButton]
     }
     ```
     */
    var clickableViews: [UIView] { get }
}
