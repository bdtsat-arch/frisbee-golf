#!/bin/bash
# Auto-generates lib/build_info.dart with an incrementing build number,
# git hash, and build timestamp. Run before every flutter build or flutter run.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_NUMBER_FILE="$SCRIPT_DIR/build_number.txt"

# Read and increment build number
BUILD_NUMBER=$(cat "$BUILD_NUMBER_FILE" 2>/dev/null || echo "1")
BUILD_NUMBER=$((BUILD_NUMBER + 1))
echo "$BUILD_NUMBER" > "$BUILD_NUMBER_FILE"

if [[ -n "$GITHUB_SHA" ]]; then
	HASH="${GITHUB_SHA:0:7}"
else
	HASH=$(git -C "$SCRIPT_DIR/.." rev-parse --short HEAD 2>/dev/null || echo "unknown")
fi
TIMESTAMP=$(date -u "+%Y-%m-%d %H:%M UTC")

cat > "$SCRIPT_DIR/../lib/build_info.dart" <<EOF
// AUTO-GENERATED — do not edit. Re-generated on each build by scripts/gen_build_info.sh
const String kBuildHash = '$HASH';
const String kBuildDate = '$TIMESTAMP';
const int kBuildNumber = $BUILD_NUMBER;
EOF

echo "Build #$BUILD_NUMBER  |  $HASH  |  $TIMESTAMP"
