//
//  NimbusError+Moloco.swift
//  NimbusMolocoKit
//
//  Created on 2/23/26.
//  Copyright © 2026 Nimbus Advertising Solutions Inc. All rights reserved.
//

import NimbusKit

extension NimbusError.Domain {
    static let moloco = Self(rawValue: "moloco")
}

extension NimbusError {
    static func moloco(reason: Reason = .failure, stage: Stage, detail: String? = nil) -> NimbusError {
        NimbusError(reason: reason, domain: .moloco, stage: stage, detail: detail)
    }
}
