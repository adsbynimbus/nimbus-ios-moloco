//
//  MolocoAdControllerTests.swift
//  NimbusMolocoKitTests
//  Created on 10/26/26
//  Copyright © 2026 Nimbus Advertising Solutions Inc. All rights reserved.
//

import Testing
@testable import NimbusMolocoKit
@testable import NimbusKit
import UIKit
import MolocoSDK

private let adUnit = "test-ad-unit"

/// Moloco's interstitial, rewarded and native ads are protocols, so these tests hand the adapter mock ads.
/// No banner tests: there is no way to get a `MolocoBannerAdView` in a unit test.
/// - `Moloco.shared.createMolocoBanner` returns nil until the SDK is initialized, which needs a real
///   app key and network access.
/// - The class has no public initializer and isn't `open`, so it can't be created or subclassed. Its
///   Objective-C `initWithFrame:` traps as an unimplemented initializer and `initWithCoder:` calls fatalError.
/// Banners use the same delegate methods tested here through the other formats; only setting the banner's
/// delegate and adding it to the ad view go untested.
///
/// Moloco delivers its callbacks on the main thread, where the adapter's `runOnMainActor` runs them
/// right away, so the tests fire callbacks from the main actor and check events synchronously.
@Suite("Moloco AdController tests")
@MainActor
struct MolocoAdControllerTests {

    // MARK: - Native

    @Test func nativeAdEventsGetFired() throws {
        let (adController, delegate) = makeAdController(.native)

        let native = MockNativeAd()
        adController.buildNativeAd(native)
        #expect(adController.nativeAd === native)
        #expect(adController.bannerAd == nil)
        #expect(adController.interstitialAd == nil)
        #expect(adController.rewardedAd == nil)

        let moloco = try #require(native.delegate, "native delegate not wired")
        #expect(moloco === adController)

        let nativeView = MockNativeAdView()
        var providedAssets: (any MolocoNativeAdAssests)?
        MolocoExtension.nativeAdViewProvider = { _, assets in
            providedAssets = assets
            return nativeView
        }
        defer { MolocoExtension.nativeAdViewProvider = nil }

        moloco.didLoad(ad: native)
        #expect(delegate.events == [.loaded])
        #expect(adController.adView.subviews.isEmpty)

        // Moloco native impressions are reported by the adapter as soon as the ad is rendered
        adController.start()
        #expect(adController.adView.subviews.first === nativeView)
        #expect(providedAssets === native.assets)
        #expect(!nativeView.translatesAutoresizingMaskIntoConstraints)
        #expect(native.handleImpressionCount == 1)
        #expect(delegate.events == [.loaded, .impression])

        // Clickable views are wired by the adapter: buttons get a target, other views a tap recognizer
        #expect(nativeView.ctaButton.isUserInteractionEnabled)
        #expect(nativeView.mediaView.isUserInteractionEnabled)
        #expect(nativeView.mediaView.gestureRecognizers?.isEmpty == false)

        #expect(nativeView.ctaButton.allTargets.contains { ($0.base as AnyObject) === adController })
        tap(nativeView.ctaButton)
        #expect(native.handleClickCount == 1)
        #expect(delegate.events == [.loaded, .impression, .clicked])
        #expect(delegate.lastError == nil)
    }

    @Test func nativeAdWithoutViewProviderGetsDestroyed() throws {
        let (adController, delegate) = makeAdController(.native)
        let native = MockNativeAd()
        adController.buildNativeAd(native)
        let moloco = try #require(native.delegate, "native delegate not wired")
        MolocoExtension.nativeAdViewProvider = nil

        moloco.didLoad(ad: native)
        #expect(delegate.events.contains(.loaded))
        adController.start()

        #expect(delegate.lastError?.reason == .configuration)
        #expect(native.handleImpressionCount == 0)
        #expect(delegate.events.last == .destroyed)
    }

    @Test func nativeAdWithoutAssetsGetsDestroyed() throws {
        let (adController, delegate) = makeAdController(.native)
        let native = MockNativeAd()
        native.assets = nil
        adController.buildNativeAd(native)
        let moloco = try #require(native.delegate, "native delegate not wired")

        MolocoExtension.nativeAdViewProvider = { _, _ in MockNativeAdView() }
        defer { MolocoExtension.nativeAdViewProvider = nil }

        moloco.didLoad(ad: native)
        #expect(delegate.events.contains(.loaded))
        adController.start()

        #expect(delegate.lastError?.detail == "NativeAd assets are missing")
        #expect(!delegate.events.contains(.impression))
        #expect(delegate.events.last == .destroyed)
    }

