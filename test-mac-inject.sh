#!/bin/bash

function build() {
  echo "==========Build Start=========="
  chmod +x build-macOS_x86.sh
  ./build-macOS_x86.sh
  echo "==========Build Finish=========="
}

function testCase() {
  echo "==========Test Start=========="
  ./inject inject -d @executable_path/testMac/libtestinject.dylib
  codesign -s - -f --preserve-metadata=entitlements inject
  echo "==========Test otool=========="
  otool -L inject
  echo "==========Test Run=========="
  ./inject
  echo "==========Test Finish=========="
}

function clean() {
  echo "==========Clean Start=========="
  rm -rf inject
  mv inject_back inject
  echo "==========Clean Finish=========="
}

build
echo " "
testCase
echo " "
clean

function buildarm() {
  echo "==========Build Start=========="
  chmod +x build-macOS_arm.sh
  ./build-macOS_arm.sh
  echo "==========Build Finish=========="
}

function testCasearm() {
  echo "==========Test Start=========="
  ./inject_arm64 inject_arm64 -d @executable_path/testMac/libtestinject.dylib
  codesign -s - -f --preserve-metadata=entitlements inject_arm64
  echo "==========Test otool=========="
  otool -L inject_arm64
  echo "==========Test Run=========="
  ./inject_arm64
  echo "==========Test Finish=========="
}

function cleanarm() {
  echo "==========Clean Start=========="
  rm -rf inject_arm64
  mv inject_arm64_back inject_arm64
  echo "==========Clean Finish=========="
}

buildarm
echo " "
testCasearm
echo " "
cleanarm
