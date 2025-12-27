#!/bin/sh

# Fail on error
set -e

# The path to your flutter installation is handled by Xcode Cloud if 
# you've configured the environment, but it's safer to ensure 
# dependencies are fetched.
cd ../..
flutter precache --ios
flutter pub get

# Navigate to the iOS folder to install pods
cd ios
pod install