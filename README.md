# NimbusMolocoKit

A Nimbus SDK extension for **Moloco bidding and rendering**. It enriches Nimbus ad requests with Moloco demand and handles ad rendering through the Moloco SDK when it wins the auction.

## Versioning

NimbusMolocoKit **major versions are kept in sync** with the Moloco SDK. For example, NimbusMolocoKit `3.x.x` depends on Moloco SDK `3.x.x`.
 
Minor and patch versions are independent — a NimbusMolocoKit patch release does not necessarily correspond to a Moloco SDK patch release, and vice versa.
 
| NimbusMolocoKit | Moloco SDK |
|---|---|
| 3.x.x | 3.x.x |

## Installation

### Swift Package Manager

#### Xcode Project

1. In Xcode, go to **File → Add Package Dependencies…**
2. Enter the repository URL:
   ```
   https://github.com/adsbynimbus/nimbus-ios-moloco
   ```
3. Set the dependency rule to **Up to Next Major Version** and enter `3.0.0` as the minimum.
4. Click **Add Package** and select the **NimbusMolocoKit** library when prompted.

#### Package.swift

If you're managing dependencies through a `Package.swift` file, add the following:

```swift
dependencies: [
    .package(url: "https://github.com/adsbynimbus/nimbus-ios-moloco", from: "3.0.0")
]
```

Then add the product to your target:

```swift
.product(name: "NimbusMolocoKit", package: "nimbus-ios-moloco")
```

### CocoaPods

Add the following to your `Podfile`:

```ruby
pod 'NimbusMolocoKit'
```

Then run:

```sh
pod install
```

## Usage
 
Navigate to where you call `Nimbus.initialize` and register the `MolocoExtension`:
 
```swift
import NimbusMolocoKit
 
Nimbus.initialize(publisher: "<publisher>", apiKey: "<apiKey>") {
    MolocoExtension(appKey: "<molocoAppKey>")
}
```

If you provide an app key, Nimbus will automatically initialize the Moloco SDK.

That's it — Moloco is now enabled in all upcoming requests.

## Documentation

- [Nimbus iOS SDK Documentation](https://docs.adsbynimbus.com/docs/sdk/ios) — integration guides, configuration, and API reference.
- [DocC API Reference](https://iosdocs.adsbynimbus.com) — auto-generated documentation for the latest release.

## Sample App

See NimbusMolocoKit in action in our public [sample app repository](https://github.com/adsbynimbus/nimbus-ios-sample), which demonstrates end-to-end integration including setup, bid requests, and ad rendering.