    // MARK: - Interstitial

    @Test func interstitialAdEventsGetFired() throws {
        let (adController, delegate) = makeAdController(.interstitial)

        let interstitial = MockInterstitialAd()
        adController.buildInterstitialAd(interstitial)
        #expect(adController.interstitialAd === interstitial)
        #expect(adController.bannerAd == nil)
        #expect(adController.nativeAd == nil)
        #expect(adController.rewardedAd == nil)

        let moloco = try #require(interstitial.interstitialDelegate, "interstitial delegate not wired")
        #expect(moloco === adController)

        moloco.didLoad(ad: interstitial)
        #expect(delegate.events == [.loaded])
        #expect(interstitial.presentedFrom == nil)

        adController.volume = 0
        adController.start()
        #expect(delegate.lastError == nil)
        #expect(interstitial.showCount == 1)
        #expect(interstitial.presentedFrom === presenter)
        #expect(interstitial.muted == true)

        moloco.didShow(ad: interstitial)
        #expect(delegate.events == [.loaded, .impression])

        moloco.didClick(on: interstitial)
        #expect(delegate.events == [.loaded, .impression, .clicked])
        #expect(delegate.lastError == nil)

        moloco.didHide(ad: interstitial)
        #expect(delegate.events.last == .destroyed)
        #expect(delegate.lastError == nil)
        #expect(!delegate.events.contains(.rewardEarned))
        #expect(interstitial.destroyCount == 1)
        #expect(adController.interstitialAd == nil)
    }

    @Test func interstitialThatIsNotReadyIsNotPresented() throws {
        let (adController, delegate) = makeAdController(.interstitial)
        let interstitial = MockInterstitialAd()
        interstitial.isReady = false
        adController.buildInterstitialAd(interstitial)
        let moloco = try #require(interstitial.interstitialDelegate, "interstitial delegate not wired")

        moloco.didLoad(ad: interstitial)
        #expect(delegate.events.contains(.loaded))
        adController.start()

        #expect(interstitial.showCount == 0)
        #expect(delegate.lastError?.reason == .invalidState)
        #expect(delegate.events.last == .destroyed)
    }

    @Test func interstitialAdGetsDestroyedOnLoadError() throws {
        let (adController, delegate) = makeAdController(.interstitial)
        let interstitial = MockInterstitialAd()
        adController.buildInterstitialAd(interstitial)
        let moloco = try #require(interstitial.interstitialDelegate, "interstitial delegate not wired")

        moloco.failToLoad(ad: interstitial, with: molocoError)

        expectMolocoError(delegate)
        #expect(!delegate.events.contains(.loaded))
        #expect(delegate.events.last == .destroyed)
    }

    @Test func interstitialAdGetsDestroyedOnShowError() throws {
        let (adController, delegate) = makeAdController(.interstitial)
        let interstitial = MockInterstitialAd()
        adController.buildInterstitialAd(interstitial)
        let moloco = try #require(interstitial.interstitialDelegate, "interstitial delegate not wired")

        moloco.didLoad(ad: interstitial)
        #expect(delegate.events.contains(.loaded))
        adController.start()
        moloco.failToShow(ad: interstitial, with: molocoError)

        expectMolocoError(delegate)
        #expect(delegate.events.last == .destroyed)
    }

    // MARK: - Rewarded

