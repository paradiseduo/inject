//
//  Inject.swift
//  Injection
//
//  Created by paradiseduo on 2022/12/6.
//

import Foundation

public struct Inject {
    public static func injectIPA(ipaPath: String, cmdType: LC_Type, injectPath: String, finishHandle:(Bool)->()) {
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
        Shell.run("unzip -o \(ipaPath) -d \(targetUrl)") { t1, o1 in
            if t1 == 0 {
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
                    
                    try FileManager.default.createDirectory(atPath: "\(appPath)/Inject/", withIntermediateDirectories: true, attributes: nil)
                    try FileManager.default.moveItem(atPath: iPath, toPath: "\(appPath)/Inject/\(iName)")
                    
                    injectMachO(machoPath: machoPath, cmdType: cmdType, backup: false, injectPath: injectPathNew) { success in
                        if success {
                            Shell.run("zip -r \(ipaPath) \(payload)") { t2, o2 in
                                if t2 == 0 {
                                    print("Inject \(injectPath) finish, new IPA file is \(ipaPath)")
                                    result = true
                                } else {
                                    print("\(o2)")
                                }
                            }
                        }
                    }
                    try FileManager.default.removeItem(atPath: payload)
                } catch let e {
                    print("\(e)")
                }
            } else {
                print("\(o1)")
            }
        }
        finishHandle(result)
    }
    
    public static func removeIPA(ipaPath: String, cmdType: LC_Type, injectPath: String, finishHandle:(Bool)->()) {
        var result = false
        let targetUrl = "."
        Shell.run("unzip -o \(ipaPath) -d \(targetUrl)") { t1, o1 in
            if t1 == 0 {
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
                    removeMachO(machoPath: machoPath, cmdType: cmdType, backup: false, injectPath: injectPath) { success in
                        if success {
                            Shell.run("zip -r \(ipaPath) \(payload)") { t2, o2 in
                                if t2 == 0 {
                                    print("Remove \(injectPath) finish, new IPA file is \(ipaPath)")
                                    result = true
                                } else {
                                    print("\(o2)")
                                }
                            }
                        }
                    }
                    try FileManager.default.removeItem(atPath: payload)
                } catch let e {
                    print("\(e)")
                }
            } else {
                print("\(o1)")
            }
        }
        finishHandle(result)
    }
    
    public static func removeMachO(machoPath: String, cmdType: LC_Type, backup: Bool, injectPath: String, finishHandle:(Bool)->()) {
        let cmd_type = LC_Type.get(cmdType.rawValue)
        var result = false
        FileManager.open(machoPath: machoPath, backup: backup) { data in
            if let binary = data {
                let fh = binary.extract(fat_header.self)
                BitType.checkType(machoPath: machoPath, header: fh) { type, isByteSwapped  in
                    if injectPath.count > 0 {
                        LoadCommand.remove(binary: binary, dylibPath: injectPath, cmd: cmd_type, type: type) { newBinary in
                            result = Inject.writeFile(newBinary: newBinary, machoPath: machoPath, successTitle: "Remove \(injectPath) Finish", failTitle: "Remove \(injectPath) failed")
                        }
                    } else {
                        print("Need dylib to inject")
                    }
                }
            }
        }
        finishHandle(result)
    }
    
    public static func injectMachO(machoPath: String, cmdType: LC_Type, backup: Bool, injectPath: String, finishHandle:(Bool)->()) {
        let cmd_type = LC_Type.get(cmdType.rawValue)
        var result = false
        FileManager.open(machoPath: machoPath, backup: backup) { data in
            if let binary = data {
                let fh = binary.extract(fat_header.self)
                BitType.checkType(machoPath: machoPath, header: fh) { type, isByteSwapped  in
                    if injectPath.count > 0 {
                        LoadCommand.couldInjectLoadCommand(binary: binary, dylibPath: injectPath, type: type, isByteSwapped: isByteSwapped) { canInject in
                            LoadCommand.inject(binary: binary, dylibPath: injectPath, cmd: cmd_type, type: type, canInject: canInject) { newBinary in
                                result = Inject.writeFile(newBinary: newBinary, machoPath: machoPath, successTitle: "Inject \(injectPath) Finish", failTitle: "Inject \(injectPath) failed")
                            }
                        }
                    } else {
                        print("Need dylib to inject")
                    }
                }
            }
        }
        finishHandle(result)
    }
    
    private static func writeFile(newBinary: Data?, machoPath: String, successTitle: String, failTitle: String) -> Bool {
        if let b = newBinary {
            do {
                try b.write(to: URL(fileURLWithPath: machoPath))
                print(successTitle)
                return true
            } catch let err {
                print(err)
            }
        }
        print(failTitle)
        return false
    }
}
