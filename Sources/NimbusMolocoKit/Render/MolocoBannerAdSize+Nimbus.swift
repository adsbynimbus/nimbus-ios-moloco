//
//  MolocoBannerAdSize+Nimbus.swift
//  NimbusMolocoKit
//  Created on 10/20/26
//  Copyright © 2026 Nimbus Advertising Solutions Inc. All rights reserved.
//

import MolocoSDK
import UIKit
import NimbusKit

extension MolocoBannerAdSize {
    static func from(size: CGSize) -> MolocoBannerAdSize {
        let adSize = AdSize(width: Int(size.width), height: Int(size.height))
        
        return switch adSize {
        case .banner: .standard
        case .mrec: .mrec
        default: .inlineAdaptive(width: Int(size.width))
        }
    }
}
