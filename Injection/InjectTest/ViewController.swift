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
        Inject.injectMachO(machoPath: "/Users/admin/Desktop/Code/inject/inject",
                           cmdType: LC_Type.LOAD_DYLIB,
                           backup: false,
                           injectPath: "@executable_path/testMac/libtestinject.dylib") { result in
            if result {
                Shell.run("otool -L /Users/admin/Desktop/Code/inject/inject") { _, output in
                    print(output)
                    Inject.removeMachO(machoPath: "/Users/admin/Desktop/Code/inject/inject",
                                       cmdType: LC_Type.LOAD_DYLIB,
                                       backup: false,
                                       injectPath: "@executable_path/testMac/libtestinject.dylib") { result in
                        Shell.run("otool -L /Users/admin/Desktop/Code/inject/inject") { _, output in
                            print(output)
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

