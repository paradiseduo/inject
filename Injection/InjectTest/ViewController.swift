//
//  ViewController.swift
//  InjectTest
//
//  Created by paradiseduo on 2022/12/6.
//

import Cocoa
import Injection

class ViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        Inject.injectMachO(machoPath: "/Users/admin/Desktop/Code/inject/inject", cmdType: LC_Type.LOAD_DYLIB, backup: false, injectPath: "@executable_path/testMac/libtestinject.dylib") { result in
            if result {
                Shell.run("otool -L /Users/admin/Desktop/Code/inject/inject") { code, str in
                    print(str)
                    Inject.removeMachO(machoPath: "/Users/admin/Desktop/Code/inject/inject", cmdType: LC_Type.LOAD_DYLIB, backup: false, injectPath: "@executable_path/testMac/libtestinject.dylib") { result in
                        Shell.run("otool -L /Users/admin/Desktop/Code/inject/inject") { code2, str2 in
                            print(str2)
                        }
                    }
                }
            }
        }
        
        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

