#!/bin/bash
# Core/ must stay free of UI and platform frameworks.
#
# This is the architectural rule the whole project rests on: if the puppet's behaviour
# is pure Swift, it can be unit-tested in milliseconds without a screen, a simulator or
# a microphone — and the rendering technology stays replaceable. It is also the rule
# that decays silently, because adding `import SwiftUI` to fix one thing always works.
# So it is enforced here rather than remembered.
set -euo pipefail

cd "$(dirname "$0")/.."
CORE="PuppetMaster/Core"
BANNED="UIKit|SwiftUI|SpriteKit|AVFoundation|QuartzCore|CoreGraphics|Combine"

if [ ! -d "$CORE" ]; then
  echo "error: $CORE not found"
  exit 1
fi

if violations=$(grep -rnE "^import ($BANNED)" "$CORE" 2>/dev/null); then
  echo "error: Core/ imports a UI or platform framework."
  echo "       Core must stay pure Swift — move this code to Stage/, Controls/ or Support/."
  echo
  echo "$violations"
  exit 1
fi

echo "Core purity: OK ($(find "$CORE" -name '*.swift' | wc -l | tr -d ' ') files, no platform imports)"
