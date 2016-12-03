//
//  ViewController.swift
//  Url to Text
//
//  Created by Tamer Wahba on 9/29/16.
//  Copyright © 2016 Tamer Wahba. All rights reserved.
//

import UIKit
import AVFoundation

import TesseractOCR

class ViewController : UIViewController, UITableViewDelegate, UITableViewDataSource, CaptureSessionManagerDelegate {
    
    @IBOutlet var errorView: UIView?
    @IBOutlet var errorLabel: UILabel?
    @IBOutlet var errorButton: UIButton?
    @IBOutlet var previewView: UIView?
    @IBOutlet var historyView: UITableView?
    
    @IBOutlet var captureButton: UIButton?
    @IBOutlet var captureImage: UIImageView?
    
    let captureSession = AVCaptureSession()
    let photoOutput = AVCapturePhotoOutput()
    let tesseract = G8Tesseract(language: "eng",
                                configDictionary: nil,
                                configFileNames: ["\(Bundle.main.resourcePath!)/tessdata/configs/config"],
                                cachesRelatedDataPath: nil,
                                engineMode: .tesseractCubeCombined)
    
    var sessionManager: CaptureSessionManager? = nil
    
    var isProcessingImage = false
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    let detector = CIDetector(ofType: CIDetectorTypeText,
                              context: nil,
                              options: [CIDetectorAccuracy: CIDetectorAccuracyLow,
                                        CIDetectorReturnSubFeatures: true,
                                        /*CIDetectorMinFeatureSize: 0.20*/])
    var textImage: UIImage!
    var tableData: [String] = []
    
    var detectorContext: CIContext?

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
        
        switch UIDevice.current.orientation {
        case .portrait:
            sessionManager?.orientation = .portrait
        case .landscapeLeft:
            sessionManager?.orientation = .landscapeRight
        case .landscapeRight:
            sessionManager?.orientation = .landscapeLeft
        case .portraitUpsideDown:
            sessionManager?.orientation = .portraitUpsideDown
        default:
            sessionManager?.orientation = .portrait
        }
        
        sessionManager?.redraw(in: previewView!)
        
        if previewLayer != nil {
            previewLayer!.frame = previewView!.bounds
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
    
    // TODO -- Remove this
    @IBAction func capture() {
        sessionManager?.filter = readText
    }
    
    @IBAction func detect() {
        sessionManager?.filter = detectText
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
    
    // Mark -- CaptureSessionManagerDelegate
    func passthrough(_ img: CIImage) -> CIImage {
        return img
    }
    
    func detectText(_ img: CIImage) -> CIImage {
        var image = img.applyingGaussianBlur(withSigma: 1.5)

        let features = detector?.features(in: image)
        for feature in features as! [CITextFeature] {
            
            var overlay = CIImage(color: CIColor(red: 1.0, green: 0, blue: 1.0, alpha: 0.5))
            overlay = overlay.cropping(to: image.extent)
            overlay = overlay.applyingFilter("CIPerspectiveTransformWithExtent", withInputParameters: [
                "inputExtent": CIVector(cgRect: image.extent),
                "inputTopLeft": CIVector(cgPoint: feature.topLeft),
                "inputTopRight": CIVector(cgPoint: feature.topRight),
                "inputBottomLeft": CIVector(cgPoint: feature.bottomLeft),
                "inputBottomRight": CIVector(cgPoint: feature.bottomRight)
                ])
            image = overlay.compositingOverImage(image)
            
            break
        }
        
        return image
    }
    
    func readText(_ img: CIImage) -> CIImage {
        var image = img.applyingGaussianBlur(withSigma: 1.5)
        
        let features = detector?.features(in: image)
        for feature in features as! [CITextFeature] {
            
            var overlay = CIImage(color: CIColor(red: 1.0, green: 0, blue: 0, alpha: 0.5))
            overlay = overlay.cropping(to: image.extent)
            overlay = overlay.applyingFilter("CIPerspectiveTransformWithExtent", withInputParameters: [
                "inputExtent": CIVector(cgRect: image.extent),
                "inputTopLeft": CIVector(cgPoint: feature.topLeft),
                "inputTopRight": CIVector(cgPoint: feature.topRight),
                "inputBottomLeft": CIVector(cgPoint: feature.bottomLeft),
                "inputBottomRight": CIVector(cgPoint: feature.bottomRight)
                ])

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
            
            image = overlay.compositingOverImage(image)

            break
        }
        
        if textImage != nil {
            DispatchQueue.main.async {
                self.captureButton?.isEnabled = false
            }
            
            DispatchQueue.global().async {
                self.tesseract?.engineMode = .tesseractCubeCombined
                self.tesseract?.image = self.textImage
                self.tesseract?.recognize()
                
                print("recognized: \(self.tesseract!.recognizedText)")
                self.tableData.append(self.tesseract!.recognizedText.replacingOccurrences(of: "\n", with: ""))
                
                DispatchQueue.main.async {
                    self.captureImage?.image = self.textImage
                    self.historyView?.reloadData()
                    self.captureButton?.isEnabled = true
                    self.textImage = nil
                }
            }

            sessionManager?.filter = passthrough
        }

        return image
    }
    
    func filter(for captureSessionManager: CaptureSessionManager) -> ((CIImage) -> CIImage?)? {
        return passthrough
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

    // Mark -- HistoryTableView
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableData.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "History"
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "history_cell")!
        cell.textLabel?.text = tableData[indexPath.row]
        return cell
    }
}

