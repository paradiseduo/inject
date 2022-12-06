//
//  File.swift
//  
//
//  Created by Paradiseduo on 2021/11/28.
//

import Foundation

public struct Shell {
    public static func run(_ command: String, handle:(Int32, String)->()) {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", command]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        task.launch()
        
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: String.Encoding.utf8)
        
        task.waitUntilExit()
        handle(task.terminationStatus, output ?? "")
    }
}
