//
//  File.swift
//
//
//  Created by paradiseduo on 2021/9/10.
//

import Foundation
import MachO

let byteSwappedOrder = NXByteOrder(rawValue: 0)

public enum LCType: String {
    case reexportDylib = "LC_REEXPORT_DYLIB"
    case loadWeakDylib = "LC_LOAD_WEAK_DYLIB"
    case loadUpwardDylib = "LC_LOAD_UPWARD_DYLIB"
    case loadDylib = "LC_LOAD_DYLIB"

    static func get(_ type: String) -> UInt32 {
        switch type {
        case LCType.reexportDylib.rawValue:
            return LC_REEXPORT_DYLIB
        case LCType.loadWeakDylib.rawValue:
            return LC_LOAD_WEAK_DYLIB
        case LCType.loadUpwardDylib.rawValue:
            return LC_LOAD_UPWARD_DYLIB
        case LCType.loadDylib.rawValue:
            return UInt32(LC_LOAD_DYLIB)
        default:
            return 0
        }
    }
}

public struct LoadCommand {
    public static func couldInjectLoadCommand(binary: Data,
                                              dylibPath: String,
                                              type: BitType,
                                              isByteSwapped: Bool,
                                              handle: (Bool) -> Void) {
        if type == .x64Fat || type == .x86Fat || type == .none {
            handle(false)
            return
        }

        if type == .x86 {
            let header = binary.extract(mach_header.self)
            var offset = MemoryLayout.size(ofValue: header)
            for _ in 0..<header.ncmds {
                let loadCommand = binary.extract(load_command.self, offset: offset)
                switch loadCommand.cmd {
                case LC_REEXPORT_DYLIB, LC_LOAD_UPWARD_DYLIB, LC_LOAD_WEAK_DYLIB, UInt32(LC_LOAD_DYLIB):
                    var command = binary.extract(dylib_command.self, offset: offset)
                    if isByteSwapped {
                        swap_dylib_command(&command, byteSwappedOrder)
                    }
                    let curPath = String(data: binary,
                                         offset: offset,
                                         commandSize: Int(command.cmdsize),
                                         loadCommandString: command.dylib.name)
                    let curName = curPath.components(separatedBy: "/").last
                    if curName == dylibPath || curPath == dylibPath {
                        print("Load command already exists")
                        handle(false)
                        return
                    }
                default:
                    break
                }
                offset += Int(loadCommand.cmdsize)
            }
        } else {
            let header = binary.extract(mach_header_64.self)
            var offset = MemoryLayout.size(ofValue: header)
            for _ in 0..<header.ncmds {
                let loadCommand = binary.extract(load_command.self, offset: offset)
                switch loadCommand.cmd {
                case LC_REEXPORT_DYLIB, LC_LOAD_UPWARD_DYLIB, LC_LOAD_WEAK_DYLIB, UInt32(LC_LOAD_DYLIB):
                    var command = binary.extract(dylib_command.self, offset: offset)
                    if isByteSwapped {
                        swap_dylib_command(&command, byteSwappedOrder)
                    }
                    let curPath = String(data: binary,
                                         offset: offset,
                                         commandSize: Int(command.cmdsize),
                                         loadCommandString: command.dylib.name)
                    let curName = curPath.components(separatedBy: "/").last
                    if curName == dylibPath || curPath == dylibPath {
                        print("Load command already exists")
                        handle(false)
                        return
                    }
                default:
                    break
                }
                offset += Int(loadCommand.cmdsize)
            }
        }
        handle(true)
    }

