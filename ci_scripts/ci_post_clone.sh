#!/bin/sh

# The docs recommend using Homebrew for CocoaPods.
# https://developer.apple.com/documentation/xcode/making-dependencies-available-to-xcode-cloud#Make-CocoaPods-Dependencies-Available-to-Xcode-Cloud

echo "ℹ️Ruby -v:"
ruby -v

echo "ℹ️rbenv?"
which rbenv

echo "ℹ️rvm?"
which rvm

echo "ℹ️chruby?"
which chruby

echo "👋Inspection Completed"
exit 1

echo "ℹ️: Install CocoaPods via Homebrew"
brew install cocoapods

echo "ℹ️: Install CocoaPods' libraries"
pod install
