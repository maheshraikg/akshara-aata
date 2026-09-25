# ಅಕ್ಷರ ಆಟ · Akshara Aata (Flutter)

A Flutter app that teaches young children (ages 3–8) the Kannada varnamala. It is built for Google Play's Families program: no accounts, and child-safe AdMob ads only on menu screens.

## What's inside

| Area | Details |
| --- | --- |
| Letters | All 49: 13 ಸ್ವರಗಳು, 2 ಯೋಗವಾಹಗಳು, 34 ವ್ಯಂಜನಗಳು grouped by ವರ್ಗ |
| Letter cards | Big letter with sound, a picture word (ಆ → ಆನೆ 🐘), English hint, swipe between letters |
| Kagunita | Any consonant with all 15 vowel signs, plus "hear all" |
| Numbers | ೦–೧೦ with number words and counting |
| Tracing | Finger tracing on copybook lines, checked for coverage and for staying inside the letter |
| Games | Listen & find, first letter, memory pairs, balloon pop, what comes next, kagunita builder, counting |
| Rewards | Stars, 20 stickers, progress bar |
| Voice | 586 Kannada recordings built into the app (every letter, picture word, number and kagunita form), so sound works offline on any phone. The phone's text-to-speech is only a fallback |
| Parents | Settings behind a sum: sound, speed, English hints, reset |
| Ads | AdMob banner on menu screens, a full-screen ad after every 3rd finished game. None while learning, tracing or playing |

Code layout: `lib/ads.dart` (AdMob), `lib/audio.dart` (built-in recordings, speech fallback, sound effects), `lib/data.dart` (content), `lib/state.dart` (saved progress), `lib/widgets.dart` (toy-style UI parts), `lib/screens/` (one file per area).

## Run it

```bash
flutter pub get
flutter run            # on a connected phone or emulator
flutter test
```

## Build for the Play Store

### 1. Create your upload key (once, keep it safe)

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload
```

Back up the `.jks` file and its passwords. If you lose them you can't ship updates without asking Google to reset the key.

### 2a. Build on GitHub (no Android Studio needed)

The workflow `.github/workflows/akshara-aata-android.yml` builds the app every time `akshara_aata/` changes, or when you run it from the Actions tab. To sign the build for Play, add these repository secrets (Settings → Secrets and variables → Actions):

| Secret | Value |
| --- | --- |
| `AKSHARA_KEYSTORE_BASE64` | output of `base64 -w0 upload-keystore.jks` |
| `AKSHARA_KEYSTORE_PASSWORD` | keystore password |
| `AKSHARA_KEY_ALIAS` | `upload` |
| `AKSHARA_KEY_PASSWORD` | key password |

Download `app-release.aab` from the run's **akshara-aata-release** artifact.

### 2b. Or build on your computer

Put the keystore at `android/app/upload-keystore.jks` and create `android/key.properties`:

```properties
storeFile=upload-keystore.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

Then run `flutter build appbundle --release`. Both files are git-ignored.

### 3. AdMob

1. In [AdMob](https://admob.google.com) add an Android app, then create two ad units: a **Banner** and an **Interstitial**.
2. In the app's settings, open **Blocking controls → Content** and keep the maximum ad content rating at **G**. Under **App settings → Child-directed treatment**, choose to treat all requests as child-directed.
3. Add these repository secrets (same place as the signing secrets):

| Secret | Value (from AdMob) |
| --- | --- |
| `ADMOB_APP_ID` | app ID, `ca-app-pub-XXXX~YYYY` |
| `ADMOB_BANNER_ID` | banner unit ID, `ca-app-pub-XXXX/ZZZZ` |
| `ADMOB_INTERSTITIAL_ID` | interstitial unit ID |

Without them the build uses Google's test IDs and shows "Test Ad" banners. That is the right setup while you test. Never tap your own real ads, because AdMob can suspend the account for it.

Building on your computer instead: `ADMOB_APP_ID=ca-app-pub-...~... flutter build appbundle --release --dart-define=ADMOB_BANNER_ID=... --dart-define=ADMOB_INTERSTITIAL_ID=...`

What the code does for the Families policy:
- every request uses child age treatment, G-rated content only and non-personalized ads (`lib/ads.dart`)
- the advertising ID permission is removed from the manifest
- ads appear only on menu and result screens, never during learning, tracing or a game

After the app is live, add an `app-ads.txt` file to your developer website, as AdMob asks.

### 4. Upload

1. Create the app in [Play Console](https://play.google.com/console). The package name is `com.aksharaaata.kannada`. To change it, edit `applicationId` in `android/app/build.gradle.kts` before the first upload. It can't change afterwards.
2. Use the text in `store/listing.md` for the store listing and `store/feature-graphic.png` as the feature graphic. Take 2–8 phone screenshots from the app.
3. Host `store/privacy-policy.md` somewhere public (for example GitHub Pages) and paste its URL. Play requires a privacy policy for apps aimed at children.
4. App content: target audience **ages 5 and under** and **6–8**. Ads: **Yes**. In the Families section, confirm the app uses only Families self-certified ad SDKs (AdMob is one).
   Data safety: the AdMob SDK collects **Device or other IDs** (app set ID) and **App info and performance** (crash logs, diagnostics) for **Advertising** and **Fraud prevention**. That data is shared with Google, encrypted in transit, and not optional. Check Google's current [AdMob data disclosure](https://developers.google.com/admob/android/privacy/play-data-disclosure) when you fill this in.
5. Upload the `.aab` to Internal testing first, try it on a phone, then promote it to Production.

For every update, raise the number after `+` in `pubspec.yaml` (`version: 1.0.1+2`).

## Built-in sounds

`assets/audio/` holds one small `.ogg` file for everything the app says. The file name is the text's Unicode code points (ಕಾ → `c95_cbe.ogg`), and `assets/audio/recording-list.csv` lists every file with its Kannada text.

The current files were made with the open-source espeak-ng Kannada voice by `dart run tool/generate_audio.dart` (needs `espeak-ng` and `ffmpeg`). The pronunciation is correct but the voice sounds robotic.

**For a friendlier human voice:** have a clear Kannada speaker record the lines in `recording-list.csv`. Save each as `.ogg` with the exact file name from the list and copy it over the old one. Any file you don't replace keeps the generated voice. The generator only writes files that are missing, unless you pass `--all`. To convert a phone recording: `ffmpeg -i ka.m4a -ac 1 -ar 22050 -c:a libvorbis -q:a 4 c95.ogg`.

## Content fixes

Each letter is one line in `lib/data.dart`:

```dart
Letter('ಆ', 'aa', Group.swara, '', 'ಆನೆ', 'aane', '🐘', 'Elephant'),
```

Add `start: false` when the word doesn't begin with the letter (like ಳ in ಬಾಳೆಹಣ್ಣು), so the first-letter game skips it.

Font: Baloo Tamma 2, SIL Open Font License (`assets/fonts/OFL.txt`).
