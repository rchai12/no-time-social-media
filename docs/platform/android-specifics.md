# Android Platform Specifics — No Time Media

## Minimum Android Version

**API 26 (Android 8.0 Oreo)** — Required for:
- `photo_manager` full functionality
- ML Kit on-device models
- Modern Gradle + Kotlin support

Target SDK: **API 35 (Android 15)**
Compile SDK: **35**

## Required Permissions (AndroidManifest.xml)

```xml
<!-- android/app/src/main/AndroidManifest.xml -->

<!-- Media access: API 33+ (Android 13+) -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"
    android:minSdkVersion="33" />

<!-- Media access: API 26–32 -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />

<!-- Internet access (for Supabase + AI calls) -->
<uses-permission android:name="android.permission.INTERNET" />
```

`photo_manager` handles the conditional permission request automatically. No manual version branching required in Dart code.

## Gradle Configuration

```groovy
// android/app/build.gradle
android {
    compileSdkVersion 35
    defaultConfig {
        applicationId "com.notimemedia.app"
        minSdkVersion 26
        targetSdkVersion 35
        // ...
    }
}
```

## Google Play Billing

RevenueCat handles Google Play Billing Library integration. Ensure:

1. `purchases_flutter` is in `pubspec.yaml`
2. `BILLING` permission is auto-added by the RevenueCat plugin
3. In Google Play Console: create the `no_time_media_pro_monthly` subscription product and link to RevenueCat

### Testing Subscriptions on Android

Use Google Play's "license testing" accounts (set in Play Console) for sandbox purchases. RevenueCat supports Play Store sandbox environment.

## ML Kit on Android

`google_mlkit_image_labeling` and `google_mlkit_face_detection` use Google Play Services for model delivery on Android, or bundled models.

For production, use **bundled models** to avoid dependency on Play Services model availability:

```yaml
# pubspec.yaml
dependencies:
  google_mlkit_image_labeling: ^0.10.0
  # Use the bundled variant for offline reliability:
  # google_mlkit_image_labeling_bundled: ^0.10.0  (if available)
```

Check the ml_kit_flutter package for bundled model availability at implementation time.

## Share Sheet (share_plus on Android)

On Android, `share_plus` uses `Intent.ACTION_SEND`. When sharing images:
- The image must be exposed via a `FileProvider` (handled internally by `share_plus`)
- Instagram appears in the chooser if installed
- On Android 12+, the system share sheet shows a preview of shared content

## ProGuard / R8

Add the following to `android/app/proguard-rules.pro` to prevent ML Kit class stripping:

```
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
```

## App Signing

- Use Play App Signing (Google manages the upload key)
- Generate a local keystore for debug/upload builds
- Store keystore credentials in environment variables, not in source control

```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Reference in `android/key.properties` (add to `.gitignore`).

## Play Store Listing Requirements

### Data Safety Section

Declare in Play Console:
- **Photos and videos:** Collected for app functionality, not shared with third parties, not used for tracking
- **App activity (in-app purchases):** Collected for account management
- **Personal info (user ID):** Collected for account management

### Content Rating

Target rating: **Everyone** — no mature content, no user-generated content shared within the app.

## Background Processing

Same as iOS: on-device ML scoring runs in an `Isolate` (Dart), completing in the foreground. No `WorkManager` usage needed for v1.

## Internal Test Track → Closed Testing → Production

Use Play Console's internal test track for early builds. Move to closed testing for beta, then production rollout (staged: 10% → 50% → 100%).
