//
//  File.swift
//  
//
//  Created by paradiseduo on 2021/9/10.
//

import ArgumentParser
import Foundation
import MachO

let version = "1.0.0"

struct Inject: ParsableCommand {
    static let configuration = CommandConfiguration(abstract: "inject v\(version)", discussion: "inject is a tool which interfaces with MachO binaries in order to insert load commands.", version: version)
    
    @Argument(help: "The machO to inject.")
    var machoPath: String
    
    @Argument(help: "The dylib to inject.")
    var dylibPath: String
    
    @Option(help: "Specify which type of load command to use in INSTALL. Can be reexport for LC_REEXPORT_DYLIB, weak for LC_LOAD_WEAK_DYLIB, upward for LC_LOAD_UPWARD_DYLIB, or load for LC_LOAD_DYLIB")
    var cmd: String = "LC_LOAD_DYLIB"
    
    mutating func run() throws {
        let cmd_type = LC_Type.get(cmd)
        if cmd_type == 0 {
            print("Invalid load command type")
            return
        }
        
        FileManager.open(machoPath: machoPath, dylibPath: dylibPath) { data in
            if let binary = data {
                let fh = binary.extract(fat_header.self)
                BitType.checkType(machoPath: machoPath, header: fh) { type, isByteSwapped  in
                    LoadCommand.couldInjectLoadCommand(binary: binary, dylibPath: dylibPath, type: type, isByteSwapped: isByteSwapped) { canInject in
                        LoadCommand.inject(binary: binary, dylibPath: dylibPath, cmd: cmd_type, type: type, canInject: canInject) { newBinary in
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
    }
}
