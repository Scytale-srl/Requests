#!/bin/sh

# Definisci le variabili
SCHEME_NAME="Requests"
FRAMEWORK_NAME="Requests"
PLATFORM="iphoneos"
OUTPUT_PATH="Output"


# Per dispositivi:
xcodebuild archive -scheme $SCHEME_NAME -destination 'generic/platform='$PLATFORM'' -archivePath 'build/device.xcarchive' SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES

# Per simulatori:
xcodebuild archive -scheme $SCHEME_NAME -destination 'generic/platform=iOS Simulator' -archivePath 'build/simulator.xcarchive' SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES


# Crea l'xcframeworki
xcodebuild -create-xcframework \
-framework 'build/device.xcarchive/Products/Library/Frameworks/'$FRAMEWORK_NAME'.framework' \
-framework 'build/simulator.xcarchive/Products/Library/Frameworks/'$FRAMEWORK_NAME'.framework' \
-output $OUTPUT_PATH'/'$FRAMEWORK_NAME'.xcframework'


echo "XCFramework creato con successo in $OUTPUT_PATH"

