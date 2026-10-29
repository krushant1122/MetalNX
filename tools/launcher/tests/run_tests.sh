#!/bin/bash
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
echo "=== Running MetalNX Test Suite ==="
echo "-> 1/3: Game Detection & Recipe Compatibility Suite"
swift "$DIR/TestGameDetection.swift"

echo "-> 2/3: Pipeline Regression Reproduction Suite"
swift "$DIR/TestPipelineRegression.swift"

echo "-> 3/3: Pipeline Architectural Fixes Suite"
swift "$DIR/TestPipelineFixes.swift"

echo "✓ All MetalNX Test Suites Passed Successfully!"
