#!/bin/sh
# Runs the UI tests on a watch simulator and exports their screenshots.
#
#     Tools/ui_tests.sh [output directory] [-only-testing:HorizonUITests/HorizonUITests/testName]
set -e
cd "$(dirname "$0")/.."
DEVICE="${DEVICE:-Apple Watch Ultra 3 (49mm)}"
OUT="${1:-build/ui-tests}"
[ $# -gt 0 ] && shift
rm -rf build/ui-tests.xcresult "$OUT"
xcodegen generate >/dev/null
set +e
xcodebuild -project Horizon.xcodeproj -scheme Horizon \
    -destination "platform=watchOS Simulator,name=$DEVICE" -derivedDataPath build/dd \
    -resultBundlePath build/ui-tests.xcresult "$@" test 2>&1 \
    | grep -E "error:|Test Case .* (passed|failed)|XCTAssert|Executed|TEST (SUCCEEDED|FAILED)|BUILD FAILED"
set -e
mkdir -p "$OUT"
# Keep the named screenshots only, under their names.
TMP="$(mktemp -d)"
xcrun xcresulttool export attachments --path build/ui-tests.xcresult --output-path "$TMP" >/dev/null 2>&1 || true
python3 - "$TMP" "$OUT" <<'PY'
import json, pathlib, shutil, sys
source, target = map(pathlib.Path, sys.argv[1:])
manifest = source / "manifest.json"
if manifest.exists():
    for test in json.loads(manifest.read_text()):
        for attachment in test.get("attachments", []):
            name = attachment.get("suggestedHumanReadableName", "")
            if name.endswith(".png"):
                shutil.copy(source / attachment["exportedFileName"], target / (name.split("_0_")[0] + ".png"))
PY
rm -rf "$TMP"