    @Test func rewardedAdEventsGetFired() throws {
        let (adController, delegate) = makeAdController(.rewarded)

        let rewarded = MockRewardedAd()
        adController.buildRewardedAd(rewarded)
        #expect(adController.rewardedAd === rewarded)
        #expect(adController.bannerAd == nil)
        #expect(adController.nativeAd == nil)
        #expect(adController.interstitialAd == nil)

        let moloco = try #require(rewarded.rewardedDelegate, "rewarded delegate not wired")
        #expect(moloco === adController)

        moloco.didLoad(ad: rewarded)
        #expect(delegate.events == [.loaded])

        adController.start()
        #expect(delegate.lastError == nil)
        #expect(rewarded.showCount == 1)
        #expect(rewarded.presentedFrom === presenter)

        moloco.didShow(ad: rewarded)
        #expect(delegate.events == [.loaded, .impression])

        moloco.didClick(on: rewarded)
        #expect(delegate.events == [.loaded, .impression, .clicked])

        moloco.rewardedVideoStarted(ad: rewarded)
        moloco.rewardedVideoCompleted(ad: rewarded)
        #expect(delegate.events == [.loaded, .impression, .clicked, .completed])

        moloco.userRewarded(ad: rewarded)
        #expect(delegate.events == [.loaded, .impression, .clicked, .completed, .rewardEarned])
        #expect(delegate.lastError == nil)

        moloco.didHide(ad: rewarded)
        #expect(delegate.events.last == .destroyed)
        #expect(delegate.lastError == nil)
        #expect(rewarded.destroyCount == 1)
        #expect(adController.rewardedAd == nil)
    }

    @Test func rewardedThatIsNotReadyIsNotPresented() throws {
        let (adController, delegate) = makeAdController(.rewarded)
        let rewarded = MockRewardedAd()
        rewarded.isReady = false
        adController.buildRewardedAd(rewarded)
        let moloco = try #require(rewarded.rewardedDelegate, "rewarded delegate not wired")

        moloco.didLoad(ad: rewarded)
        #expect(delegate.events.contains(.loaded))
        adController.start()

        #expect(rewarded.showCount == 0)
        #expect(delegate.lastError?.reason == .invalidState)
        #expect(delegate.events.last == .destroyed)
    }

    @Test func rewardedAdGetsDestroyedOnLoadError() throws {
        let (adController, delegate) = makeAdController(.rewarded)
        let rewarded = MockRewardedAd()
        adController.buildRewardedAd(rewarded)
        let moloco = try #require(rewarded.rewardedDelegate, "rewarded delegate not wired")

        moloco.failToLoad(ad: rewarded, with: molocoError)

        expectMolocoError(delegate)
        #expect(!delegate.events.contains(.rewardEarned))
        #expect(delegate.events.last == .destroyed)
    }

    @Test func rewardedAdGetsDestroyedOnShowError() throws {
        let (adController, delegate) = makeAdController(.rewarded)
        let rewarded = MockRewardedAd()
        adController.buildRewardedAd(rewarded)
        let moloco = try #require(rewarded.rewardedDelegate, "rewarded delegate not wired")

        moloco.didLoad(ad: rewarded)
        #expect(delegate.events.contains(.loaded))
        adController.start()
        moloco.failToShow(ad: rewarded, with: molocoError)

        expectMolocoError(delegate)
        #expect(!delegate.events.contains(.rewardEarned))
        #expect(delegate.events.last == .destroyed)
    }

    // MARK: - Load validation

    @Test func loadFailsWithoutAdUnit() {
        let adController = MolocoAdController(
            response: NimbusResponse(id: "", bid: .init(mtype: .static, adm: "", price: 0, ext: .init())),
            isBlocking: true,
            isRewarded: false,
            container: container,
            adPresentingViewController: presenter
        )
        let delegate = MockDelegate()
        adController.delegate = delegate

        adController.load()

        #expect(adController.interstitialAd == nil)
        #expect(delegate.lastError?.detail == "Ad unit id is missing")
        #expect(delegate.events.last == .destroyed)
    }

    // MARK: - Helpers

    /// Fresh per test: Swift Testing creates a new suite instance for every @Test.
    private let container = UIView()

    /// AdController holds adPresentingViewController weakly, so it must outlive the test body.
    private let presenter = UIViewController()

    private let molocoError = NSError(
        domain: "com.moloco.test",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Moloco test error"]
    )

    enum Format { case banner, native, interstitial, rewarded }

