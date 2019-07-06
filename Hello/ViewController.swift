//
//  ViewController.swift
//  Hello
//
//  Created by bluefish on 2019/7/5.
//  Copyright © 2019 systec. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var domain: UITextField!
    @IBOutlet weak var sipId: UITextField!
    @IBOutlet weak var password: UITextField!
    @IBOutlet weak var status: UILabel!
    
    static var demo:ViewController? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        ViewController.demo = self
    }
    
    @objc(status:) static func stateChange(path: String) {
        ViewController.demo?.status.text = path
    }
    
    @IBAction func onRegister(_ sender: Any) {
        let domain = self.domain.text
        let sipId = self.sipId.text
        let password = self.password.text
        add_account(domain, sipId, password)
    }
    
}

