//
//  ViewController.swift
//  AdmobManager
//
//  Created by zhouxueyun on 2018/9/29.
//  Copyright © 2018 zhouxueyun. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        AdmobManager.createBannerView(adUnitID: "ca-app-pub-9973066618708289/2508558475", toView: self.view)
        
    }


}