    public static func inject(binary: Data,
                              dylibPath: String,
                              cmd: UInt32,
                              type: BitType,
                              canInject: Bool,
                              handle: (Data?) -> Void) {
        if canInject {
            var newbinary = binary
            let length = MemoryLayout<dylib_command>.size + dylibPath.lengthOfBytes(using: String.Encoding.utf8)
            let padding = (8 - (length % 8))
            let cmdsize = length+padding

            var start = 0
            var end = cmdsize
            var subData: Data
            var newHeaderData: Data
            var machoRange: Range<Data.Index>
            if type == .x86 {
                var header = binary.extract(mach_header.self)
                start = Int(header.sizeofcmds) + Int(MemoryLayout<mach_header>.size)
                end += start
                subData = newbinary[start..<end]

                header.ncmds += 1
                header.sizeofcmds += UInt32(cmdsize)

                newHeaderData = Data(bytes: &header, count: MemoryLayout<mach_header>.size)
                machoRange = 0..<MemoryLayout<mach_header>.size
            } else {
                var header = binary.extract(mach_header_64.self)
                start = Int(header.sizeofcmds) + Int(MemoryLayout<mach_header_64>.size)
                end += start
                subData = newbinary[start..<end]

                header.ncmds += 1
                header.sizeofcmds += UInt32(cmdsize)

                newHeaderData = Data(bytes: &header, count: MemoryLayout<mach_header_64>.size)
                machoRange = 0..<MemoryLayout<mach_header_64>.size
            }

            let testString = String(data: subData, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters)
            if testString != "" && testString != nil {
                print("cannot inject payload into \(dylibPath) because there is no room")
                handle(nil)
                return
            }

            let dylib = dylib(name: lc_str(offset: UInt32(MemoryLayout<dylib_command>.size)),
                           timestamp: 2,
                           current_version: 0,
                           compatibility_version: 0)
            var command = dylib_command(cmd: cmd,
                                        cmdsize: UInt32(cmdsize),
                                        dylib: dylib)

            var commandData = Data(bytes: &command, count: MemoryLayout<dylib_command>.size)
            commandData.append(dylibPath.data(using: String.Encoding.ascii) ?? Data())
            commandData.append(Data(count: padding))

            let subrange = start..<start + commandData.count
            newbinary.replaceSubrange(subrange, with: commandData)

            newbinary.replaceSubrange(machoRange, with: newHeaderData)

            handle(newbinary)
        } else {
            handle(nil)
        }
    }

    public static func removeSignature(binary: Data,
                                       type: BitType,
                                       isWeak: Bool,
                                       handle: (Data?) -> Void) {
        if type == .x64Fat || type == .x86Fat || type == .none {
            handle(nil)
            return
        }
        var newbinary = binary
        var opSoftStrip = 0x00001337
        if type == .x86 {
            var header = newbinary.extract(mach_header.self)
            var offset = MemoryLayout.size(ofValue: header)
            for _ in 0..<header.ncmds {
                let loadCommand = binary.extract(load_command.self, offset: offset)
                if loadCommand.cmd == UInt32(LC_CODE_SIGNATURE) {
                    let command = binary.extract(linkedit_data_command.self, offset: offset)
                    if isWeak {
                        header.ncmds -= 1
                        header.sizeofcmds -= UInt32(MemoryLayout<linkedit_data_command>.size)
                        let newHeaderData = Data(bytes: &header, count: MemoryLayout<mach_header>.size)

                        newbinary.replaceSubrange(0..<MemoryLayout<mach_header>.size,
                                                  with: newHeaderData)
                        newbinary.replaceSubrange(offset..<offset + Int(command.cmdsize),
                                                  with: Data(count: Int(command.cmdsize)))
                        newbinary.removeSubrange(Int(command.dataoff)..<Int(command.dataoff + command.datasize))
                    } else {
                        newbinary.replaceSubrange(offset..<offset + 4,
                                                  with: Data(bytes: &opSoftStrip, count: 4))
                    }
                }
                offset += Int(loadCommand.cmdsize)
            }
        } else {
            var header = binary.extract(mach_header_64.self)
            var offset = MemoryLayout.size(ofValue: header)
            for _ in 0..<header.ncmds {
                let loadCommand = binary.extract(load_command.self, offset: offset)
                if loadCommand.cmd == UInt32(LC_CODE_SIGNATURE) {
                    let command = binary.extract(linkedit_data_command.self, offset: offset)
                    if isWeak {
                        header.ncmds -= 1
                        header.sizeofcmds -= UInt32(MemoryLayout<linkedit_data_command>.size)
                        let newHeaderData = Data(bytes: &header, count: MemoryLayout<mach_header_64>.size)

                        newbinary.replaceSubrange(0..<MemoryLayout<mach_header_64>.size,
                                                  with: newHeaderData)
                        newbinary.replaceSubrange(offset..<offset + Int(command.cmdsize),
                                                  with: Data(count: Int(command.cmdsize)))
                        newbinary.removeSubrange(Int(command.dataoff)..<Int(command.dataoff + command.datasize))
                    } else {
                        newbinary.replaceSubrange(offset..<offset + 4,
                                                  with: Data(bytes: &opSoftStrip, count: 4))
                    }
                }
                offset += Int(loadCommand.cmdsize)
            }
        }
        handle(newbinary)
    }

