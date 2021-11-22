#!/bin/sh

# The docs recommend using Homebrew for CocoaPods.
# https://developer.apple.com/documentation/xcode/making-dependencies-available-to-xcode-cloud#Make-CocoaPods-Dependencies-Available-to-Xcode-Cloud

echo "ℹ️: Install CocoaPods via Homebrew"
brew install cocoapods

echo "ℹ️: Install CocoaPods' libraries"
pod install
