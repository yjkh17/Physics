#!/bin/bash
# Format all Swift sources using swift-format if available.
if command -v swift-format >/dev/null 2>&1; then
  find "$(dirname "$0")/.." -name '*.swift' -print0 | xargs -0 swift-format format -i
else
  echo "swift-format not found"
fi
