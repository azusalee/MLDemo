//
//  ViewController.swift
//  MLDemo
//
//  Created by lizihong on 2020/8/13.
//  Copyright © 2020 kinshun. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    @IBAction func gotoScan(_ sender: Any) {
        let controller = MLScanViewController()
        controller.modalPresentationStyle = .fullScreen
        self.present(controller, animated: true, completion: nil)
    }
    
}

