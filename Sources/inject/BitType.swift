//
//  File.swift
//  
//
//  Created by paradiseduo on 2021/9/10.
//

import Foundation

public enum BitType {
    case x86
    case x64
    case x86_fat
    case x64_fat
    case none
    
    static func checkType(machoPath: String, header: fat_header, handle: (BitType, Bool)->()) {
        switch header.magic {
        case FAT_CIGAM, FAT_MAGIC:
            handle(.x86_fat, header.magic == FAT_CIGAM)
            break
        case FAT_CIGAM_64, FAT_MAGIC_64:
            handle(.x64_fat, header.magic == FAT_CIGAM_64)
            break
        case MH_MAGIC, MH_CIGAM:
            handle(.x86, header.magic == MH_CIGAM)
            break
        case MH_MAGIC_64, MH_CIGAM_64:
            handle(.x64, header.magic == MH_CIGAM_64)
            break
        default:
            print("Unknown MachO header")
            handle(.none, false)
            break
        }
    }
}
