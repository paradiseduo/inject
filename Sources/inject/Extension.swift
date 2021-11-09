//
//  File.swift
//  
//
//  Created by paradiseduo on 2021/9/10.
//

import Foundation

extension Data {
    func extract<T>(_ type: T.Type, offset: Int = 0) -> T {
        let data = self[offset..<offset + MemoryLayout<T>.size]
        return data.withUnsafeBytes { dataBytes in
            dataBytes.baseAddress!.assumingMemoryBound(to: UInt8.self).withMemoryRebound(to: T.self, capacity: 1) { (p) -> T in
                return p.pointee
            }
        }
    }
}

extension String {
    init(_ rawCString: (Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8)) {
        var rawCString = rawCString
        let rawCStringSize = MemoryLayout.size(ofValue: rawCString)
        let string = withUnsafePointer(to: &rawCString) { (pointer) -> String in
            return pointer.withMemoryRebound(to: UInt8.self, capacity: rawCStringSize, {
                return String(cString: $0)
            })
        }
        self.init(string)
    }
    
    init(data: Data, offset: Int, commandSize: Int, loadCommandString: lc_str) {
        let loadCommandStringOffset = Int(loadCommandString.offset)
        let stringOffset = offset + loadCommandStringOffset
        let length = commandSize - loadCommandStringOffset
        self = String(data: data[stringOffset..<(stringOffset + length)], encoding: .utf8)!.trimmingCharacters(in: .controlCharacters)
    }
}

extension FileManager {
    static func open(machoPath: String, dylibPath:String, handle: (Data?)->()) {
        do {
            if FileManager.default.fileExists(atPath: machoPath) {
                if FileManager.default.fileExists(atPath: dylibPath) {
                    let backUpPath = "./\(machoPath.components(separatedBy: "/").last!)_back"
                    if FileManager.default.fileExists(atPath: backUpPath) {
                        try FileManager.default.removeItem(atPath: backUpPath)
                    }
                    try FileManager.default.copyItem(atPath: machoPath, toPath: backUpPath)
                    print("Backup machO file \(backUpPath)")
                    let data = try Data(contentsOf: URL(fileURLWithPath: machoPath))
                    handle(data)
                } else {
                    print("dylib file not exist !")
                    handle(nil)
                }
            } else {
                print("MachO file not exist !")
                handle(nil)
            }
        } catch let err {
            print(err)
            handle(nil)
        }
    }
    
    static func open(machoPath: String, handle: (Data?)->()) {
        do {
            if FileManager.default.fileExists(atPath: machoPath) {
                let backUpPath = "./\(machoPath.components(separatedBy: "/").last!)_back"
                if FileManager.default.fileExists(atPath: backUpPath) {
                    try FileManager.default.removeItem(atPath: backUpPath)
                }
                try FileManager.default.copyItem(atPath: machoPath, toPath: backUpPath)
                print("Backup machO file \(backUpPath)")
                let data = try Data(contentsOf: URL(fileURLWithPath: machoPath))
                handle(data)
            } else {
                print("MachO file not exist !")
                handle(nil)
            }
        } catch let err {
            print(err)
            handle(nil)
        }
    }
}
