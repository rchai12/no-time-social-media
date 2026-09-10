# No Time Media

AI-powered Instagram post generator. Scans recent photos on-device, scores them with ML Kit, and generates captions via a Supabase Edge Function.

## Run

Pass the RevenueCat public SDK key at build time (never commit the real value).

```bash
# iOS
flutter run --dart-define=REVENUECAT_KEY=appl_xxxxx

# Android
flutter run --dart-define=REVENUECAT_KEY=goog_xxxxx
```

See `.env.example` for the variable name.

## Release builds

```bash
# iOS (macOS only)
flutter build ipa \
  --release \
  --obfuscate \
  --split-debug-info=build/debug-info \
  --dart-define=REVENUECAT_KEY=appl_xxxxx

# Android
flutter build appbundle \
  --release \
  --obfuscate \
  --split-debug-info=build/debug-info \
  --dart-define=REVENUECAT_KEY=goog_xxxxx
```

Android release signing uses `android/key.properties` (gitignored) and `upload-keystore.jks`. Generate the keystore locally — do not commit it.

## Icons and splash

Place artwork, then generate platform assets:

```bash
# assets/icon/app_icon.png (1024×1024) and app_icon_foreground.png
dart run flutter_launcher_icons

# assets/splash/splash_logo.png and splash_logo_dark.png
dart run flutter_native_splash:create
```
