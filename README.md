# inject

inject is a tool which interfaces with MachO binaries in order to insert load commands. Below is its help.
```bash
➜ ./inject -h
OVERVIEW: inject v1.2.0

inject is a tool which interfaces with MachO binaries in order to insert load commands.

USAGE: inject <macho-path> [--dylib <dylib>] [--cmd <cmd>] [--strip] [--aslr] [--weak <weak>]

ARGUMENTS:
  <macho-path>            The machO to inject.

OPTIONS:
  -d, --dylib <dylib>     The dylib to inject, please give me path.
  -c, --cmd <cmd>         Specify which type of load command to use in INSTALL. Can be reexport for LC_REEXPORT_DYLIB, weak for LC_LOAD_WEAK_DYLIB, upward for LC_LOAD_UPWARD_DYLIB, or load for LC_LOAD_DYLIB. (default:
                          LC_LOAD_DYLIB)
  -s, --strip             Removes a code signature load command from the given binary.
  -a, --aslr              Removes an ASLR flag from the macho header if it exists. This may render some executables unusable.
  -w, --weak <weak>       Used with the STRIP command to weakly remove the signature. Without this, the code signature is replaced with null bytes on the binary and it's LOAD command is removed. (default: true)
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
