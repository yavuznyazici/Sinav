# iTEP Upper Intermediate Trainer (Flutter)

A Turkish-language, offline-first English practice app with 250 multiple-choice questions. The question mix is tailored to the uploaded iTEP score report: grammar (especially pronouns, verb forms, sentence structure and quantity), vocabulary (word forms and academic vocabulary), and reading (main idea, inference and synthesis).

## Features
- 250 B2 / Upper Intermediate practice questions with four options.
- Immediate right/wrong feedback, Turkish translation and Turkish explanation.
- Home screen with three progress bars.
- Wrong-answer review grouped by first, second and third attempt.
- Statistics screen with four summary metrics and five charts.
- Local persistence using SharedPreferences; no account or internet connection required after installation.
- GitHub Actions workflow to build a release APK.

## Build an APK on GitHub (phone or computer)
1. Create a new GitHub repository.
2. Upload the **contents** of this folder to the repository root (not the containing folder itself).
3. Open the repository's **Actions** tab and enable workflows if GitHub asks.
4. Run **Build Android APK** with **Run workflow**, or push a commit to `main` / `master`.
5. When the workflow finishes successfully, open its run and download the artifact named `itep-upper-intermediate-apk`.
6. Extract the artifact ZIP; it contains `app-release.apk`. Transfer it to the Android phone and install it. Android may ask you to allow installation from that source.

## Local build
Install Flutter (stable), then run:

```bash
flutter create --platforms=android --org com.yavuznailyazici .
flutter pub get
flutter run
flutter build apk --release
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`.

## Notes
- Progress and answers are stored on the device. Clearing app data or uninstalling may remove them.
- The 250 questions are original practice questions, not official iTEP questions.
- Listening, speaking and free-form writing are not directly tested in this multiple-choice version.
