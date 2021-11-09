//
//  File.swift
//  
//
//  Created by paradiseduo on 2021/9/10.
//

import ArgumentParser
import Foundation
import MachO

let version = "1.1.0"

struct Inject: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "inject v\(version)", discussion: "inject is a tool which interfaces with MachO binaries in order to insert load commands.", version: version)
    
    @Argument(help: "The machO to inject.")
    var machoPath: String
    
    @Option(name: .shortAndLong, help: "The dylib to inject, please give me path.")
    var dylib: String = ""
    
    @Option(name: .shortAndLong, help: "Specify which type of load command to use in INSTALL. Can be reexport for LC_REEXPORT_DYLIB, weak for LC_LOAD_WEAK_DYLIB, upward for LC_LOAD_UPWARD_DYLIB, or load for LC_LOAD_DYLIB")
    var cmd: String = "LC_LOAD_DYLIB"
    
    @Flag(name: .shortAndLong, help: "Removes a code signature load command from the given binary.")
    var strip = false
    
    @Option(name: .shortAndLong, help: "Used with the STRIP command to weakly remove the signature. Without this, the code signature is replaced with null bytes on the binary and it's LOAD command is removed.")
    var weak = true
    
    mutating func run() throws {
        let cmd_type = LC_Type.get(cmd)
        if cmd_type == 0 {
            print("Invalid load command type")
            return
        }
        
        if dylib.count > 0 {
            FileManager.open(machoPath: machoPath, dylibPath: dylib) { data in
                if let binary = data {
                    let fh = binary.extract(fat_header.self)
                    BitType.checkType(machoPath: machoPath, header: fh) { type, isByteSwapped  in
                        LoadCommand.couldInjectLoadCommand(binary: binary, dylibPath: dylib, type: type, isByteSwapped: isByteSwapped) { canInject in
                            LoadCommand.inject(binary: binary, dylibPath: dylib, cmd: cmd_type, type: type, canInject: canInject) { newBinary in
                                if let b = newBinary {
                                    do {
                                        try b.write(to: URL(fileURLWithPath: machoPath))
                                        print("Inject Finish")
                                    } catch let err {
                                        print(err)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } else {
            if strip {
                FileManager.open(machoPath: machoPath) { data in
                    if let binary = data {
                        let fh = binary.extract(fat_header.self)
                        BitType.checkType(machoPath: machoPath, header: fh) { type, isByteSwapped  in
                            LoadCommand.removeSignature(binary: binary, type: type, isWeak: weak) { newBinary in
                                if let b = newBinary {
                                    do {
                                        try b.write(to: URL(fileURLWithPath: machoPath))
                                        print("Removes code signature finish")
                                    } catch let err {
                                        print(err)
                                    }
                                } else {
                                    print("Removes code signature failed")
                                }
                            }
                        }
                    }
                }
            } else {
                print("Need dylib to inject")
                return
            }
        }
    }
}
