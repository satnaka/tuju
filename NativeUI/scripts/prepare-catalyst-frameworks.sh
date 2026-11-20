#!/bin/sh
set -eu
[ "${EFFECTIVE_PLATFORM_NAME:-}" = "-maccatalyst" ] || exit 0

# RN 0.88.1's Catalyst archives materialize the versioned framework symlinks
# as duplicate directories/files. Restore the standard macOS layout in the
# platform's build intermediates before CocoaPods embeds and signs them.
for spec in 'React-Core-prebuilt/React' 'ReactNativeDependencies/ReactNativeDependencies'; do
  framework="$PODS_XCFRAMEWORKS_BUILD_DIR/$spec.framework"
  name=${spec##*/}
  if [ -L "$framework/Versions/Current" ]; then continue; fi
  test -f "$framework/Versions/A/$name"
  test -f "$framework/Versions/Current/Resources/Info.plist"
  rm -rf "$framework/Versions/Current" "$framework/Resources"
  ln -s A "$framework/Versions/Current"
  mv -f "$framework/$name" "$framework/Versions/A/$name"
  ln -s "Versions/Current/$name" "$framework/$name"
  ln -s "Versions/Current/Resources" "$framework/Resources"
  for resource in "$framework"/*.xcprivacy "$framework"/*.bundle; do
    if [ -e "$resource" ]; then
      mv "$resource" "$framework/Resources/"
    fi
  done
done
