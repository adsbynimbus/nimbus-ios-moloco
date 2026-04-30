//
//  NimbusMolocoAdController.swift
//  Nimbus
//  Created on 5/28/25
//  Copyright © 2025 Nimbus Advertising Solutions Inc. All rights reserved.
//

import UIKit
import NimbusKit
import MolocoSDK

final class NimbusMolocoAdController: AdController,
                                      @preconcurrency MolocoBannerDelegate,
                                      @preconcurrency MolocoInterstitialDelegate,
                                      @preconcurrency MolocoNativeAdDelegate,
                                      @preconcurrency MolocoRewardedDelegate {
    
    // MARK: - Properties
    
    // MARK: - Moloco ad types
    var bannerAd: MolocoBannerAdView?
    var nativeAd: MolocoNativeAd?
    var interstitialAd: MolocoInterstitial?
    var rewardedAd: MolocoRewardedInterstitial?
    
    override class func setup(
        response: NimbusResponse,
        container: UIView,
        adPresentingViewController: UIViewController?
    ) -> AdController {
        let adController = Self.init(
            response: response,
            isBlocking: false,
            isRewarded: false,
            container: container,
            adPresentingViewController: adPresentingViewController
        )
        
        return adController
    }
    
    override class func setupBlocking(
        response: NimbusResponse,
        isRewarded: Bool,
        adPresentingViewController: UIViewController
    ) -> AdController {
        let adController = Self.init(
            response: response,
            isBlocking: true,
            isRewarded: isRewarded,
            container: nil,
            adPresentingViewController: adPresentingViewController
        )
        
        return adController
    }
    
    @MainActor
    override func load() {
        guard let placementId = response.bid.ext?.omp?.buyerPlacementId else {
            sendNimbusError(.moloco(reason: .invalidState, stage: .render, detail: "Ad unit id is missing"))
            return
        }
        
        let adParams = MolocoCreateAdParams(adUnit: placementId, mediation: Nimbus.sdkName)
        
        switch adRenderType {
        case .banner:
            guard let adPresentingViewController else {
                sendNimbusError(.moloco(
                    reason: .invalidState,
                    stage: .render,
                    detail: "adPresentingViewController was released before the ad was loaded")
                )
                return
            }
            
            bannerAd = Moloco.shared.createBanner(params: adParams, viewController: adPresentingViewController)
            guard let bannerAd else {
                sendNimbusError(.moloco(stage: .render, detail: "Moloco.shared.createBanner returned nil"))
                return
            }
            bannerAd.delegate = self
            bannerAd.load(bidResponse: response.bid.adm)
        case .interstitial:
            interstitialAd = Moloco.shared.createInterstitial(params: adParams)
            guard let interstitialAd else {
                sendNimbusError(.moloco(stage: .render, detail: "Moloco.shared.createInterstitial returned nil"))
                return
            }
            interstitialAd.interstitialDelegate = self
            interstitialAd.load(bidResponse: response.bid.adm)
        case .native:
            nativeAd = Moloco.shared.createNativeAd(params: adParams)
            guard let nativeAd else {
                sendNimbusError(.moloco(stage: .render, detail: "Moloco.shared.createNative returned nil"))
                return
            }
            nativeAd.delegate = self
            nativeAd.load(bidResponse: response.bid.adm)
        case .rewarded:
            rewardedAd = Moloco.shared.createRewarded(params: adParams)
            guard let rewardedAd else {
                sendNimbusError(.moloco(stage: .render, detail: "Moloco.shared.createRewarded returned nil"))
                return
            }
            rewardedAd.rewardedDelegate = self
            rewardedAd.load(bidResponse: response.bid.adm)
        @unknown default:
            sendNimbusError(.moloco(reason: .unsupported, stage: .render, detail: "adRenderType: \(adRenderType.rawValue)"))
        }
    }
    
    @MainActor
    func presentIfNeeded() {
        guard started, adState == .ready else { return }
        
        adState = .resumed
        
        if let bannerAd {
            adView.addSubview(bannerAd)
        } else if let nativeAd = nativeAd {
            guard let nativeAdViewProvider = MolocoExtension.nativeAdViewProvider else {
                sendNimbusError(.moloco(reason: .misconfiguration, stage: .render, detail: "MolocoExtension.nativeAdViewProvider must be set to render native ads"))
                return
            }
            
            guard let assets = nativeAd.assets else {
                sendNimbusError(.moloco(reason: .invalidState, stage: .render, detail: "NativeAd assets are missing"))
                return
            }
            
            let nativeView = nativeAdViewProvider(adView, assets)
            nativeView.translatesAutoresizingMaskIntoConstraints = false
            
            adView.addSubview(nativeView)
            
            NSLayoutConstraint.activate([
                nativeView.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
                nativeView.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
                nativeView.topAnchor.constraint(equalTo: adView.topAnchor),
                nativeView.bottomAnchor.constraint(equalTo: adView.bottomAnchor)
            ])
            
            nativeAd.handleImpression()
            sendNimbusEvent(.impression)
            
            nativeView.clickableViews.forEach {
                $0.isUserInteractionEnabled = true
                
                if let button = $0 as? UIButton {
                    button.addTarget(self, action:  #selector(onNativeAdClick), for: .touchUpInside)
                } else {
                    let tap = UITapGestureRecognizer(target: self, action: #selector(onNativeAdClick))
                    
                    /*
                     Delegate is implemented to allow simulatenously recognize the clicks
                     as Moloco's VideoView has other gesture recognizers to pause/unpause video.
                     (see UIGestureRecognizerDelegate extension)
                     */
                    tap.delegate = self
                    tap.cancelsTouchesInView = false
                    
                    $0.addGestureRecognizer(tap)
                }
            }
            
        } else if let interstitialAd, interstitialAd.isReady, let adPresentingViewController {
            interstitialAd.show(from: adPresentingViewController, muted: volume == 0)
        } else if let rewardedAd = rewardedAd, rewardedAd.isReady, let adPresentingViewController {
            rewardedAd.show(from: adPresentingViewController)
        } else {
            sendNimbusError(.moloco(reason: .invalidState, stage: .render, detail: "Ad \(adRenderType) is invalid and could not be presented."))
        }
    }
    
    override func onStart() {
        Task { @MainActor in
            presentIfNeeded()
        }
    }
    
    override func onDestroy() {
        bannerAd?.destroy()
        bannerAd = nil
        
        interstitialAd?.destroy()
        interstitialAd = nil
        
        nativeAd?.destroy()
        nativeAd = nil
        
        rewardedAd?.destroy()
        rewardedAd = nil
    }
    
    @objc private func onNativeAdClick() {
        nativeAd?.handleClick()
        sendNimbusEvent(.clicked)
    }
    
    // MARK: - BaseAdDelegate
    
    func didLoad(ad: any MolocoAd) {
        Task { @MainActor in
            adState = .ready
            sendNimbusEvent(.loaded)
            presentIfNeeded()
        }
    }
    
    func failToLoad(ad: any MolocoAd, with error: (any Error)?) {
        sendNimbusError(.moloco(stage: .render, detail: error?.localizedDescription))
    }
    
    func didShow(ad: any MolocoAd) {
        sendNimbusEvent(.impression)
    }
    
    func failToShow(ad: any MolocoAd, with error: (any Error)?) {
        sendNimbusError(.moloco(stage: .render, detail: error?.localizedDescription))
    }
    
    func didHide(ad: any MolocoAd) {
        destroy()
    }
    
    func didClick(on ad: any MolocoAd) {
        sendNimbusEvent(.clicked)
    }
    
    // MARK: - Native delegate
    
    func didHandleClick(ad: any MolocoAd) {
        Nimbus.Log.ad.debug("Handled Moloco Click")
    }
    
    func didHandleImpression(ad: any MolocoAd) {
        Nimbus.Log.ad.debug("Handled Moloco Impression")
    }
    
    // MARK: - Rewarded delegate
    
    func userRewarded(ad: any MolocoAd) {
        sendNimbusEvent(.rewardEarned)
    }
    
    func rewardedVideoStarted(ad: any MolocoAd) {
        Nimbus.Log.ad.debug("Moloco Video Started")
    }
    
    func rewardedVideoCompleted(ad: any MolocoAd) {
        Nimbus.Log.ad.debug("Moloco Video Completed")
    }
}

extension NimbusMolocoAdController: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}

// Internal: Do NOT implement delegate conformance as separate extensions as the methods won't not be found in runtime when built as a static library
