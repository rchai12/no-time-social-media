# Phase 7 — App Store & Play Store Submission

**Depends on:** Phase 6 complete.
**Spec references:** `docs/platform/ios-specifics.md`, `docs/platform/android-specifics.md`.

Read both platform docs fully before starting.

This phase prepares the app for submission to the Apple App Store and Google Play Store. It has two kinds of work: **code tasks** (coding agent does these) and **human tasks** (marked 🧑 — the coding agent cannot do these). Human tasks are grouped at the end of each track.

---

## Track A — Platform Identity & Native Config

These are the most critical fixes. Wrong package IDs will cause App Store / Play Store rejection or confusion with other apps.

### A1 — Android: Fix `build.gradle.kts`

**File:** `no_time_media/android/app/build.gradle.kts`

Current values are wrong or use Flutter defaults. Replace the full file contents:

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Load signing config from key.properties (created in Step A3)
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = java.util.Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.notimemedia.app"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias     = keystoreProperties["keyAlias"]     as String
                keyPassword  = keystoreProperties["keyPassword"]  as String
                storeFile    = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    defaultConfig {
        applicationId = "com.notimemedia.app"
        minSdk        = 26
        targetSdk     = 35
        versionCode   = flutter.versionCode
        versionName   = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig   = signingConfigs.getByName("release")
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
```

### A2 — Android: Fix `AndroidManifest.xml`

**File:** `no_time_media/android/app/src/main/AndroidManifest.xml`

Replace the current manifest. Key changes:
- App label: `"No Time Media"` (was `"no_time_media"`)
- Fix media permissions with correct `minSdkVersion` / `maxSdkVersion` attributes
- Add `READ_EXTERNAL_STORAGE` for API 26–32
- Add `INTERNET`
- Remove `READ_MEDIA_VIDEO` (not needed — we only access images)

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Internet for Supabase + AI calls -->
    <uses-permission android:name="android.permission.INTERNET" />

    <!-- Photo access: API 33+ -->
    <uses-permission
        android:name="android.permission.READ_MEDIA_IMAGES"
        android:minSdkVersion="33" />

    <!-- Photo access: API 26–32 -->
    <uses-permission
        android:name="android.permission.READ_EXTERNAL_STORAGE"
        android:maxSdkVersion="32" />

    <application
        android:label="No Time Media"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:roundIcon="@mipmap/ic_launcher_round"
        android:requestLegacyExternalStorage="false">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme" />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>

        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>

    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
</manifest>
```

### A3 — Android: ProGuard rules

**File:** `no_time_media/android/app/proguard-rules.pro`

Create the file (or append if it exists):

```
# ML Kit — prevent R8 from stripping these classes
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }

# Hive
-keep class * extends com.google.flatbuffers.Table { *; }
-keepclassmembers class * {
    @com.google.flatbuffers.Table *;
}

# Supabase / Ktor
-dontwarn org.slf4j.**
-dontwarn okhttp3.**

# RevenueCat
-keep class com.revenuecat.purchases.** { *; }
```

### A4 — Android: Keystore for release signing

**File (create, do not commit):** `no_time_media/android/key.properties`

```
storePassword=<your-keystore-password>
keyPassword=<your-key-password>
keyAlias=upload
storeFile=../../upload-keystore.jks
```

This file **must be in `.gitignore`**. Verify `no_time_media/android/.gitignore` contains:
```
key.properties
**/*.jks
```

🧑 **Human task:** Generate the keystore:
```bash
keytool -genkey -v -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Store the keystore file at `no_time_media/upload-keystore.jks` (outside the `android/` folder so it's not accidentally committed with ProGuard outputs). Add `upload-keystore.jks` to the root `.gitignore`.

### A5 — iOS: Confirm deployment target is 16.0

**File:** `no_time_media/ios/Podfile`

Ensure the first non-comment line is:
```ruby
platform :ios, '16.0'
```

**File:** `no_time_media/ios/Runner.xcodeproj/project.pbxproj`

Search for `IPHONEOS_DEPLOYMENT_TARGET`. Every occurrence must be `16.0`. If any is `12.0` (the Flutter default), replace it.

There will be multiple occurrences (Debug, Release, Profile). Replace all.

### A6 — iOS: Confirm bundle ID

**File:** `no_time_media/ios/Runner.xcodeproj/project.pbxproj`

Search for `PRODUCT_BUNDLE_IDENTIFIER`. All occurrences must be `com.notimemedia.app`.

If they are `com.notimemedia.noTimeMedia` (Flutter default), replace all.

### A7 — iOS: Confirm `Info.plist` permissions

**File:** `no_time_media/ios/Runner/Info.plist`

Confirm these two keys exist (added in Phase 1–3 fixes). Add if missing:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>No Time Media needs access to your photos to find your best shots for social media.</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>No Time Media saves post thumbnails to your photo library.</string>
```

### A8 — `pubspec.yaml`: version and app metadata

Confirm `pubspec.yaml` has correct values:
```yaml
name: no_time_media
description: "AI-powered social media post generator for Instagram."
publish_to: 'none'

version: 1.0.0+1   # increment build number on each submission
```

`version` format is `<semver>+<build-number>`. `build-number` maps to `versionCode` (Android) and `CFBundleVersion` (iOS).

---

## Track B — Visual Assets

**The coding agent cannot create artwork.** The agent's job in this track is to set up the packages and configuration so that once the human provides the image files, running one command generates all required icon and splash sizes.

### B1 — App icon setup

Add to `pubspec.yaml` dev_dependencies:
```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.14.0
```

Add icon configuration to `pubspec.yaml`:
```yaml
flutter_launcher_icons:
  android: true
  ios: true
  remove_alpha_ios: true          # App Store requires no alpha channel
  image_path: "assets/icon/app_icon.png"
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: "assets/icon/app_icon_foreground.png"
  web:
    generate: false
```

Create the assets directory:
```
assets/
  icon/
    app_icon.png              ← 1024×1024 px, no alpha, solid background
    app_icon_foreground.png   ← 1024×1024 px, subject centred in safe zone (66%)
```

🧑 **Human task:** Create or commission both icon files and place them in `assets/icon/`.

Once files are in place, agent runs:
```bash
dart run flutter_launcher_icons
```

### B2 — Splash screen setup

Add to `pubspec.yaml` dev_dependencies:
```yaml
dev_dependencies:
  flutter_native_splash: ^2.4.0
```

Add splash configuration to `pubspec.yaml`:
```yaml
flutter_native_splash:
  color: "#FFFFFF"
  image: "assets/splash/splash_logo.png"
  color_dark: "#121212"
  image_dark: "assets/splash/splash_logo_dark.png"
  android_12:
    color: "#FFFFFF"
    image: "assets/splash/splash_logo.png"
    color_dark: "#121212"
    image_dark: "assets/splash/splash_logo_dark.png"
  fullscreen: false
```

Create assets directory:
```
assets/
  splash/
    splash_logo.png       ← logo/wordmark, 288×288 px, transparent background
    splash_logo_dark.png  ← same, for dark mode
```

🧑 **Human task:** Create splash logo files.

Once files are in place, agent runs:
```bash
dart run flutter_native_splash:create
```

Add `assets/icon/` and `assets/splash/` to the `flutter.assets` section of `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/icon/
    - assets/splash/
```

---

## Track C — Legal & Compliance

### C1 — Privacy policy screen

**File:** `no_time_media/lib/features/legal/privacy_policy_screen.dart`

Add `webview_flutter: ^4.0.0` to `pubspec.yaml` dependencies.

```dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse('https://notimemedia.app/privacy'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: WebViewWidget(controller: _controller),
    );
  }
}
```

🧑 **Human task:** Host a privacy policy at `https://notimemedia.app/privacy`. The policy must disclose:
- Photo library access (thumbnails analysed on-device and sent to AI)
- Photos are never stored on servers (only 256×256 thumbnails sent to AI for curation, then discarded)
- Account data: email address for auth
- Subscription data: managed via RevenueCat / App Store / Google Play
- No third-party ad tracking

### C2 — Terms of service screen

**File:** `no_time_media/lib/features/legal/terms_screen.dart`

Identical structure to `PrivacyPolicyScreen`, loading `https://notimemedia.app/terms`.

🧑 **Human task:** Host terms at `https://notimemedia.app/terms`.

### C3 — Add routes for legal screens

In `router.dart`, add outside the `ShellRoute`:
```dart
GoRoute(
  path: '/privacy',
  builder: (context, state) => const PrivacyPolicyScreen(),
),
GoRoute(
  path: '/terms',
  builder: (context, state) => const TermsScreen(),
),
```

### C4 — Link legal screens from Settings

In `SettingsScreen`, update the Legal section:
```dart
ListTile(
  title: const Text('Privacy Policy'),
  trailing: const Icon(Icons.open_in_new, size: 16),
  onTap: () => context.push('/privacy'),
),
ListTile(
  title: const Text('Terms of Service'),
  trailing: const Icon(Icons.open_in_new, size: 16),
  onTap: () => context.push('/terms'),
),
```

### C5 — Confirm paywall has App Store required subscription copy

**File:** `no_time_media/lib/features/subscription/paywall_screen.dart`

The following text **must** appear on the paywall screen. App Store review will reject without it:

```dart
const Text(
  'Payment will be charged to your Apple ID / Google Play account at '
  'confirmation of purchase. Subscription automatically renews unless cancelled '
  'at least 24 hours before the end of the current period. You can manage and '
  'cancel your subscription in your account settings.',
  style: TextStyle(fontSize: 11, color: Colors.grey),
  textAlign: TextAlign.center,
),
const SizedBox(height: 8),
Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    TextButton(
      onPressed: () => context.push('/privacy'),
      child: const Text('Privacy Policy', style: TextStyle(fontSize: 11)),
    ),
    const Text('·', style: TextStyle(color: Colors.grey)),
    TextButton(
      onPressed: () => context.push('/terms'),
      child: const Text('Terms of Use', style: TextStyle(fontSize: 11)),
    ),
  ],
),
```

---

## Track D — First-Launch Onboarding

Shown once on first install. Stored in the Hive `prefs` box. After viewing, never shown again.

### D1 — Onboarding seen flag in `PrefsService`

Add to `PrefsService`:
```dart
static const _keyOnboardingSeen = 'onboardingSeen';

static bool get onboardingSeen =>
    (_box.get(_keyOnboardingSeen) as bool?) ?? false;

static Future<void> markOnboardingSeen() =>
    _box.put(_keyOnboardingSeen, true);
```

### D2 — Create `OnboardingScreen`

**File:** `no_time_media/lib/features/onboarding/onboarding_screen.dart`

Three pages, swipeable `PageView` with a dot indicator and a "Next" / "Get Started" button.

**Page 1 — Value prop:**
```
[Illustration: sparkles + phone]
"Your best shot, instantly"
"No Time Media scans your camera roll and finds the photos worth posting — then writes the caption for you."
```

**Page 2 — How it works:**
```
[Illustration: 3-step flow]
"Scan → Curate → Post"
"On-device AI scores your photos. Cloud AI writes Instagram-ready captions. You just tap Share."
```

**Page 3 — Permission request:**
```
[Illustration: photo library icon]
"Allow photo access"
"We scan your recent photos on-device. Your photos never leave your phone without your approval."
[Allow Access]  ← calls PhotoManager.requestPermissionExtend()
```

On "Allow Access":
- Call `PhotoManager.requestPermissionExtend()`
- Regardless of result (allow or deny): mark onboarding seen + navigate to `/scan`
- The scan screen already handles permission-denied state (Phase 6, Step C1)

```dart
onPressed: () async {
  await PhotoManager.requestPermissionExtend();
  await PrefsService.markOnboardingSeen();
  if (context.mounted) context.go('/scan');
},
```

The "Next" button on pages 1 and 2 advances the page. On page 3, the button becomes "Allow Access".

### D3 — Add onboarding to router

```dart
GoRoute(
  path: '/onboarding',
  builder: (context, state) => const OnboardingScreen(),
),
```

Update the router `redirect`:
```dart
redirect: (context, state) {
  final isSignedIn     = Supabase.instance.client.auth.currentUser != null;
  final onboardingSeen = PrefsService.onboardingSeen;
  final location       = state.matchedLocation;

  // First launch: show onboarding before anything else
  if (!onboardingSeen && location != '/onboarding') return '/onboarding';

  // Auth guard
  if (!isSignedIn && location != '/auth' && location != '/onboarding') {
    return '/auth';
  }
  if (isSignedIn && location == '/auth') return '/scan';

  return null;
},
```

---

## Track E — Production Hardening

### E1 — Conditional RevenueCat log level

**File:** `no_time_media/lib/main.dart`

Replace `LogLevel.debug` with a runtime check:
```dart
await Purchases.setLogLevel(kReleaseMode ? LogLevel.warn : LogLevel.debug);
```

Import: `import 'package:flutter/foundation.dart';`

### E2 — Remove all `print()` calls

Search the entire `lib/` directory for bare `print(` calls:
```bash
grep -r "print(" lib/ --include="*.dart"
```

Replace every `print(...)` with `debugPrint(...)`. `debugPrint` is a no-op in release builds. Do not replace `debugPrint` calls (those are already correct).

### E3 — Handle iOS `limited` photo access

**File:** `no_time_media/lib/core/services/photo_service.dart`

`photo_manager` on iOS 14+ can return `PermissionState.limited` (user granted access to selected photos only). The app should still function, not error out.

Update the permission check:
```dart
final status = await PhotoManager.requestPermissionExtend();

// isAuth is true for both authorized AND limited
if (!status.isAuth) {
  throw Exception('Permission denied');
}

// If limited, show a non-blocking hint (handled in PhotoScanScreen)
```

Add a boolean to the thrown exception or return type to signal "limited" so `PhotoScanScreen` can show a gentle banner: `"You've granted limited access. Tap to allow access to all photos."` — banner uses `PhotoManager.presentLimited()` to let the user update their selection.

### E4 — `flutter analyze` zero errors

Run and fix all errors and warnings:
```bash
flutter analyze
```

Warnings are acceptable only for:
- `deprecated_member_use` from third-party packages (not your code)
- `avoid_print` if any `print` calls remain (fix them — see E2)

### E5 — `--dart-define` documentation

Create `no_time_media/.env.example` (committed — no real values):
```
REVENUECAT_KEY=appl_xxxxxxxxxxxxxxxxxxxxxxxxx
```

Update `README.md` (or create one) with the run command:
```bash
# iOS
flutter run --dart-define=REVENUECAT_KEY=appl_xxxxx

# Android
flutter run --dart-define=REVENUECAT_KEY=goog_xxxxx

# Release build (see Track F)
```

---

## Track F — Release Builds

### F1 — iOS release build

```bash
cd no_time_media
flutter build ipa \
  --release \
  --obfuscate \
  --split-debug-info=build/debug-info \
  --dart-define=REVENUECAT_KEY=appl_xxxxx
```

The `.ipa` file is at `build/ios/ipa/no_time_media.ipa`.

🧑 **Human task:** Upload via Xcode Organizer or `xcrun altool` to App Store Connect / TestFlight.

### F2 — Android release build

```bash
cd no_time_media
flutter build appbundle \
  --release \
  --obfuscate \
  --split-debug-info=build/debug-info \
  --dart-define=REVENUECAT_KEY=goog_xxxxx
```

The `.aab` file is at `build/app/outputs/bundle/release/app-release.aab`.

🧑 **Human task:** Upload to Google Play Console → Internal Testing track.

### F3 — Verify `versionCode` increments

Every Play Store upload requires a higher `versionCode`. Every App Store build requires a higher `CFBundleVersion`.

Manage this in `pubspec.yaml` `version` field: `1.0.0+1` where `+1` is the build number. Increment the build number on every submission.

---

## Track G — Human Checklist (non-code)

These cannot be automated. Complete before submission.

### Apple App Store
- [ ] Enrol in Apple Developer Program ($99/year) if not already
- [ ] Create App Store Connect listing for `com.notimemedia.app`
- [ ] Configure in-app subscription product `no_time_media_pro_monthly` at $7.99/month in App Store Connect
- [ ] Link RevenueCat to App Store Connect (API key + shared secret)
- [ ] Prepare screenshots for all required device sizes (6.7", 6.1", 5.5", iPad if needed)
- [ ] Write App Store description (4000 chars max), subtitle (30 chars), keywords (100 chars)
- [ ] Set up privacy nutrition labels in App Store Connect (see `docs/platform/ios-specifics.md`)
- [ ] Host privacy policy at `https://notimemedia.app/privacy`
- [ ] Host terms at `https://notimemedia.app/terms`
- [ ] Create a test account with Pro subscription pre-activated for Apple reviewers
- [ ] Add App Review notes: "Test account: test@example.com / password123 — Pro tier is pre-activated"
- [ ] Upload build to TestFlight, confirm internal testers can install and use the app
- [ ] Submit for App Store review

### Google Play Store
- [ ] Enrol in Google Play Developer program ($25 one-time)
- [ ] Create Play Console app listing for `com.notimemedia.app`
- [ ] Configure subscription product `no_time_media_pro_monthly` in Play Console
- [ ] Link RevenueCat to Google Play (service account JSON key)
- [ ] Set up RevenueCat webhook: `https://<project-ref>.supabase.co/functions/v1/revenuecat-webhook`
- [ ] Prepare feature graphic (1024×500 px) and screenshots
- [ ] Write Play Store description (short: 80 chars, long: 4000 chars)
- [ ] Complete Data Safety section in Play Console (see `docs/platform/android-specifics.md`)
- [ ] Upload `.aab` to internal testing track
- [ ] Promote to closed testing (at least 12 testers for 14 days before production)
- [ ] Submit for Play review

### RevenueCat
- [ ] Create RevenueCat project and configure iOS + Android apps
- [ ] Set `app_user_id` mapping to Supabase user IDs
- [ ] Configure `revenuecat-webhook` URL in RevenueCat dashboard
- [ ] Switch RevenueCat to production mode (sandbox → production)
- [ ] Test sandbox purchase on both platforms end-to-end

---

## File structure after Phase 7

```
no_time_media/
  android/
    app/
      build.gradle.kts          ← updated (A1)
      proguard-rules.pro        ← NEW (A3)
      src/main/AndroidManifest  ← updated (A2)
    key.properties              ← NEW, gitignored (A4)
  ios/
    Podfile                     ← confirmed 16.0 (A5)
    Runner/Info.plist           ← confirmed permissions (A7)
    Runner.xcodeproj/           ← bundle ID + deployment target (A5, A6)
  assets/
    icon/
      app_icon.png              ← 🧑 human provides
      app_icon_foreground.png   ← 🧑 human provides
    splash/
      splash_logo.png           ← 🧑 human provides
      splash_logo_dark.png      ← 🧑 human provides
  lib/
    features/
      onboarding/
        onboarding_screen.dart  ← NEW (D2)
      legal/
        privacy_policy_screen.dart ← NEW (C1)
        terms_screen.dart          ← NEW (C2)
    core/
      services/
        prefs_service.dart      ← updated: onboarding flag (D1)
      router.dart               ← updated: onboarding redirect (D3)
  .env.example                  ← NEW (E5)
  pubspec.yaml                  ← updated: flutter_launcher_icons,
                                   flutter_native_splash, webview_flutter,
                                   version bump (A8, B1, B2, C1)
```

---

## Build sequence

1. Fix `build.gradle.kts`, `AndroidManifest.xml`, ProGuard (A1–A3).
2. Confirm iOS deployment target + bundle ID (A5–A6).
3. Add packages: `flutter_launcher_icons`, `flutter_native_splash`, `webview_flutter`. Run `flutter pub get`.
4. Set up icon and splash config in `pubspec.yaml` (B1, B2). ← Wait for 🧑 to provide artwork, then run commands.
5. Create legal screens + routes (C1–C4).
6. Confirm paywall subscription copy (C5).
7. Create onboarding screen + update router (D1–D3).
8. Apply production hardening (E1–E4).
9. Run `flutter analyze` — zero errors.
10. Run `flutter build ipa --release` and `flutter build appbundle --release` to confirm builds succeed.
11. Hand off to 🧑 for artwork, store listings, and upload.

---

## Verification checklist (code)

- [ ] `flutter analyze` — zero errors, zero `print()` warnings
- [ ] `flutter build ipa --release` succeeds with no errors
- [ ] `flutter build appbundle --release` succeeds with no errors
- [ ] Android `applicationId` is `com.notimemedia.app`
- [ ] iOS bundle ID is `com.notimemedia.app`
- [ ] iOS deployment target is `16.0` throughout `project.pbxproj`
- [ ] Android `minSdk = 26`
- [ ] Onboarding appears on first launch, not on subsequent launches
- [ ] Privacy Policy and Terms accessible from Settings
- [ ] Paywall has App Store subscription legal copy + links to Privacy / Terms
- [ ] RevenueCat uses `LogLevel.warn` in release builds
- [ ] No hardcoded API keys or secrets in committed code
