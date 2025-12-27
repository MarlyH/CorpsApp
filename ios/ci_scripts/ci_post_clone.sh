#!/bin/sh
set -e

echo "--- SETTING UP FLUTTER ---"

if [ ! -d "$HOME/flutter" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
fi

export PATH="$PATH:$HOME/flutter/bin"

flutter --version
flutter precache --ios

cd "$CI_WORKSPACE"

echo "--- RECREATING .ENV FILE ---"
: "${API_BASE_URL:?API_BASE_URL is not set}"

cat <<EOF > .env
API_BASE_URL=$API_BASE_URL
EOF

echo ".env file created successfully."

echo "--- GETTING FLUTTER DEPENDENCIES ---"
flutter pub get

echo "--- INSTALLING COCOAPODS ---"
brew list cocoapods >/dev/null 2>&1 || HOMEBREW_NO_AUTO_UPDATE=1 brew install cocoapods

echo "--- INSTALLING PODS ---"
cd ios
pod install

echo "--- DONE ---"
