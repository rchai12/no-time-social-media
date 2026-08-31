# iOS Platform Specifics — No Time Media

## Minimum iOS Version

**iOS 16.0** — Required for:
- `PhotoKit` modern API used by `photo_manager`
- On-device ML Kit models
- Swift concurrency (used internally by plugins)

## Required Permissions (Info.plist)

```xml
<!-- ios/Runner/Info.plist -->

<!-- Photo library access -->
<key>NSPhotoLibraryUsageDescription</key>
<string>No Time Media needs access to your photos to find your best shots for social media.</string>

<!-- Required for photo_manager on iOS 14+ -->
<key>NSPhotoLibraryAddUsageDescription</key>
<string>No Time Media saves post thumbnails to your photo library.</string>
```

Note: `photo_manager` on iOS uses `PHPhotoLibrary`. For iOS 14+, the user can grant limited photo access. Handle `AuthorizationStatus.limited` by showing a prompt to "allow full access" in settings, but the app must still function with limited access.

## App Store Requirements

### In-App Subscriptions
- Subscription must include:
  - Clear pricing on the paywall screen
  - Link to Privacy Policy
  - Link to Terms of Use
  - "Restore Purchases" button
- Apple review requires the subscription to function as described
- RevenueCat handles StoreKit integration — no raw StoreKit code needed

### App Privacy Report

In App Store Connect, declare the following data types collected:

| Data Type | Used For | Linked to User | Tracking |
|---|---|---|---|
| Photos or videos | App functionality (photo analysis) | No | No |
| User ID | Account management | Yes | No |
| Purchase history | App functionality (subscription) | Yes | No |

**Photos are processed as thumbnails only — never stored on our servers.** State this clearly in the privacy policy.

### App Review Notes

Include in App Review notes:
- The app requires a working Supabase backend and RevenueCat
- Provide a test account with Pro subscription pre-activated for reviewers
- The free tier allows 3 generations; use the test account to demonstrate Pro

## iOS-Specific Flutter Configuration

### Podfile

Ensure minimum deployment target is set:

```ruby
# ios/Podfile
platform :ios, '16.0'
```

### ML Kit Models

`google_mlkit_image_labeling` and `google_mlkit_face_detection` download model files at runtime on first use (not bundled). Ensure the app is not used offline for the first time.

To bundle models offline (optional future enhancement): use the Firebase iOS SDK's local model option.

### Share Sheet (share_plus on iOS)

On iOS, `share_plus` uses `UIActivityViewController`. When sharing images:
- The image file must exist at a local `file://` path
- Pass the `XFile` with the local path from `AssetEntity.file`
- Instagram appears in the share sheet if installed

### Background Processing

The on-device ML scoring should complete within the app's foreground session. Do not use `BGTaskScheduler` — scoring is fast enough (< 5 seconds for 20 photos) to run synchronously in the UI thread via Isolate.

## Xcode Build Settings

- Bundle ID: `com.notimemedia.app`
- Sign with appropriate provisioning profile (distribution for App Store)
- Enable "Associated Domains" capability if deep links are added in future

## TestFlight

Use TestFlight for beta distribution before App Store submission. Configure via App Store Connect. RevenueCat supports StoreKit testing environment for sandbox purchases.
