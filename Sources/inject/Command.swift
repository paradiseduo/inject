//
//  File.swift
//  
//
//  Created by paradiseduo on 2021/9/10.
//

import Foundation
import MachO

let byteSwappedOrder = NXByteOrder(rawValue: 0)

public enum LC_Type: String {
    case REEXPORT_DYLIB = "LC_REEXPORT_DYLIB"
    case LOAD_WEAK_DYLIB = "LC_LOAD_WEAK_DYLIB"
    case LOAD_UPWARD_DYLIB = "LC_LOAD_UPWARD_DYLIB"
    case LOAD_DYLIB = "LC_LOAD_DYLIB"
    
    static func get(_ type: String) -> UInt32 {
        switch type {
        case LC_Type.REEXPORT_DYLIB.rawValue:
            return LC_REEXPORT_DYLIB
        case LC_Type.LOAD_WEAK_DYLIB.rawValue:
            return LC_LOAD_WEAK_DYLIB
        case LC_Type.LOAD_UPWARD_DYLIB.rawValue:
            return LC_LOAD_UPWARD_DYLIB
        case LC_Type.LOAD_DYLIB.rawValue:
            return UInt32(LC_LOAD_DYLIB)
        default:
            return 0
        }
    }
}

public struct LoadCommand {
    public static func couldInjectLoadCommand(binary: Data, dylibPath: String, type: BitType, isByteSwapped: Bool, handle: (Bool)->()) {
        if type == .none {
            handle(false)
            return
        }

        if type == .x86_fat {
            let header = binary.extract(fat_header.self)
            var offset = MemoryLayout.size(ofValue: header)
            for _ in 0..<header.nfat_arch {
                var arch = binary.extract(fat_arch.self, offset: offset)
                if isByteSwapped {
                    swap_fat_arch(&arch, 1, byteSwappedOrder)
                }
                
                var header = binary.extract(mach_header.self, offset: offset)
                if header.magic == MH_MAGIC || header.magic == MH_CIGAM {
                    couldInjectLoadCommandInHeader(binary: binary, dylibPath: dylibPath, type: .x86, isByteSwapped: header.magic == MH_CIGAM, offset: &offset, handle: { canInject in
                        if !canInject {
                            handle(false)
                            return
                        }
                    })
                } else {
                    couldInjectLoadCommandInHeader(binary: binary, dylibPath: dylibPath, type: .x64, isByteSwapped: header.magic == MH_CIGAM_64, offset: &offset, handle: { canInject in
                        if !canInject {
                            handle(false)
                            return
                        }
                    })
                }
            }
            handle(true)
        } else if type == .x64_fat {
            let header = binary.extract(fat_header.self)
            var offset = MemoryLayout.size(ofValue: header)
            for _ in 0..<header.nfat_arch {
                var arch = binary.extract(fat_arch_64.self, offset: offset)
                if isByteSwapped {
                    swap_fat_arch_64(&arch, 1, byteSwappedOrder)
                }

                var header = binary.extract(mach_header.self, offset: offset)
                if header.magic == MH_MAGIC || header.magic == MH_CIGAM {
                    couldInjectLoadCommandInHeader(binary: binary, dylibPath: dylibPath, type: .x86, isByteSwapped: header.magic == MH_CIGAM, offset: &offset, handle: { canInject in
                        if !canInject {
                            handle(false)
                            return
                        }
                    })
                } else {
                    couldInjectLoadCommandInHeader(binary: binary, dylibPath: dylibPath, type: .x64, isByteSwapped: header.magic == MH_CIGAM_64, offset: &offset, handle: { canInject in
                        if !canInject {
                            handle(false)
                            return
                        }
                    })
                }
            }
            handle(true)
        } else {
            var offset = 0
            couldInjectLoadCommandInHeader(binary: binary, dylibPath: dylibPath, type: type, isByteSwapped: isByteSwapped, offset: &offset, handle: { canInject in
                handle(canInject)
            })
        }
    }

