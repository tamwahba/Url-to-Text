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
    
    @IBOutlet var errorView: UIView?
    @IBOutlet var errorLabel: UILabel?
    @IBOutlet var errorButton: UIButton?
    @IBOutlet var previewView: UIView?
    @IBOutlet var historyView: UITableView?
    
    var captureSession = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        errorView?.alpha = 0
        verifyCameraAccess()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        DispatchQueue.global(qos: .userInteractive).async {
            self.captureSession.startRunning()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
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
        
        if previewLayer != nil {
            previewLayer!.frame = previewView!.bounds
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func showAccessError(withButton:Bool = true) {
        errorLabel?.text = "The app needs camera access to see URLs!"
        if withButton {
            errorButton?.alpha = 1
        } else {
            errorButton?.alpha = 0
        }
        UIView.animate(withDuration: 0.45, animations: {
            self.errorView?.alpha = 1
        })
    }
    
    func showRestrictedError() {
        errorLabel?.text = "Your access to the camera is restricted"
        errorButton?.alpha = 0
        UIView.animate(withDuration: 0.45, animations: {
            self.errorView?.alpha = 1
        })
    }
    
    @IBAction func openSettings() {
        guard let settingsURL = URL(string: UIApplicationOpenSettingsURLString) else {
            return
        }
        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL)
        }
    }
    
    // Mark -- Camera
    
    func verifyCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) {
        case .notDetermined:
            showAccessError(withButton: false)
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo,
                                          completionHandler: {_ in
                                            self.verifyCameraAccess()
            })
            break
        case .denied:
            showAccessError()
            break
        case .restricted:
            showRestrictedError()
            break
        case .authorized:
            fallthrough
        default:
            initCamera()
            break
        }
    }
    
    func initCamera() {
        if errorView?.alpha == 1 {
            UIView.animate(withDuration: 0.45, animations: {
                self.errorView?.alpha = 0
            })
        }
        
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

