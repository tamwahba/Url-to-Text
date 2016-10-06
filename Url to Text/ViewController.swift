//
//  ViewController.swift
//  Url to Text
//
//  Created by Tamer Wahba on 9/29/16.
//  Copyright © 2016 Tamer Wahba. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController : UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet var previewView: UIView?
    @IBOutlet var historyView: UITableView?
    
    var captureSession = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        do {
            let camera = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
            let input = try AVCaptureDeviceInput(device: camera)

            captureSession.addInput(input)
        } catch {
            NSLog("error...")
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer!.videoGravity = AVLayerVideoGravityResizeAspectFill
        
        previewView!.layer.addSublayer(previewLayer!)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        DispatchQueue.global(qos: .userInteractive).async {
            self.captureSession.startRunning()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        DispatchQueue.global().async {
            self.captureSession.stopRunning()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        switch UIDevice.current.orientation {
        case .portrait:
            previewLayer?.connection.videoOrientation = .portrait
            break
        case .landscapeLeft:
            previewLayer?.connection.videoOrientation = .landscapeRight
            break
        case .landscapeRight:
            previewLayer?.connection.videoOrientation = .landscapeLeft
            break
        case .portraitUpsideDown:
            previewLayer?.connection.videoOrientation = .portraitUpsideDown
            break
        default:
            previewLayer?.connection.videoOrientation = .portrait
            break
        }
        
        previewLayer!.frame = previewView!.bounds
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // Mark -- HistoryTableView
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 10
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "History"
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: "history_cell")!
    }
    

}

