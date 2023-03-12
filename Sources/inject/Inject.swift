//
//  File.swift
//  
//
//  Created by paradiseduo on 2021/9/10.
//

import ArgumentParser
import Foundation
import MachO

let version = "3.0.0"

struct Inject: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "inject v\(version)",
                                                    discussion: "inject is a tool which interfaces with MachO binaries in order to insert load commands.",
                                                    version: version)

    @Argument(help: "The machO/ipa to inject.")
    var filePath: String

    @Option(name: .shortAndLong, help: "The dylib to inject, please give me path.")
    var dylib: String = ""

    @Option(name: .shortAndLong, help: "Specify which type of load command to use in INSTALL. Can be reexport for LC_REEXPORT_DYLIB, weak for LC_LOAD_WEAK_DYLIB, upward for LC_LOAD_UPWARD_DYLIB, or load for LC_LOAD_DYLIB.")
    var cmd: String = "LC_LOAD_DYLIB"

    @Flag(name: .shortAndLong, help: "If inject into ipa, please set this flag. Default false mean is machO file path.")
    var ipa = false

    @Flag(name: .shortAndLong, help: "Removes a code signature load command from the given binary.")
    var strip = false

    @Flag(name: .shortAndLong, help: "Removes an ASLR flag from the macho header if it exists. This may render some executables unusable.")
    var aslr = false

    @Flag(name: .shortAndLong, help: "Removes any LC_LOAD commands which point to a given payload from the target binary. This may render some executables unusable.")
    var remove = false

    @Option(name: .shortAndLong, help: "Used with the STRIP command to weakly remove the signature. Without this, the code signature is replaced with null bytes on the binary and it's LOAD command is removed.")
    var weak = true

    mutating func run() throws {
        let cmdType = LCType.get(cmd)
        if cmdType == 0 {
            print("Invalid load command type")
            return
        }

        if ipa {
            injectIPA(ipaPath: filePath,
                      cmdType: cmdType,
                      injectPath: dylib) { success in
                if !success {
                    print("Inject IPA Fail")
                }
            }
        } else {
            injectMachO(machoPath: filePath,
                        cmdType: cmdType,
                        backup: true,
                        injectPath: dylib) { success in
                if !success {
                    print("Inject MachO Fail")
                }
            }
        }
    }
}

extension Inject {
    private func injectIPA(ipaPath: String,
                           cmdType: UInt32,
                           injectPath: String,
                           finishHandle: (Bool) -> Void) {
        var result = false
        var injectFilePath = "."
        if injectPath.hasPrefix("@") {
            let arr = injectPath.components(separatedBy: "/")
            for item in arr {
                if item.contains("@") {
                    continue
                } else {
                    injectFilePath += "/\(item)"
                }
            }
        } else {
            injectFilePath += "/\(injectPath)"
        }
        var iPath = ""
        var iName = ""
        var injectPathNew = ""
        let components = injectPath.components(separatedBy: "/")

        if injectPath.hasSuffix(".framework") {
            iName = injectFilePath.components(separatedBy: "/").last!
            iPath = injectFilePath

            let frameworkExeName = iName.components(separatedBy: ".").first!
            if components.count > 1 {
                if components.first!.hasPrefix("@") {
                    injectPathNew = "\(components.first!)/Inject/\(iName)/\(frameworkExeName)"
                } else {
                    injectPathNew = "@executable_path/Inject/\(iName)/\(frameworkExeName)"
                }
            } else {
                injectPathNew = "@executable_path/Inject/\(iName)/\(frameworkExeName)"
            }
        } else if injectPath.hasSuffix(".dylib") {
            iName = injectFilePath.components(separatedBy: "/").last!
            iPath = injectFilePath

            if components.count > 1 {
                if components.first!.hasPrefix("@") {
                    injectPathNew = "\(components.first!)/Inject/\(iName)"
                } else {
                    injectPathNew = "@executable_path/Inject/\(iName)"
                }
            } else {
                injectPathNew = "@executable_path/Inject/\(iName)"
            }
        } else if injectPath.contains(".framework") {
            let aaa = injectFilePath.components(separatedBy: "/")
            let bbb = aaa.dropLast()
            iName = bbb.last!
            for item in bbb {
                iPath += item+"/"
            }

            if components.count > 1 {
                if components.first!.hasPrefix("@") {
                    injectPathNew = "\(components.first!)/Inject/\(iName)/\(aaa.last!)"
                } else {
                    injectPathNew = "@executable_path/Inject/\(iName)/\(aaa.last!)"
                }
            } else {
                injectPathNew = "@executable_path/Inject/\(iName)/\(aaa.last!)"
            }
        }

        if injectPathNew.hasSuffix("/") {
            injectPathNew.removeLast()
        }

        if iPath == "" || iName == "" || !FileManager.default.fileExists(atPath: iPath) {
            print("Need a dylib or framework file to inject")
            finishHandle(result)
            return
        }

        let targetUrl = "."
        Shell.run("unzip -o \(ipaPath) -d \(targetUrl)") { status, output in
            if status == 0 {
                let payload = targetUrl+"/Payload"
                do {
                    let fileList = try FileManager.default.contentsOfDirectory(atPath: payload)
                    var machoPath = ""
                    var appPath = ""
                    for item in fileList {
                        if item.hasSuffix(".app") {
                            appPath = payload + "/\(item)"
                            machoPath = appPath+"/\(item.components(separatedBy: ".")[0])"
                            break
                        }
                    }

                    try FileManager.default.createDirectory(atPath: "\(appPath)/Inject/",
                                                            withIntermediateDirectories: true,
                                                            attributes: nil)
                    try FileManager.default.moveItem(atPath: iPath,
                                                     toPath: "\(appPath)/Inject/\(iName)")

                    injectMachO(machoPath: machoPath,
                                cmdType: cmdType,
                                backup: false,
                                injectPath: injectPathNew) { success in
                        if success {
                            Shell.run("zip -r \(ipaPath) \(payload)") { status, output in
                                if status == 0 {
                                    print("Inject \(injectPath) finish, new IPA file is \(ipaPath)")
                                    result = true
                                } else {
                                    print("\(output)")
                                }
                            }
                        }
                    }
                    try FileManager.default.removeItem(atPath: payload)
                } catch let error {
                    print("\(error)")
                }
            } else {
                print("\(output)")
            }
        }
        finishHandle(result)
    }

