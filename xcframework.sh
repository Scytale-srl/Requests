#!/bin/sh

# Definisci le variabili
SCHEME_NAME="Requests"
FRAMEWORK_NAME="Requests"
PLATFORM="iphoneos"
OUTPUT_PATH="Output"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"


# Per dispositivi:
xcodebuild archive -scheme $SCHEME_NAME -destination 'generic/platform='$PLATFORM'' -archivePath "$PROJECT_DIR/build/device.xcarchive" SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES

# Per simulatori:
xcodebuild archive -scheme $SCHEME_NAME -destination 'generic/platform=iOS Simulator' -archivePath "$PROJECT_DIR/build/simulator.xcarchive" SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES


# Crea l'xcframeworki con dSYM
xcodebuild -create-xcframework \
-framework "$PROJECT_DIR/build/device.xcarchive/Products/Library/Frameworks/$FRAMEWORK_NAME.framework" \
-debug-symbols "$PROJECT_DIR/build/device.xcarchive/dSYMs/$FRAMEWORK_NAME.framework.dSYM" \
-framework "$PROJECT_DIR/build/simulator.xcarchive/Products/Library/Frameworks/$FRAMEWORK_NAME.framework" \
-debug-symbols "$PROJECT_DIR/build/simulator.xcarchive/dSYMs/$FRAMEWORK_NAME.framework.dSYM" \
-output "$PROJECT_DIR/$OUTPUT_PATH/$FRAMEWORK_NAME.xcframework"


echo "XCFramework creato con successo in $OUTPUT_PATH"