    private static func couldInjectLoadCommandInHeader(binary: Data, dylibPath: String, type: BitType, isByteSwapped: Bool, offset: inout Int, handle: (Bool)->()) {
        if type == .x86 {
            let header = binary.extract(mach_header.self, offset: offset)
            offset += MemoryLayout.size(ofValue: header)
            for _ in 0..<header.ncmds {
                let loadCommand = binary.extract(load_command.self, offset: offset)
                switch loadCommand.cmd {
                case LC_REEXPORT_DYLIB, LC_LOAD_UPWARD_DYLIB, LC_LOAD_WEAK_DYLIB, UInt32(LC_LOAD_DYLIB):
                    var command = binary.extract(dylib_command.self, offset: offset)
                    if isByteSwapped {
                        swap_dylib_command(&command, byteSwappedOrder)
                    }
                    let curPath = String(data: binary, offset: offset, commandSize: Int(command.cmdsize), loadCommandString: command.dylib.name)
                    let curName = curPath.components(separatedBy: "/").last
                    if curName == dylibPath || curPath == dylibPath {
                        print("Load command already exists")
                        handle(false)
                        return
                    }
                    break
                default:
                    break
                }
                offset += Int(loadCommand.cmdsize)
            }
        } else {
            let header = binary.extract(mach_header_64.self, offset: offset)
            offset += MemoryLayout.size(ofValue: header)
            for _ in 0..<header.ncmds {
                let loadCommand = binary.extract(load_command.self, offset: offset)
                switch loadCommand.cmd {
                case LC_REEXPORT_DYLIB, LC_LOAD_UPWARD_DYLIB, LC_LOAD_WEAK_DYLIB, UInt32(LC_LOAD_DYLIB):
                    var command = binary.extract(dylib_command.self, offset: offset)
                    if isByteSwapped {
                        swap_dylib_command(&command, byteSwappedOrder)
                    }
                    let curPath = String(data: binary, offset: offset, commandSize: Int(command.cmdsize), loadCommandString: command.dylib.name)
                    let curName = curPath.components(separatedBy: "/").last
                    if curName == dylibPath || curPath == dylibPath {
                        print("Load command already exists")
                        handle(false)
                        return
                    }
                    break
                default:
                    break
                }
                offset += Int(loadCommand.cmdsize)
            }
        }
        handle(true)
    }
    
    public static func inject(binary: Data, dylibPath: String, cmd: UInt32, type: BitType, canInject: Bool, handle: (Data?)->()) {
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
                let header = binary.extract(mach_header.self)
                start = Int(header.sizeofcmds)+Int(MemoryLayout<mach_header>.size)
                end += start
                subData = newbinary[start..<end]
                
                var newheader = mach_header(magic: header.magic, cputype: header.cputype, cpusubtype: header.cpusubtype, filetype: header.filetype, ncmds: header.ncmds+1, sizeofcmds: header.sizeofcmds+UInt32(cmdsize), flags: header.flags)
                newHeaderData = Data(bytes: &newheader, count: MemoryLayout<mach_header>.size)
                machoRange = Range(NSRange(location: 0, length: MemoryLayout<mach_header>.size))!
            } else {
                let header = binary.extract(mach_header_64.self)
                start = Int(header.sizeofcmds)+Int(MemoryLayout<mach_header_64>.size)
                end += start
                subData = newbinary[start..<end]
                
                var newheader = mach_header_64(magic: header.magic, cputype: header.cputype, cpusubtype: header.cpusubtype, filetype: header.filetype, ncmds: header.ncmds+1, sizeofcmds: header.sizeofcmds+UInt32(cmdsize), flags: header.flags, reserved: header.reserved)
                newHeaderData = Data(bytes: &newheader, count: MemoryLayout<mach_header_64>.size)
                machoRange = Range(NSRange(location: 0, length: MemoryLayout<mach_header_64>.size))!
            }
            
            let d = String(data: subData, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters)
            if d != "" && d != nil {
                print("cannot inject payload into \(dylibPath) because there is no room")
                handle(nil)
                return
            }
            
            let dy = dylib(name: lc_str(offset: UInt32(MemoryLayout<dylib_command>.size)), timestamp: 2, current_version: 0, compatibility_version: 0)
            var command = dylib_command(cmd: cmd, cmdsize: UInt32(cmdsize), dylib: dy)
            
            var zero: UInt = 0
            var commandData = Data()
            commandData.append(Data(bytes: &command, count: MemoryLayout<dylib_command>.size))
            commandData.append(dylibPath.data(using: String.Encoding.ascii) ?? Data())
            commandData.append(Data(bytes: &zero, count: padding))
            
