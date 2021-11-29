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
  echo "==========Test Result=========="
  otool -L inject
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
