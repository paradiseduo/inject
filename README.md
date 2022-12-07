# inject

inject is a tool which interfaces with MachO binaries in order to insert load commands. Below is its help.
```bash
❯ ./inject -h
OVERVIEW: inject v3.0.0

inject is a tool which interfaces with MachO binaries in order to insert load commands.

USAGE: inject <file-path> [--dylib <dylib>] [--cmd <cmd>] [--ipa] [--strip] [--aslr] [--remove] [--weak <weak>]

ARGUMENTS:
  <file-path>             The machO/ipa to inject.

OPTIONS:
  -d, --dylib <dylib>     The dylib to inject, please give me path.
  -c, --cmd <cmd>         Specify which type of load command to use in INSTALL. Can be reexport for LC_REEXPORT_DYLIB, weak for LC_LOAD_WEAK_DYLIB, upward for LC_LOAD_UPWARD_DYLIB, or load for LC_LOAD_DYLIB. (default: LC_LOAD_DYLIB)
  -i, --ipa               If inject into ipa, please set this flag. Default false mean is machO file path.
  -s, --strip             Removes a code signature load command from the given binary.
  -a, --aslr              Removes an ASLR flag from the macho header if it exists. This may render some executables unusable.
  -r, --remove            Removes any LC_LOAD commands which point to a given payload from the target binary. This may render some executables unusable.
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
❯ chmod +x build-macOS_x86.sh
❯ ./build-macOS_x86.sh
```

## Test
Test for mac machO
```bash
❯ chmod +x test-mac-inject.sh
❯ ./test-mac-inject.sh
==========Build Start==========
[0/0] Build complete!
build in 1 seconds
==========Build Finish==========

==========Test Start==========
Backup machO file ./inject_back
Inject @executable_path/testMac/libtestinject.dylib Finish
==========Test Result==========
inject:
	/usr/lib/libobjc.A.dylib (compatibility version 1.0.0, current version 228.0.0)
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1311.0.0)
	/System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation (compatibility version 150.0.0, current version 1853.0.0)
	/System/Library/Frameworks/Foundation.framework/Versions/C/Foundation (compatibility version 300.0.0, current version 1853.0.0)
	@rpath/libswiftCore.dylib (compatibility version 1.0.0, current version 1300.0.29)
	@rpath/libswiftCoreFoundation.dylib (compatibility version 1.0.0, current version 14.0.0, weak)
	@rpath/libswiftCoreGraphics.dylib (compatibility version 1.0.0, current version 2.0.0, weak)
	@rpath/libswiftDarwin.dylib (compatibility version 1.0.0, current version 0.0.0)
	@rpath/libswiftDispatch.dylib (compatibility version 1.0.0, current version 9.0.0, weak)
	@rpath/libswiftFoundation.dylib (compatibility version 1.0.0, current version 69.0.0)
	@rpath/libswiftIOKit.dylib (compatibility version 1.0.0, current version 1.0.0, weak)
	@rpath/libswiftObjectiveC.dylib (compatibility version 1.0.0, current version 3.0.0, weak)
	@rpath/libswiftXPC.dylib (compatibility version 1.0.0, current version 1.1.0, weak)
	@executable_path/testMac/libtestinject.dylib (compatibility version 0.0.0, current version 0.0.0)
==========Test Finish==========

==========Clean Start==========
==========Clean Finish==========
```
Test for iOS IPA
```bash
❯ chmod +x test-ios-inject.sh
❯ ./test-ios-inject.sh
==========Build Start==========
[0/0] Build complete!
build in 0 seconds
==========Build Finish==========

==========Test Start==========
Inject @executable_path/Inject/injectiOSFramework.framework/injectiOSFramework Finish
Inject @executable_path/testiOS/injectiOSFramework.framework finish, new IPA file is testiOS/app.ipa
Inject @executable_path/Inject/libinjectiOS.dylib Finish
Inject @executable_path/testiOS/libinjectiOS.dylib finish, new IPA file is testiOS/app.ipa
==========Test Result==========
Payload/TestLock.app/TestLock:
	/System/Library/Frameworks/Foundation.framework/Foundation (compatibility version 300.0.0, current version 1854.0.0)
	/usr/lib/libobjc.A.dylib (compatibility version 1.0.0, current version 228.0.0)
	/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1311.0.0)
	/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation (compatibility version 150.0.0, current version 1854.0.0)
	/System/Library/Frameworks/UIKit.framework/UIKit (compatibility version 1.0.0, current version 5067.3.107)
	@executable_path/Inject/injectiOSFramework.framework/injectiOSFramework (compatibility version 0.0.0, current version 0.0.0)
	@executable_path/Inject/libinjectiOS.dylib (compatibility version 0.0.0, current version 0.0.0)
==========Test Finish==========

==========Clean Start==========
==========Clean Finish==========
```

## Use
### Inject dylib for mac exec:
```bash
❯ ./inject testExec -d @executable_path/testMac/libtestinject.dylib
```
### Remove dylib for mac exec:
```bash
❯ ./inject testExec -d @executable_path/testMac/libtestinject.dylib --remove
```

### Inject dylib for ipa:
```bash
❯ ./inject testiOS/app.ipa -d  @executable_path/testiOS/libinjectiOS.dylib --ipa
```
### Inject Framework for ipa:
```bash
❯ ./inject testiOS/app.ipa -d  @executable_path/testiOS/injectiOSFramework.framework/injectiOSFramework --ipa
```
OR end with .framework
```bash
❯ ./inject testiOS/app.ipa -d  @executable_path/testiOS/injectiOSFramework.framework --ipa
```

## Use As Framework

Use Injection.framework, See [ViewController.swift](https://github.com/paradiseduo/inject/blob/master/Injection/InjectTest/ViewController.swift)


## Use as Swift Package

Package.swift:
```swift
// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Test",
    products: [
        .executable(
            name: "Test",
            targets: ["Test"]),
    ],
    dependencies: [
         .package(url: "https://github.com/paradiseduo/inject", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "Test",
            dependencies: [.product(name: "Injection", package: "inject"),]),
        .testTarget(
            name: "TestTests",
            dependencies: ["Test"]),
    ]
)
```

Example:

```swift
import injection

Inject.injectMachO(machoPath: "", cmdType: LC_Type.LOAD_DYLIB, backup: false, injectPath: "") { result in
    
}
```



## Other
You should resign new .IPA file to run.
Just use codesign:
```bash
❯ security find-identity -v -p codesigning
1) xxxxx "Apple Development: xxx xx (xxxxxxxxxx)"
     1 valid identities found
❯ codesign -f -s "xxxxx" Payload/app.app
Payload/app.app: replacing existing signature
❯ codesign -f -s "xxxxx" Payload/app.app/Inject/libxxxxx.dylib
Payload/app.app/Inject/libxxxxx.dylib: replacing existing signature
```

## License

This software is released under the GPL-3.0 license.
