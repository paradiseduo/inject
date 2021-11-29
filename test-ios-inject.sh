#!/bin/bash

function build() {
  echo "==========Build Start=========="
  chmod +x build-macOS_x86.sh
  ./build-macOS_x86.sh
  echo "==========Build Finish=========="
}

function testCase() {
  echo "==========Test Start=========="
  ./inject testiOS/app.ipa -d  @executable_path/testiOS/injectiOSFramework.framework --ipa
  ./inject testiOS/app.ipa -d  @executable_path/testiOS/libinjectiOS.dylib --ipa  
  echo "==========Test Result=========="
  unzip testiOS/app.ipa > /dev/null
  otool -L Payload/TestLock.app/TestLock
  echo "==========Test Finish=========="
}

function clean() {
  echo "==========Clean Start=========="
  rm -rf Payload
  echo "==========Clean Finish=========="
}

build
echo " "
testCase
echo " "
clean