    public static func removeASLR(binary: Data, type: BitType, handle: (Data?) -> Void) {
        if type == .x64Fat || type == .x86Fat || type == .none {
            handle(nil)
            return
        }
        var newbinary = binary
        if type == .x86 {
            var header = newbinary.extract(mach_header.self)
            if (header.flags & UInt32(MH_PIE)) != 0 {
                header.flags &= 0xFFDFFFFF
                newbinary.replaceSubrange(0..<MemoryLayout<mach_header>.size,
                                          with: Data(bytes: &header, count: MemoryLayout<mach_header>.size))
            } else {
                handle(nil)
                return
            }
        } else {
            var header = binary.extract(mach_header_64.self)
            if (header.flags & UInt32(MH_PIE)) != 0 {
                header.flags &= 0xFFDFFFFF
                newbinary.replaceSubrange(0..<MemoryLayout<mach_header_64>.size,
                                          with: Data(bytes: &header, count: MemoryLayout<mach_header_64>.size))
            } else {
                handle(nil)
                return
            }
        }
        handle(newbinary)
    }

    public static func remove(binary: Data,
                              dylibPath: String,
                              cmd: UInt32,
                              type: BitType,
                              handle: (Data?) -> Void) {
        if type == .x64Fat || type == .x86Fat || type == .none {
            handle(nil)
            return
        }
        var newbinary = binary
        var newHeaderData: Data?
        var machoRange: Range<Data.Index>?
        var start: Int?
        var size: Int?
        var end: Int?

        if type == .x86 {
            var header = newbinary.extract(mach_header.self)
            var offset = MemoryLayout.size(ofValue: header)
            for _ in 0..<header.ncmds {
                let loadCommand = binary.extract(load_command.self, offset: offset)
                switch UInt32(loadCommand.cmd) {
                case LC_REEXPORT_DYLIB, LC_LOAD_WEAK_DYLIB, LC_LOAD_UPWARD_DYLIB, UInt32(LC_LOAD_DYLIB):
                    let dylibCommand = newbinary.extract(dylib_command.self, offset: offset)
                    if String.init(data: newbinary,
                                   offset: offset,
                                   commandSize: Int(dylibCommand.cmdsize),
                                   loadCommandString: dylibCommand.dylib.name) == dylibPath {
                        start = offset
                        size = Int(dylibCommand.cmdsize)

                        header.ncmds -= 1
                        header.sizeofcmds -= UInt32(dylibCommand.cmdsize)

                        newHeaderData = Data(bytes: &header, count: MemoryLayout<mach_header>.size)
                        machoRange = 0..<MemoryLayout<mach_header>.size
                    }
                default:
                    break
                }
                offset += Int(loadCommand.cmdsize)
            }
            end = offset
        } else {
            var header = newbinary.extract(mach_header_64.self)
            var offset = MemoryLayout.size(ofValue: header)
            for _ in 0..<header.ncmds {
                let loadCommand = binary.extract(load_command.self, offset: offset)
                switch UInt32(loadCommand.cmd) {
                case LC_REEXPORT_DYLIB, LC_LOAD_WEAK_DYLIB, LC_LOAD_UPWARD_DYLIB, UInt32(LC_LOAD_DYLIB):
                    let dylibCommand = newbinary.extract(dylib_command.self, offset: offset)
                    if String.init(data: newbinary,
                                   offset: offset,
                                   commandSize: Int(dylibCommand.cmdsize),
                                   loadCommandString: dylibCommand.dylib.name) == dylibPath {
                        start = offset
                        size = Int(dylibCommand.cmdsize)

                        header.ncmds -= 1
                        header.sizeofcmds -= UInt32(dylibCommand.cmdsize)

                        newHeaderData = Data(bytes: &header, count: MemoryLayout<mach_header_64>.size)
                        machoRange = 0..<MemoryLayout<mach_header_64>.size
                    }
                default:
                    break
                }
                offset += Int(loadCommand.cmdsize)
            }
            end = offset
        }

        if let start = start,
           let end = end,
           let size = size,
           let machoRange = machoRange,
           let newHeaderData = newHeaderData {
            var commandData = newbinary.subdata(in: start + size..<end)
            commandData.append(Data(count: size))

            newbinary.replaceSubrange(start..<end, with: commandData)
            newbinary.replaceSubrange(machoRange, with: newHeaderData)
        }

        handle(newbinary)
    }
}
