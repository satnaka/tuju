#!/bin/sh
set -eu

# CocoaPods records the local Node installation for builds launched from Xcode.
. "$SRCROOT/.xcode.env"
if [ -f "$SRCROOT/.xcode.env.local" ]; then
  . "$SRCROOT/.xcode.env.local"
fi
if [ ! -x "${NODE_BINARY:-}" ]; then
  echo "error: Set NODE_BINARY in .xcode.env.local to your Node executable."
  exit 1
fi
export PATH="$(dirname "$NODE_BINARY"):$PATH"
js="$DERIVED_FILE_DIR/TuJuControls.js"
"$NODE_BINARY" "$SRCROOT/NativeUI/scripts/bundle.cjs" "$js"
cp "$DERIVED_FILE_DIR/TuJuComponentNotices.txt" "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/"
cp "$PODS_ROOT/Target Support Files/Pods-TuJu/Pods-TuJu-acknowledgements.plist" "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/"
"$PODS_ROOT/hermes-engine/destroot/bin/hermesc" -O -emit-binary -max-diagnostic-width=80 \
  -out "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/main.jsbundle" "$js"
