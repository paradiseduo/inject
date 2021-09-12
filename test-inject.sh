#!/bin/bash

function build() {
  echo "==========Build Start=========="
  chmod +x build-macOS_x86.sh
  ./build-macOS_x86.sh
  echo "==========Build Finish=========="
}

function testCase() {
  echo "==========Test Start=========="
  ./inject inject libtestinject.dylib
  echo "==========Test Result=========="
  ./inject
  echo "==========Test Finish=========="
}

function clean() {
  echo "==========Clean Start=========="
  rm -rf inject
  rm -rf inject_back
  echo "==========Clean Finish=========="
}

build
echo " "
testCase
echo " "
clean
