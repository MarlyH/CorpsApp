#!/bin/sh

# Fail on error
set -e

# 1. Navigate to the root of the repo
cd "$(dirname "$0")/../.."

# 2. Define Flutter version and path
FLUTTER_VERSION="3.24.5" # Use your specific version here
FLUTTER_SDK_DIR="$HOME/developer/flutter"

# 3. Download Flutter if not already present (caching)
if [ ! -d "$FLUTTER_SDK_DIR" ]; then
    echo "Downloading Flutter SDK..."
    mkdir -p $HOME/developer
    curl -o flutter.zip https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_$FLUTTER_VERSION-stable.zip
    unzip -q flutter.zip -d $HOME/developer
    rm flutter.zip
fi

# 4. Add Flutter to PATH for this session
export PATH="$FLUTTER_SDK_DIR/bin:$PATH"

# 5. Disable analytics to speed up the process
flutter config --no-analytics

# 6. Precache iOS artifacts and get dependencies
echo "Fetching Flutter dependencies..."
flutter precache --ios
flutter pub get

# 7. Install CocoaPods
echo "Installing Pods..."
cd ios
# Xcode Cloud has CocoaPods installed, but we need to link it
pod install