    private func injectMachO(machoPath: String,
                             cmdType: UInt32,
                             backup: Bool,
                             injectPath: String,
                             finishHandle: (Bool) -> Void) {
        var result = false
        FileManager.open(machoPath: machoPath, backup: backup) { data in
            if let binary = data {
                let fatHeader = binary.extract(fat_header.self)
                BitType.checkType(machoPath: machoPath, header: fatHeader) { type, isByteSwapped in
                    if injectPath.count > 0 {
                        if remove {
                            LoadCommand.remove(binary: binary,
                                               dylibPath: injectPath,
                                               cmd: cmdType,
                                               type: type) { newBinary in
                                result = Inject.writeFile(newBinary: newBinary,
                                                          machoPath: machoPath,
                                                          successTitle: "Remove \(injectPath) Finish",
                                                          failTitle: "Remove \(injectPath) failed")
                            }
                        } else {
                            LoadCommand.couldInjectLoadCommand(binary: binary,
                                                               dylibPath: injectPath,
                                                               type: type,
                                                               isByteSwapped: isByteSwapped) { canInject in
                                LoadCommand.inject(binary: binary,
                                                   dylibPath: injectPath,
                                                   cmd: cmdType, type: type,
                                                   canInject: canInject) { newBinary in
                                    result = Inject.writeFile(newBinary: newBinary,
                                                              machoPath: machoPath,
                                                              successTitle: "Inject \(injectPath) Finish",
                                                              failTitle: "Inject \(injectPath) failed")
                                }
                            }
                        }
                    } else if strip {
                        LoadCommand.removeSignature(binary: binary,
                                                    type: type,
                                                    isWeak: weak) { newBinary in
                            result = Inject.writeFile(newBinary: newBinary,
                                                      machoPath: machoPath,
                                                      successTitle: "Removes code signature finish",
                                                      failTitle: "Removes code signature failed")
                        }
                    } else if aslr {
                        LoadCommand.removeASLR(binary: binary,
                                               type: type) { newBinary in
                            result = Inject.writeFile(newBinary: newBinary,
                                                      machoPath: machoPath,
                                                      successTitle: "Removes ALSR finish",
                                                      failTitle: "Binary is not protected by ASLR")
                        }
                    } else {
                        print("Need dylib to inject")
                    }
                }
            }
        }
        finishHandle(result)
    }

    private static func writeFile(newBinary: Data?,
                                  machoPath: String,
                                  successTitle: String,
                                  failTitle: String) -> Bool {
        if let newBinary = newBinary {
            do {
                try newBinary.write(to: URL(fileURLWithPath: machoPath))
                print(successTitle)
                return true
            } catch let error {
                print(error)
            }
        }
        print(failTitle)
        return false
    }
}
