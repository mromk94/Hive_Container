# OMK Container Dev Bootstrap — Windows Notes

These notes complement `scripts/dev-bootstrap.sh` for Windows developers.

## Core Requirements

- **Windows 10/11**, WSL2 recommended for Node/Flutter tooling.
- **Git**: https://git-scm.com/download/win
- **Node.js LTS (20.x)**: https://nodejs.org/en/download
- **Flutter SDK**: https://docs.flutter.dev/get-started/install/windows
- **Android Studio + SDK**: install via Android Studio installer.

## Suggested Setup Steps

1. Install **Node.js 20.x LTS**.
2. Install **Flutter** and add `flutter\bin` to your PATH.
3. Install **Android Studio**:
   - Enable Android SDK, platform-tools, and at least one Android 34 system image.
4. Open a **Developer PowerShell** or **WSL2** shell.

### Clone and install

```powershell
git clone https://github.com/mromk94/Hive_Container.git
cd Hive_Container\omk-container
npm install
cd mobile
flutter pub get
```

### Run tests

```powershell
cd ..\mobile
flutter test

cd ..\hive-bridge
npm test
npm run dev
```

### Emulator

Use Android Studio AVD Manager to create an emulator (e.g., `omk-android-34`). Then:

```powershell
flutter devices
flutter run -d emulator-5554
```

## TFLite Tooling

For early experiments, prefer WSL2 with Python 3.11+:

```bash
python -m venv .venv
source .venv/bin/activate
pip install tensorflow==2.17.0 tensorflow-model-optimization
```

Later, dedicated TFLite runtimes will be wired through Kotlin plugins and Flutter platform channels.
