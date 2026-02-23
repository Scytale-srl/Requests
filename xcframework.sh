#!/bin/sh

set -e

# Definisci le variabili
SCHEME_NAME="Requests"
FRAMEWORK_NAME="Requests"
PLATFORM="iphoneos"
OUTPUT_PATH="Output"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Pulizia build precedenti
echo "Pulizia cartelle build/ e Output/..."
rm -rf "$PROJECT_DIR/build"
rm -rf "$PROJECT_DIR/$OUTPUT_PATH"

# Per dispositivi:
xcodebuild archive -scheme $SCHEME_NAME -destination 'generic/platform='$PLATFORM'' -archivePath "$PROJECT_DIR/build/device.xcarchive" SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES

# Per simulatori:
xcodebuild archive -scheme $SCHEME_NAME -destination 'generic/platform=iOS Simulator' -archivePath "$PROJECT_DIR/build/simulator.xcarchive" SKIP_INSTALL=NO BUILD_LIBRARIES_FOR_DISTRIBUTION=YES

# Crea l'xcframework con dSYM
xcodebuild -create-xcframework \
-framework "$PROJECT_DIR/build/device.xcarchive/Products/Library/Frameworks/$FRAMEWORK_NAME.framework" \
-debug-symbols "$PROJECT_DIR/build/device.xcarchive/dSYMs/$FRAMEWORK_NAME.framework.dSYM" \
-framework "$PROJECT_DIR/build/simulator.xcarchive/Products/Library/Frameworks/$FRAMEWORK_NAME.framework" \
-debug-symbols "$PROJECT_DIR/build/simulator.xcarchive/dSYMs/$FRAMEWORK_NAME.framework.dSYM" \
-output "$PROJECT_DIR/$OUTPUT_PATH/$FRAMEWORK_NAME.xcframework"

echo "XCFramework creato con successo in $OUTPUT_PATH"

# Crea zip dell'XCFramework
echo "Creazione zip..."
cd "$PROJECT_DIR/$OUTPUT_PATH"
zip -r "$PROJECT_DIR/$OUTPUT_PATH/$FRAMEWORK_NAME.xcframework.zip" "$FRAMEWORK_NAME.xcframework"
cd "$PROJECT_DIR"

echo "Zip creato: $OUTPUT_PATH/$FRAMEWORK_NAME.xcframework.zip"

# Calcola SHA256 checksum
CHECKSUM=$(swift package compute-checksum "$PROJECT_DIR/$OUTPUT_PATH/$FRAMEWORK_NAME.xcframework.zip")
echo "SHA256 Checksum: $CHECKSUM"