    private func makeAdController(_ format: Format) -> (MolocoAdController, MockDelegate) {
        let mtype: NimbusResponse.Bid.MarkupType = switch format {
        case .banner, .interstitial: .static
        case .native: .native
        case .rewarded: .video
        }

        let adController = MolocoAdController(
            response: NimbusResponse(id: "", bid: .init(
                mtype: mtype,
                adm: "test-bid-response",
                price: 0,
                ext: .init(omp: .init(buyer: "moloco", buyerPlacementId: adUnit)),
                w: 320,
                h: 50
            )),
            isBlocking: format == .interstitial || format == .rewarded,
            isRewarded: format == .rewarded,
            container: container,
            adPresentingViewController: presenter
        )
        let delegate = MockDelegate()
        adController.delegate = delegate
        return (adController, delegate)
    }

    /// Runs a button's touch-up-inside actions directly: `sendActions(for:)` goes through
    /// `UIApplication.shared`, which a test without a host app may not have.
    private func tap(_ button: UIButton) {
        for target in button.allTargets {
            guard let object = target.base as? NSObject else { continue }
            for action in button.actions(forTarget: object, forControlEvent: .touchUpInside) ?? [] {
                _ = object.perform(NSSelectorFromString(action), with: button)
            }
        }
    }

    private func expectMolocoError(_ delegate: MockDelegate, sourceLocation: SourceLocation = #_sourceLocation) {
        let details = delegate.errors.map { $0.detail ?? "nil" }
        #expect(delegate.errors.count == 1, "errors received: \(details)", sourceLocation: sourceLocation)

        guard let error = delegate.errors.first else { return }
        #expect(error.domain == NimbusError.Domain(rawValue: "moloco"), sourceLocation: sourceLocation)
        #expect(error.detail == "Moloco test error", sourceLocation: sourceLocation)
    }
}

// MARK: - Mocks

class MockDelegate: AdController.Delegate {
    var events: [AdEvent] = []
    var errors: [NimbusError] = []
    var lastError: NimbusError? { errors.last }

    func didReceiveNimbusEvent(event: NimbusKit.AdEvent) {
        events.append(event)
    }

    func didReceiveNimbusError(error: NimbusKit.NimbusError) {
        errors.append(error)
    }
}

final class MockNativeAdView: UIView, MolocoNativeAdViewType {
    let ctaButton = UIButton()
    let mediaView = UIView()

    var clickableViews: [UIView] { [ctaButton, mediaView] }
}

final class MockNativeAssets: NSObject, MolocoNativeAdAssests {
    var appIcon: UIImage? { nil }
    var mainImage: UIImage? { nil }
    var title: String { "Title" }
    // `description` comes from NSObject
    var sponsorText: String { "Sponsored" }
    var ctaTitle: String { "Install" }
    var rating: Double { 4.5 }
    var videoView: UIView? { nil }
}

final class MockNativeAd: NSObject, MolocoNativeAd {
    weak var delegate: (any MolocoNativeAdDelegate)?
    var assets: (any MolocoNativeAdAssests)? = MockNativeAssets()
    var isReady = true

    private(set) var handleClickCount = 0
    private(set) var handleImpressionCount = 0
    private(set) var destroyCount = 0

    @MainActor func load(bidResponse: String) {}
    func destroy() { destroyCount += 1 }
    func handleClick() { handleClickCount += 1 }
    func handleImpression() { handleImpressionCount += 1 }
}

/// Records presentation instead of showing anything.
/// `@objcMembers`: the Moloco protocols are `@objc`, and members inherited by the conforming
/// subclasses are only exposed to Objective-C when the base class declares them so.
@objcMembers
class MockFullscreenAd: NSObject {
    var isReady = true
    var fullscreenViewController: UIViewController? { nil }

    private(set) var showCount = 0
    private(set) weak var presentedFrom: UIViewController?
    private(set) var muted: Bool?
    private(set) var destroyCount = 0

    @MainActor func load(bidResponse: String) {}
    func destroy() { destroyCount += 1 }

    @MainActor func show(from viewController: UIViewController) {
        showCount += 1
        presentedFrom = viewController
    }

    @MainActor func show(from viewController: UIViewController, muted: Bool) {
        show(from: viewController)
        self.muted = muted
    }
}

final class MockInterstitialAd: MockFullscreenAd, MolocoInterstitial {
    weak var interstitialDelegate: (any MolocoInterstitialDelegate)?
}

final class MockRewardedAd: MockFullscreenAd, MolocoRewardedInterstitial {
    weak var rewardedDelegate: (any MolocoRewardedDelegate)?
}
