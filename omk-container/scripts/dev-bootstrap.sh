#!/usr/bin/env bash
set -euo pipefail

# OMK Container Dev Bootstrap (macOS/Linux)
# This script installs core tooling for:
# - Flutter (stable)
# - Node.js (LTS)
# - Android SDK / platform-tools
# - basic emulator setup
# - TFLite tooling placeholder

# NOTE: This is intentionally conservative and prints commands rather than
# forcing global installs. Review before running in your environment.

FLUTTER_VERSION="stable"
NODE_VERSION="20"  # LTS line

log() { printf "[omk-bootstrap] %s\n" "$*"; }

log "This script assumes you have git and a package manager (brew/apt) available."

if command -v brew >/dev/null 2>&1; then
  PKG_MGR="brew"
elif command -v apt-get >/dev/null 2>&1; then
  PKG_MGR="apt-get"
else
  log "No supported package manager detected (brew/apt-get). Install prerequisites manually."
fi

log "Installing Node.js (v$NODE_VERSION.x) via nvm if available..."
if command -v nvm >/dev/null 2>&1; then
  nvm install "$NODE_VERSION"
  nvm use "$NODE_VERSION"
else
  log "nvm not found. Recommended: https://github.com/nvm-sh/nvm"
fi

log "Checking Flutter SDK..."
if ! command -v flutter >/dev/null 2>&1; then
  log "Flutter not found. Recommended manual install: https://docs.flutter.dev/get-started/install"
  log "On macOS (brew): brew install --cask flutter"
fi

log "Android SDK / platform-tools..."
if [ "${PKG_MGR:-}" = "brew" ]; then
  log "brew install --cask android-studio"
  log "brew install android-platform-tools"
elif [ "${PKG_MGR:-}" = "apt-get" ]; then
  log "sudo apt-get install -y openjdk-17-jdk android-sdk adb"
fi

log "To create an emulator (once SDK is installed):"
cat <<'EOF'
  sdkmanager "system-images;android-34;google_apis;x86_64"
  avdmanager create avd -n omk-android-34 -k "system-images;android-34;google_apis;x86_64"
  emulator -avd omk-android-34
EOF

log "TFLite tooling (Python-based). Recommended:" 
cat <<'EOF'
  python -m venv .venv
  source .venv/bin/activate
  pip install --upgrade pip
  pip install tensorflow==2.17.0 tensorflow-model-optimization
EOF

log "To run mobile tests:"
cat <<'EOF'
  cd omk-container/mobile
  flutter pub get
  flutter test
EOF

log "To run Hive Bridge mock server:"
cat <<'EOF'
  cd omk-container
  npm install
  npm run test:hive-bridge
  npm --workspace hive-bridge run dev
EOF

log "Bootstrap script finished. Review the printed commands and run selectively."
