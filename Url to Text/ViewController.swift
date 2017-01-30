//
//  ViewController.swift
//  Url to Text
//
//  Created by Tamer Wahba on 9/29/16.
//  Copyright © 2016 Tamer Wahba. All rights reserved.
//

import UIKit
import AVFoundation

import RealmSwift
import TesseractOCR

class ViewController : UIViewController, CaptureSessionManagerDelegate {
    
    @IBOutlet var errorView: UIView?
    @IBOutlet var errorLabel: UILabel?
    @IBOutlet var errorButton: UIButton?
    @IBOutlet var previewView: UIView?
    @IBOutlet var historyView: UIView?
    @IBOutlet var toolBar: UIToolbar?
    @IBOutlet var leftBarItem: UIBarButtonItem?
    @IBOutlet var statusLabel: UILabel?
    @IBOutlet var rightBarItem: UIBarButtonItem?
    
    @IBOutlet var captureButton: UIButton?
    @IBOutlet var captureImage: UIImageView?
        
    let tesseract = G8Tesseract(language: "eng",
                                configDictionary: nil,
                                configFileNames: ["\(Bundle.main.resourcePath!)/tessdata/configs/config"],
                                cachesRelatedDataPath: nil,
                                engineMode: .tesseractCubeCombined)
    
    var sessionManager: CaptureSessionManager? = nil
    
    var shouldReadText = false
    
    var detectorContext: CIContext?
    var textImage: UIImage!

    let realm = try! Realm()
    let history = try! Realm().objects(DetectedURL.self).sorted(byProperty: "date", ascending: false)
    var notificationToken: NotificationToken?
    
    var isStatusBarHidden = false
    override var prefersStatusBarHidden: Bool {
        get {
            return isStatusBarHidden
        }
    }
    
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        get {
            return .slide
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        sessionManager = CaptureSessionManager(in: previewView!, with: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        errorView?.isHidden = true
        DispatchQueue.global().async {
            self.verifyCameraAccess()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        var newOrientaion: AVCaptureVideoOrientation = .portrait
        
        switch UIDevice.current.orientation {
        case .portrait:
            newOrientaion = .portrait
        case .landscapeLeft:
            newOrientaion = .landscapeRight
        case .landscapeRight:
            newOrientaion = .landscapeLeft
        case .portraitUpsideDown:
            newOrientaion = .portraitUpsideDown
        default:
            newOrientaion = .portrait
        }
        
        if newOrientaion != sessionManager?.orientation {
            sessionManager?.orientation = newOrientaion
            sessionManager?.redraw(in: previewView!)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        print("MEMORY WARNING")
    }
    
    func showAccessError(withButton:Bool = true) {
        errorLabel?.text = "The app needs camera access to see URLs!"
        errorButton?.isHidden = !withButton

        errorView?.alpha = 0
        errorView?.isHidden = false
        
        DispatchQueue.main.async {
            self.view.layoutIfNeeded()
            UIView.animate(withDuration: 0.45,
                           animations: {
                            self.errorView?.alpha = 1
                            
            })
        }
    }
    
    func showRestrictedError() {
        errorLabel?.text = "Your access to the camera is restricted."
        errorButton?.isHidden = true

        errorView?.alpha = 0
        errorView?.isHidden = false
        
        DispatchQueue.main.async {
            self.view.layoutIfNeeded()
            UIView.animate(withDuration: 0.45,
                           animations: {
                            self.errorView?.alpha = 1
            })
        }
    }
    
    // Mark: - Actions

    @IBAction func capture() {
        showMessage("Reading text...")
        shouldReadText = true
    }
    
    @IBAction func detect() {
        sessionManager?.filterMode = .detect
        showMessage("Detecting text, release to read")
    }
    
    @IBAction func openSettings() {
        guard let settingsURL = URL(string: UIApplicationOpenSettingsURLString) else {
            return
        }
        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL)
        }
    }
    
    @IBAction func share() {
        showMessage("Select item to share")
        hidePreviewView()
        if let historyController = childViewControllers.first(where: { return $0 is HistoryTableViewController }) as? HistoryTableViewController {
            historyController.isShareModeActive = true
        }
        if var items = toolBar?.items, let itemIndex = items.index(of: leftBarItem!) {
            leftBarItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(finishShare))
            items[itemIndex] = leftBarItem!
            
            toolBar?.setItems(items, animated: true)
        }
    }
    
