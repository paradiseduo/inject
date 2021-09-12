# inject

inject is a tool which interfaces with MachO binaries in order to insert load commands. Below is its help.
```bash
➜ ./inject -h
OVERVIEW: inject v1.0.0

inject is a tool which interfaces with MachO binaries in order to insert load commands.

USAGE: inject <macho-path> <dylib-path> [--cmd <cmd>]

ARGUMENTS:
  <macho-path>            The machO to inject.
  <dylib-path>            The dylib to inject.

OPTIONS:
  --cmd <cmd>             Specify which type of load command to use in INSTALL. Can be reexport for LC_REEXPORT_DYLIB,
                          weak for LC_LOAD_WEAK_DYLIB, upward for LC_LOAD_UPWARD_DYLIB, or load for LC_LOAD_DYLIB
                          (default: LC_LOAD_DYLIB)
  --version               Show the version.
  -h, --help              Show help information.

```

## Build
build with xcode
```bash
open Package.swift
command + B
```

build with bash
```bash
chmod +x build-macOS_x86.sh
./build-macOS_x86.sh
```

## Test
```bash
chmod +x test-inject.sh
./test-inject.sh
```
