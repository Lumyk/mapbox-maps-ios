#!/bin/bash

set -euo pipefail

function step { >&2 echo -e "\033[1m\033[36m* $@\033[0m"; }
function finish { >&2 echo -en "\033[0m"; }
trap finish EXIT

PRODUCT=${1}
LINK_TYPE=${2}
SCHEME=${3:-"$PRODUCT"}
PROJECT=${4:-"$PRODUCT.xcodeproj"}
DSYM_NAMES=${5:-$PRODUCT}

if [ "$LINK_TYPE" = "dynamic" ]; then
    MACH_O_TYPE=mh_dylib
elif [ "$LINK_TYPE" = "static" ]; then
    MACH_O_TYPE=staticlib
else
    echo "Error: Invalid link type: $LINK_TYPE"
    echo "Usage: $0 [dynamic|static]"
    exit 1
fi

# Create iOS Simulator Framework
step "Archiving iOS Simulator Framework for $PRODUCT"
SIMULATOR_ARCHIVE_PATH="$(pwd)/.create-xcframework/iOS-Simulator.xcarchive"
rm -rf "$SIMULATOR_ARCHIVE_PATH"

xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -archivePath "$SIMULATOR_ARCHIVE_PATH" \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  SKIP_INSTALL=NO \
  ARCHS='x86_64 arm64' \
  EXCLUDED_ARCHS= \
  MACH_O_TYPE="$MACH_O_TYPE" \
  ENABLE_BITCODE=YES \
  LLVM_LTO=NO

# Create iOS Device Framework
step "Archiving iOS Device Framework for $PRODUCT"
DEVICE_ARCHIVE_PATH="$(pwd)/.create-xcframework/iOS.xcarchive"
rm -rf "$DEVICE_ARCHIVE_PATH"

xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$DEVICE_ARCHIVE_PATH" \
  BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
  SKIP_INSTALL=NO \
  ARCHS='arm64' \
  EXCLUDED_ARCHS= \
  MACH_O_TYPE="$MACH_O_TYPE" \
  ENABLE_BITCODE=YES \
  LLVM_LTO=NO

# Create XCFramework
step "Creating $PRODUCT.xcframework"

inject_build_info() {
  local archive_path="$1"

  plist_path="$archive_path/Info.plist"

  /usr/libexec/PlistBuddy -c "Add :MBXBuildInfo dict" "$plist_path"
  plutil -insert "MBXBuildInfo.BuildDate" -string "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$plist_path"
  plutil -insert "MBXBuildInfo.Git SHA" -string "$(git rev-parse HEAD)" "$plist_path"
  plutil -insert "MBXBuildInfo.Git Branch" -string "$(git rev-parse --abbrev-ref HEAD)" "$plist_path"
  plutil -insert "MBXBuildInfo.Swift version" -string "$(swift --version 2>&1 | grep -o "version .*" | cut -d ' ' -f2)" "$plist_path"
  plutil -insert "MBXBuildInfo.Xcode version" -string "$(xcodebuild -version | head -n 1 | cut -d ' ' -f2)" "$plist_path"
  plutil -insert "MBXBuildInfo.SDK version" -string "$(jq -r .version ../../../../Sources/MapboxMaps/MapboxMaps.json)" "$plist_path"

  if [[ -n "${CIRCLE_BUILD_NUM:-}" ]]; then
    echo "Injecting CI build info into info.plist"
    plutil -insert "MBXBuildInfo.CI Build Number" -string "$CIRCLE_BUILD_NUM" "$plist_path"
  fi
}

BUILD_XCFRAMEWORK_COMMAND="xcodebuild -create-xcframework -output '$PRODUCT.xcframework'"

BREAK=$'\n\t'
DEBUG_BREAK=$'\n\t\t'
for archive in "$DEVICE_ARCHIVE_PATH" "$SIMULATOR_ARCHIVE_PATH"
do
  FRAMEWORK_PATH=$(find "$archive" -name "$PRODUCT.framework")
  BUILD_XCFRAMEWORK_COMMAND+=" \\${BREAK} -framework '$FRAMEWORK_PATH'"
  inject_build_info "$FRAMEWORK_PATH"

  for dSYM_NAME in $DSYM_NAMES
  do
    dSYM="$archive/dSYMS/$dSYM_NAME.framework.dSYM"

    if [[ -d "$dSYM" ]]; then
      BUILD_XCFRAMEWORK_COMMAND+=" \\${DEBUG_BREAK} -debug-symbols '$dSYM'"
      # Get all UUIDs for dSyms (one per architecture) and find corresponding BCSymbolMap
      dSYM_UUIDs=$(dwarfdump --uuid "$dSYM"  | cut -d ' ' -f2)

      for dSYM_UUID in $dSYM_UUIDs
      do
        BCSYMBOLMAP_PATH="$archive/BCSymbolMaps/$dSYM_UUID.bcsymbolmap"
        if [[ -f "$BCSYMBOLMAP_PATH" ]]; then
          BUILD_XCFRAMEWORK_COMMAND+=" \\${DEBUG_BREAK} -debug-symbols '$BCSYMBOLMAP_PATH'"
        fi
      done
    fi
  done

done

echo "$BUILD_XCFRAMEWORK_COMMAND"
eval "$BUILD_XCFRAMEWORK_COMMAND"

# Clean Up
step "Cleaning up intermediate artifacts for $PRODUCT"
rm -rf .create-xcframework
