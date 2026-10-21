#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build
swiftc -swift-version 5 -module-cache-path .build/module-cache Sources/DisplayLayout.swift Sources/WebAddress.swift Tests/main.swift -o .build/layout-tests
.build/layout-tests
