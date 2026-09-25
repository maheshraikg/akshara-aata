# ಅಕ್ಷರ ಆಟ · Akshara Aata (Flutter)

A Flutter app that teaches young children (ages 3–8) the Kannada varnamala. It is built for Google Play: no ads, no accounts, and no internet permission.

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
| Voice | Phone text-to-speech in Kannada, with a Hindi-voice fallback when Kannada isn't installed |
| Parents | Settings behind a sum: sound, speed, English hints, reset |

Code layout: `lib/data.dart` (content), `lib/state.dart` (saved progress), `lib/audio.dart` (speech and sound effects), `lib/widgets.dart` (toy-style UI parts), `lib/screens/` (one file per area).

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

### 3. Upload

1. Create the app in [Play Console](https://play.google.com/console). The package name is `com.aksharaaata.kannada`. To change it, edit `applicationId` in `android/app/build.gradle.kts` before the first upload. It can't change afterwards.
2. Use the text in `store/listing.md` for the store listing and `store/feature-graphic.png` as the feature graphic. Take 2–8 phone screenshots from the app.
3. Host `store/privacy-policy.md` somewhere public (for example GitHub Pages) and paste its URL. Play requires a privacy policy for apps aimed at children.
4. App content: target audience **ages 5 and under** and **6–8**. Ads: **No**. Data safety: **no data collected or shared**.
5. Upload the `.aab` to Internal testing first, try it on a phone, then promote it to Production.

For every update, raise the number after `+` in `pubspec.yaml` (`version: 1.0.1+2`).

## Content fixes

Each letter is one line in `lib/data.dart`:

```dart
Letter('ಆ', 'aa', Group.swara, '', 'ಆನೆ', 'aane', '🐘', 'Elephant'),
```

Add `start: false` when the word doesn't begin with the letter (like ಳ in ಬಾಳೆಹಣ್ಣು), so the first-letter game skips it.

Font: Baloo Tamma 2, SIL Open Font License (`assets/fonts/OFL.txt`).
