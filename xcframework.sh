#!/bin/sh

# Definisci le variabili
SCHEME_NAME="Requests"
FRAMEWORK_NAME="Requests"
OUTPUT_PATH="Output"

# Per dispositivi iOS:
xcodebuild archive -scheme $SCHEME_NAME -destination 'generic/platform=iphoneos' -archivePath 'build/device.xcarchive' SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES

# Per simulatori iOS:
xcodebuild archive -scheme $SCHEME_NAME -destination 'generic/platform=iOS Simulator' -archivePath 'build/simulator.xcarchive' SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES

# Per macOS:
xcodebuild archive -scheme $SCHEME_NAME -destination 'generic/platform=macOS' -archivePath 'build/macos.xcarchive' SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES

# Per Mac Catalyst:
xcodebuild archive -scheme $SCHEME_NAME -destination 'generic/platform=macOS,variant=Mac Catalyst' -archivePath 'build/catalyst.xcarchive' SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES

# Crea l'xcframework includendo i dSYM
xcodebuild -create-xcframework \
-framework 'build/device.xcarchive/Products/Library/Frameworks/'$FRAMEWORK_NAME'.framework' \
-debug-symbols 'build/device.xcarchive/dSYMs/'$FRAMEWORK_NAME'.framework.dSYM' \
-framework 'build/simulator.xcarchive/Products/Library/Frameworks/'$FRAMEWORK_NAME'.framework' \
-debug-symbols 'build/simulator.xcarchive/dSYMs/'$FRAMEWORK_NAME'.framework.dSYM' \
-framework 'build/macos.xcarchive/Products/Library/Frameworks/'$FRAMEWORK_NAME'.framework' \
-debug-symbols 'build/macos.xcarchive/dSYMs/'$FRAMEWORK_NAME'.framework.dSYM' \
-framework 'build/catalyst.xcarchive/Products/Library/Frameworks/'$FRAMEWORK_NAME'.framework' \
-debug-symbols 'build/catalyst.xcarchive/dSYMs/'$FRAMEWORK_NAME'.framework.dSYM' \
-output $OUTPUT_PATH'/'$FRAMEWORK_NAME'.xcframework'

echo "XCFramework creato con successo in $OUTPUT_PATH"