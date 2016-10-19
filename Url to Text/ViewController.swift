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

class ViewController : UIViewController, UITableViewDelegate, UITableViewDataSource, AVCapturePhotoCaptureDelegate {
    
    @IBOutlet var errorView: UIView?
    @IBOutlet var errorLabel: UILabel?
    @IBOutlet var errorButton: UIButton?
    @IBOutlet var previewView: UIView?
    @IBOutlet var historyView: UITableView?
    
    let captureSession = AVCaptureSession()
    let photoOutput = AVCapturePhotoOutput()
    let tesseract = G8Tesseract(language: "eng")
    
    var isProcessingImage = false
    var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
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
        
        DispatchQueue.global().async {
            self.captureSession.stopRunning()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        switch UIDevice.current.orientation {
        case .portrait:
            previewLayer?.connection.videoOrientation = .portrait
            for conn in photoOutput.connections {
                guard let connection = conn as? AVCaptureConnection else {
                    continue
                }
                
                connection.videoOrientation = .portrait
            }
            break
        case .landscapeLeft:
            previewLayer?.connection.videoOrientation = .landscapeRight
            for conn in photoOutput.connections {
                guard let connection = conn as? AVCaptureConnection else {
                    continue
                }
                
                connection.videoOrientation = .landscapeRight
            }
            break
        case .landscapeRight:
            previewLayer?.connection.videoOrientation = .landscapeLeft
            for conn in photoOutput.connections {
                guard let connection = conn as? AVCaptureConnection else {
                    continue
                }
                
                connection.videoOrientation = .landscapeLeft
            }
            break
        case .portraitUpsideDown:
            previewLayer?.connection.videoOrientation = .portraitUpsideDown
            for conn in photoOutput.connections {
                guard let connection = conn as? AVCaptureConnection else {
                    continue
                }
                
                connection.videoOrientation = .portraitUpsideDown
            }
            break
        default:
            previewLayer?.connection.videoOrientation = .portrait
            for conn in photoOutput.connections {
                guard let connection = conn as? AVCaptureConnection else {
                    continue
                }
                
                connection.videoOrientation = .portrait
            }
            break
        }
        
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
        errorLabel?.text = "Your access to the camera is restricted"
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
        do {
            let camera = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
            let input = try AVCaptureDeviceInput(device: camera)
            
            camera?.addObserver(self, forKeyPath: "adjustingFocus", options: .new, context: nil)
            
            captureSession.beginConfiguration()

            captureSession.sessionPreset = AVCaptureSessionPreset640x480
            captureSession.addInput(input)
            captureSession.addOutput(photoOutput)
            
            captureSession.commitConfiguration()
        } catch {
            NSLog("error...")
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
        previewLayer!.videoGravity = AVLayerVideoGravityResizeAspectFill
        
        captureSession.startRunning()
        
        DispatchQueue.main.async {
            self.previewView!.layer.addSublayer(self.previewLayer!)
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
    
    // Mark -- Analize on refocus
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "adjustingFocus" {
            let isAdjustingFocus:Bool = change![.newKey] as! Int == 1
            if !isAdjustingFocus && !isProcessingImage {
                let availableFormats = photoOutput.availablePhotoPixelFormatTypes

                photoOutput.capturePhoto(
                    with: AVCapturePhotoSettings(
                        format: [kCVPixelBufferPixelFormatTypeKey as String : availableFormats[availableFormats.count-1]]),
                    delegate: self)
            }
        }
    }
    
    // Mark -- AVCapturePhotoCaptureDelegate
    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {
        print("captured....")

        isProcessingImage = true
        
        if photoSampleBuffer != nil {
            let cropRect = self.previewLayer?.metadataOutputRectOfInterest(for: self.previewLayer!.bounds)
            let image = photoSampleBuffer?.imageRepresentation(croppedTo: cropRect!)

            tesseract?.engineMode = .tesseractCubeCombined
            tesseract?.image = image?.g8_blackAndWhite()
            tesseract?.recognize()

            print(tesseract!.recognizedText)
            
            UIImageWriteToSavedPhotosAlbum(image!, nil, nil, nil)
        }
        
        isProcessingImage = false
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

extension CMSampleBuffer {
    func imageRepresentation(croppedTo:CGRect) -> UIImage {
        let imageBuffer = CMSampleBufferGetImageBuffer(self)!
        
//        let coreImage = CIImage(cvPixelBuffer: imageBuffer)
//        let croppedImage = coreImage.cropping(to: croppedTo)
//        let resultImage = UIImage(ciImage: croppedImage)
        
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        let address = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let bitmapInfo = CGBitmapInfo(rawValue: (CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) as UInt32)
        
        let context = CGContext(data: address, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)!
        let fullRef = context.makeImage()!
        
        let originalSize : CGSize
        let orientation: UIImageOrientation
        let metaRect = croppedTo
        
        switch UIDevice.current.orientation {
        case .landscapeRight:
            orientation = .right
            originalSize = CGSize(width: height, height: width)
            break
        case .landscapeLeft:
            orientation = .left
            originalSize = CGSize(width: height, height: width)
            break
        case .portraitUpsideDown:
            orientation = .down
            originalSize = CGSize(width: width, height: height)
            break
        case .portrait:
            fallthrough
       default:
            orientation = .right
            originalSize = CGSize(width: width, height: height)
        }

        
        let cropRect = CGRect(x: metaRect.origin.x * originalSize.width,
                              y: metaRect.origin.y * originalSize.height,
                              width: metaRect.size.width * originalSize.width,
                              height: metaRect.size.height * originalSize.height)
        
        let imageRef = fullRef.cropping(to: cropRect)!
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        let resultImage = UIImage(cgImage: imageRef, scale: 1, orientation: orientation)
        
        return resultImage
    }
}

