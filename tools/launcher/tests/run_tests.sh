#!/bin/bash
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
echo "=== Running MetalNX Test Suite ==="
swift "$DIR/TestGameDetection.swift"