            let subrange = Range(NSRange(location: start, length: commandData.count))!
            newbinary.replaceSubrange(subrange, with: commandData)
            
            newbinary.replaceSubrange(machoRange, with: newHeaderData)
            
            handle(newbinary)
        } else {
            handle(nil)
        }
    }
    
    public static func removeSignature(binary: Data, type:BitType, isWeak: Bool, handle: (Data?)->()) {
        if type == .x64_fat || type == .x86_fat || type == .none {
            handle(nil)
            return
        }
        var newbinary = binary
        var OP_SOFT_STRIP = 0x00001337
        if type == .x86 {
            let header = newbinary.extract(mach_header.self)
            var offset = MemoryLayout.size(ofValue: header)
            for _ in 0..<header.ncmds {
                let loadCommand = binary.extract(load_command.self, offset: offset)
                if loadCommand.cmd == UInt32(LC_CODE_SIGNATURE) {
                    let command = binary.extract(linkedit_data_command.self, offset: offset)
                    if isWeak {
                        var newheader = mach_header(magic: header.magic, cputype: header.cputype, cpusubtype: header.cpusubtype, filetype: header.filetype, ncmds: header.ncmds-1, sizeofcmds: header.sizeofcmds-UInt32(MemoryLayout<linkedit_data_command>.size), flags: header.flags)
                        let newHeaderData = Data(bytes: &newheader, count: MemoryLayout<mach_header>.size)

                        newbinary.replaceSubrange(Range(NSRange(location: 0, length: MemoryLayout<mach_header>.size))!, with: newHeaderData)
                        newbinary.replaceSubrange(Range(NSRange(location: offset, length: Int(command.cmdsize)))!, with: Data(count: Int(command.cmdsize)))
                        newbinary.replaceSubrange(Range(NSRange(location: Int(command.dataoff), length: Int(command.datasize)))!, with: Data(count: Int(command.datasize)))
                    } else {
                        newbinary.replaceSubrange(Range(NSRange(location: offset, length: 4))!, with: Data(bytes: &OP_SOFT_STRIP, count: 4))
                    }
                }
                offset += Int(loadCommand.cmdsize)
            }
        } else {
            let header = binary.extract(mach_header_64.self)
            var offset = MemoryLayout.size(ofValue: header)
            for _ in 0..<header.ncmds {
                let loadCommand = binary.extract(load_command.self, offset: offset)
                if loadCommand.cmd == UInt32(LC_CODE_SIGNATURE) {
                    let command = binary.extract(linkedit_data_command.self, offset: offset)
                    if isWeak {
                        var newheader = mach_header_64(magic: header.magic, cputype: header.cputype, cpusubtype: header.cpusubtype, filetype: header.filetype, ncmds: header.ncmds-1, sizeofcmds: header.sizeofcmds-UInt32(MemoryLayout<linkedit_data_command>.size), flags: header.flags, reserved: header.reserved)
                        let newHeaderData = Data(bytes: &newheader, count: MemoryLayout<mach_header_64>.size)

                        newbinary.replaceSubrange(Range(NSRange(location: 0, length: MemoryLayout<mach_header_64>.size))!, with: newHeaderData)
                        newbinary.replaceSubrange(Range(NSRange(location: offset, length: Int(command.cmdsize)))!, with: Data(count: Int(command.cmdsize)))
                        newbinary.replaceSubrange(Range(NSRange(location: Int(command.dataoff), length: Int(command.datasize)))!, with: Data(count: Int(command.datasize)))
                    } else {
                        newbinary.replaceSubrange(Range(NSRange(location: offset, length: 4))!, with: Data(bytes: &OP_SOFT_STRIP, count: 4))
                    }
                }
                offset += Int(loadCommand.cmdsize)
            }
        }
        handle(newbinary)
    }
    
    public static func removeASLR(binary: Data, type:BitType, handle: (Data?)->()) {
        if type == .x64_fat || type == .x86_fat || type == .none {
            handle(nil)
            return
        }
        var newbinary = binary
        if type == .x86 {
            var header = newbinary.extract(mach_header.self)
            if (header.flags & UInt32(MH_PIE)) != 0 {
                header.flags &= 0xFFDFFFFF
                newbinary.replaceSubrange(Range(NSRange(location: 0, length: MemoryLayout<mach_header>.size))!, with: Data(bytes: &header, count: MemoryLayout<mach_header>.size))
            } else {
                handle(nil)
                return
            }
        } else {
            var header = binary.extract(mach_header_64.self)
            if (header.flags & UInt32(MH_PIE)) != 0 {
                header.flags &= 0xFFDFFFFF
                newbinary.replaceSubrange(Range(NSRange(location: 0, length: MemoryLayout<mach_header_64>.size))!, with: Data(bytes: &header, count: MemoryLayout<mach_header_64>.size))
            } else {
                handle(nil)
                return
            }
        }
        handle(newbinary)
    }
    
    public static func remove(binary: Data, dylibPath: String, cmd: UInt32, type:BitType, handle: (Data?)->()) {
        if type == .x64_fat || type == .x86_fat || type == .none {
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
            var newheader: mach_header
            let header = newbinary.extract(mach_header.self)
            var offset = MemoryLayout.size(ofValue: header)
            for _ in 0..<header.ncmds {
                let loadCommand = binary.extract(load_command.self, offset: offset)
                switch UInt32(loadCommand.cmd) {
                case LC_REEXPORT_DYLIB, LC_LOAD_WEAK_DYLIB, LC_LOAD_UPWARD_DYLIB, UInt32(LC_LOAD_DYLIB):
                    let dylib_command = newbinary.extract(dylib_command.self, offset: offset)
                    if String.init(data: newbinary, offset: offset, commandSize: Int(dylib_command.cmdsize), loadCommandString: dylib_command.dylib.name) == dylibPath {
                        start = offset
                        size = Int(dylib_command.cmdsize)
                        newheader = mach_header(magic: header.magic, cputype: header.cputype, cpusubtype: header.cpusubtype, filetype: header.filetype, ncmds: header.ncmds-1, sizeofcmds: header.sizeofcmds-UInt32(dylib_command.cmdsize), flags: header.flags)
                        newHeaderData = Data(bytes: &newheader, count: MemoryLayout<mach_header>.size)
                        machoRange = Range(NSRange(location: 0, length: MemoryLayout<mach_header>.size))!
                    }
                default:
                    break
                }
                offset += Int(loadCommand.cmdsize)
            }
            end = offset
        } else {
            var newheader: mach_header_64
            let header = newbinary.extract(mach_header_64.self)
            var offset = MemoryLayout.size(ofValue: header)
            for _ in 0..<header.ncmds {
                let loadCommand = binary.extract(load_command.self, offset: offset)
                switch UInt32(loadCommand.cmd) {
                case LC_REEXPORT_DYLIB, LC_LOAD_WEAK_DYLIB, LC_LOAD_UPWARD_DYLIB, UInt32(LC_LOAD_DYLIB):
                    let dylib_command = newbinary.extract(dylib_command.self, offset: offset)
                    if String.init(data: newbinary, offset: offset, commandSize: Int(dylib_command.cmdsize), loadCommandString: dylib_command.dylib.name) == dylibPath {
                        start = offset
                        size = Int(dylib_command.cmdsize)
                        newheader = mach_header_64(magic: header.magic, cputype: header.cputype, cpusubtype: header.cpusubtype, filetype: header.filetype, ncmds: header.ncmds-1, sizeofcmds: header.sizeofcmds-UInt32(dylib_command.cmdsize), flags: header.flags, reserved: header.reserved)
                        newHeaderData = Data(bytes: &newheader, count: MemoryLayout<mach_header_64>.size)
                        machoRange = Range(NSRange(location: 0, length: MemoryLayout<mach_header_64>.size))!
                    }
                default:
                    break
                }
                offset += Int(loadCommand.cmdsize)
            }
            end = offset
        }
        
        if let s = start, let e = end, let si = size, let mr = machoRange, let nh = newHeaderData {
            let subrangeNew = Range(NSRange(location: s+si, length: e-s-si))!
            let subrangeOld = Range(NSRange(location: s, length: e-s))!
            var zero: UInt = 0
            var commandData = Data()
            commandData.append(newbinary.subdata(in: subrangeNew))
            commandData.append(Data(bytes: &zero, count: si))

            newbinary.replaceSubrange(subrangeOld, with: commandData)
            newbinary.replaceSubrange(mr, with: nh)
        }
        
        handle(newbinary)
    }
}
