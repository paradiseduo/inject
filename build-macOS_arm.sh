#!/bin/bash

set -e

NAME=inject

function build() {
  START=$(date +%s)

  swift build --product $NAME \
    -c release \
    -Xswiftc "-sdk" \
    -Xswiftc "$(xcrun --sdk macosx --show-sdk-path)" \
    -Xswiftc "-target" \
    -Xswiftc "arm64-apple-macosx11.0" \
    -Xcc "-arch" \
    -Xcc "arm64" \
    -Xcc "--target=arm64-apple-macosx11.0" \
    -Xcc "-isysroot" \
    -Xcc "$(xcrun --sdk macosx --show-sdk-path)"

  END=$(date +%s)
  TIME=$(($END - $START))
  echo "build in $TIME seconds"
}

function copy() {
 cp .build/release/inject ./inject_arm64
}

function main() {
  build
  copy
}

main


