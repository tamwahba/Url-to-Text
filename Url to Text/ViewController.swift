//
//  ViewController.swift
//  Url to Text
//
//  Created by Tamer Wahba on 9/29/16.
//  Copyright © 2016 Tamer Wahba. All rights reserved.
//

import UIKit

import CameraManager

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let cameraManager = CameraManager()
        cameraManager.cameraOutputMode = .stillImage
        cameraManager.addPreviewLayerToView(self.view)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