    @IBAction func finishShare() {
        showMessage("Tap and hold to detect text, release to analyze")
        showPreviewView()
        if let historyController = childViewControllers.first(where: { return $0 is HistoryTableViewController }) as? HistoryTableViewController {
            historyController.isShareModeActive = false
        }
        if var items = toolBar?.items, let itemIndex = items.index(of: leftBarItem!) {
            leftBarItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(share))
            items[itemIndex] = leftBarItem!
            
            toolBar?.setItems(items, animated: true)
        }
    
    }

    
    // Mark: - Camera
    
    func verifyCameraAccess() {
        switch AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) {
        case .notDetermined:
            showAccessError(withButton: false)
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo,
                                          completionHandler: {
                                            granted in
                                            if granted {
                                                self.initCamera()
                                            } else {
                                                self.showAccessError()
                                            }
            })
        case .denied:
            showAccessError()
        case .restricted:
            showRestrictedError()
        case .authorized:
            fallthrough
        default:
            initCamera()
        }
    }
    
    func initCamera() {
        
        sessionManager?.startFiltering()
        
        DispatchQueue.main.async {
            self.view.setNeedsLayout()
            
            if !self.errorView!.isHidden {
                self.previewView?.alpha = 0
                
                self.view.layoutIfNeeded()
                UIView.animate(withDuration: 0.45,
                               animations: {
                                self.errorView?.alpha = 0
                                self.previewView?.alpha = 1
                    },
                               completion: {_ in
                                self.errorView?.isHidden = true
                })
            }
            
        }
    }
    
    // Mark: - CaptureSessionManagerDelegate
    
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didDetectFeature feature: CITextFeature, inImage image: CIImage) {
        if !shouldReadText {
            return
        }
        shouldReadText = false
        captureSessionManager.filterMode = .passthrough
        
        if detectorContext == nil {
            detectorContext = CIContext()
        }
        
        var topLeft = feature.topLeft
        var topRight = feature.topRight
        var bottomLeft = feature.bottomLeft
        var bottomRight = feature.bottomRight
        
        // adjust region
        topLeft.x -= 10
        topLeft.y += 10
        topRight.x += 10
        topRight.y += 10
        bottomLeft.x -= 10
        bottomLeft.y -= 10
        bottomRight.x += 10
        bottomRight.y -= 10
        
        let corrected = image.applyingFilter("CIPerspectiveCorrection", withInputParameters: [
            "inputImage": image,
            "inputTopLeft": CIVector(cgPoint: topLeft),
            "inputTopRight": CIVector(cgPoint: topRight),
            "inputBottomLeft": CIVector(cgPoint: bottomLeft),
            "inputBottomRight": CIVector(cgPoint: bottomRight)
            ])
        
        textImage = UIImage(cgImage: detectorContext!.createCGImage(corrected, from: corrected.extent)!)
        
        if textImage != nil {
            DispatchQueue.main.async {
                self.captureButton?.isEnabled = false
            }
            
            DispatchQueue.global().async {
                self.tesseract?.engineMode = .tesseractCubeCombined
                self.tesseract?.image = self.textImage
                self.tesseract?.recognize()
                
                let text = self.tesseract!.recognizedText.replacingOccurrences(of: "\n", with: "")
                
                print("recognized: \(text)")
                let url = DetectedURL(text)
                let realm = try! Realm()
                try! realm.write {
                    realm.add(url)
                }
                
                DispatchQueue.main.async {
                    self.captureImage?.image = self.textImage
                    self.captureButton?.isEnabled = true
                    self.textImage = nil
                }
                
                self.showMessage("Detected: \(text)")
            }
        }
    }
    
    func orientation(for captureSessionManager: CaptureSessionManager) -> AVCaptureVideoOrientation {
        var orientation: AVCaptureVideoOrientation = .portrait
        
        switch UIDevice.current.orientation {
        case .portrait:
            orientation = .portrait
        case .landscapeLeft:
            orientation = .landscapeRight
        case .landscapeRight:
            orientation = .landscapeLeft
        case .portraitUpsideDown:
            orientation = .portraitUpsideDown
        default:
            orientation = .portrait
        }
        
        return orientation
    }
    
    // Mark: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let tableViewController = segue.destination as? HistoryTableViewController {
            tableViewController.tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: self.toolBar!.bounds.height, right: 0)
            tableViewController.tableView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: self.toolBar!.bounds.height, right: 0)
        }
        
    }
    
    // Mark: - Helpers

    func showMessage(_ message: String) {
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.4,
                           animations: {
                            self.statusLabel?.alpha = 0
            },
                           completion: {_ in
                            self.statusLabel?.text = message
                            UIView.animate(withDuration: 0.2, animations: {
                                self.statusLabel?.alpha = 1
                            })
            })
        }
    }
    
    func hidePreviewView() {
        let newConstraint = NSLayoutConstraint(item: self.historyView!,
                                               attribute: .top,
                                               relatedBy: .equal,
                                               toItem: self.view,
                                               attribute: .top,
                                               multiplier: 1,
                                               constant: 0)
        newConstraint.identifier = "historyView_top"
        
        self.view.constraints.first(where: { return $0.identifier == "historyView_top" })?.isActive = false
        newConstraint.isActive = true
        
        if let buttonConstraint = self.view.constraints.first(where: { return $0.identifier == "captureButton_trailing" }) {
            buttonConstraint.constant += (buttonConstraint.firstItem as! UIButton).frame.width + (buttonConstraint.constant * -2)
        }
        
        isStatusBarHidden = true
        
        UIView.animate(withDuration: 0.6,
                       delay: 0,
                       usingSpringWithDamping: 0.5,
                       initialSpringVelocity: 0,
                       options: [],
                       animations: {
                        self.view.layoutIfNeeded()
                        self.setNeedsStatusBarAppearanceUpdate()
        },
                       completion: nil)
    }
    
    func showPreviewView() {
        let newConstraint = NSLayoutConstraint(item: self.historyView!,
                                               attribute: .top,
                                               relatedBy: .equal,
                                               toItem: self.previewView,
                                               attribute: .bottom,
                                               multiplier: 1,
                                               constant: 0)
        newConstraint.identifier = "historyView_top"
        
        self.view.constraints.first(where: { return $0.identifier == "historyView_top" })?.isActive = false
        newConstraint.isActive = true
        
        if let buttonConstraint = self.view.constraints.first(where: { return $0.identifier == "captureButton_trailing" }) {
            buttonConstraint.constant = (buttonConstraint.constant - (buttonConstraint.firstItem as! UIButton).frame.width) * -1
        }
        
        isStatusBarHidden = false
        
        UIView.animate(withDuration: 0.6,
                       delay: 0,
                       usingSpringWithDamping: 0.5,
                       initialSpringVelocity: 0,
                       options: [],
                       animations: {
                        self.view.layoutIfNeeded()
                        self.setNeedsStatusBarAppearanceUpdate()
        },
                       completion: nil)
    }
}

