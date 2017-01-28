//
//  CaptureSessionManager.swift
//  Url to Text
//
//  Created by Tamer Wahba on 10/28/16.
//  Copyright © 2016 Tamer Wahba. All rights reserved.
//

import AVFoundation
import GLKit
import UIKit

enum CaptureSessionManagerFilterMode {
    case passthrough
    case detect
}

protocol CaptureSessionManagerDelegate {
    func orientation(for captureSessionManager: CaptureSessionManager) -> AVCaptureVideoOrientation
    func captureSessionManager(_ captureSessionManager: CaptureSessionManager, didDetectFeature feature:CITextFeature, inImage image: CIImage)
}

class CaptureSessionManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var delegate: CaptureSessionManagerDelegate
    
    private var displayView: GLKView!
    private var displayViewBounds: CGRect!
    private var renderContext: CIContext!
    
    private var inputHeightProportion: CGFloat = 0.9
    
    private var captureSession : AVCaptureSession?
    private var captureDevice: AVCaptureDevice?
    
    private var subjectAreaChangeObserver: NSObjectProtocol?
    private var filter: ((CIImage) -> CIImage?)?
    
    private var mode: CaptureSessionManagerFilterMode = .passthrough
    var filterMode: CaptureSessionManagerFilterMode {
        get {
            return mode
        }
        set {
            switch newValue {
            case .detect:
                filter = detectorFilter
            case .passthrough:
                filter = passthroughFilter
            }
            mode = newValue
        }
    }
    
    let sessionQueue = DispatchQueue(label: "AVSessionQueue")
    let textDetector = CIDetector(ofType: CIDetectorTypeText,
                                  context: nil,
                                  options: [CIDetectorAccuracy: CIDetectorAccuracyLow,
                                            CIDetectorReturnSubFeatures: true,
                                            /*CIDetectorMinFeatureSize: 0.20*/])
    
    var orientation: AVCaptureVideoOrientation!
    
    var outputImage = CIImage()
    
    init(in superview: UIView, with delegate: CaptureSessionManagerDelegate) {
        self.delegate = delegate
        
        orientation = .portrait
        
        displayView = GLKView(frame: superview.bounds, context: EAGLContext(api: .openGLES2))
        displayView.enableSetNeedsDisplay = false
        displayView.frame = superview.bounds
        
        superview.addSubview(self.displayView)
        superview.sendSubview(toBack: self.displayView)
        
        renderContext = CIContext(eaglContext: displayView.context)
        
        displayView.bindDrawable()
        displayViewBounds = CGRect(x: 0, y: 0, width: displayView.drawableWidth, height: displayView.drawableHeight)
    }
    
    deinit {
        stopFiltering()
    }
    
    func redraw(in superview: UIView) {
        guard let captureSession = captureSession else {
            return
        }
        
        self.stopFiltering()
        displayView.removeFromSuperview()
        
        displayView = GLKView(frame: superview.bounds, context: EAGLContext(api: .openGLES2))
        displayView.enableSetNeedsDisplay = false
        displayView.frame = superview.bounds
        
        superview.addSubview(self.displayView)
        superview.sendSubview(toBack: self.displayView)
        
        renderContext = CIContext(eaglContext: displayView.context)

        displayView.bindDrawable()
        displayViewBounds = CGRect(x: 0, y: 0, width: displayView.drawableWidth, height: displayView.drawableHeight)
        
        guard let videoOutput = captureSession.outputs.first(where: {item in return item is AVCaptureVideoDataOutput}) as? AVCaptureVideoDataOutput else {
            return
        }
        let connection =  videoOutput.connection(withMediaType: AVMediaTypeVideo)
        connection?.videoOrientation = orientation

        self.startFiltering()
    }
    
    func startFiltering() {
        sessionQueue.async {
            guard let session = self.createCaptureSession() else {
                return
            }
            
            self.orientation = self.delegate.orientation(for: self)
            
            self.captureSession = session
            self.captureSession?.startRunning()
        }
    }
    
    func stopFiltering() {
        sessionQueue.sync {
            self.captureSession?.stopRunning()
        }
    }
    
    func createCaptureSession() -> AVCaptureSession? {
        do {
            let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
            let input = try AVCaptureDeviceInput(device: device)
            
            captureDevice = device
            
            let session = AVCaptureSession()
            session.sessionPreset = AVCaptureSessionPresetHigh
            
            let videoOutput = AVCaptureVideoDataOutput()
            
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
            
            session.addInput(input)
            session.addOutput(videoOutput)
            
            let connection = videoOutput.connection(withMediaType: AVMediaTypeVideo)
            connection?.videoOrientation = orientation

            return session
        } catch {
            return nil
        }
    }
    
    func passthroughFilter(_ img: CIImage) -> CIImage {
        return img
    }
    
    func detectorFilter(_ img: CIImage) -> CIImage {
        var image = img.applyingGaussianBlur(withSigma: 1.2)
        
        let features = textDetector?.features(in: image).sorted(by: { return $0.bounds.size.width > $1.bounds.size.width})
        for feature in features as! [CITextFeature] {
            
            var overlay = CIImage(color: CIColor(red: 0.24, green: 0.67, blue: 0.87, alpha: 0.5))
            overlay = overlay.cropping(to: image.extent)
            overlay = overlay.applyingFilter("CIPerspectiveTransformWithExtent", withInputParameters: [
                "inputExtent": CIVector(cgRect: image.extent),
                "inputTopLeft": CIVector(cgPoint: feature.topLeft),
                "inputTopRight": CIVector(cgPoint: feature.topRight),
                "inputBottomLeft": CIVector(cgPoint: feature.bottomLeft),
                "inputBottomRight": CIVector(cgPoint: feature.bottomRight)
                ])

            self.delegate.captureSessionManager(self, didDetectFeature: feature, inImage: image)
            
            image = overlay.compositingOverImage(image)
            
            break
        }
        
        return image
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        let opaqueBuffer = Unmanaged<CVImageBuffer>.passUnretained(imageBuffer).toOpaque()
        let pixelBuffer = Unmanaged<CVPixelBuffer>.fromOpaque(opaqueBuffer).takeUnretainedValue()
        
        let sourceImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        var drawFrame = sourceImage.extent
        let viewAR = displayViewBounds.width / displayViewBounds.height

        drawFrame.origin.y = drawFrame.size.height / 2
        drawFrame.size.height = drawFrame.width / viewAR
        
        outputImage = sourceImage.cropping(to: drawFrame)
        
        let detectionResult = filter?(outputImage)
        if detectionResult != nil {
            outputImage = detectionResult!
        }

        drawFrame = outputImage.extent
        
        self.displayView.bindDrawable()
        if self.renderContext != EAGLContext.current() {
            EAGLContext.setCurrent(self.displayView.context)
        }
        
//        glClearColor(0.5, 0.5, 0.5, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        
        glEnable(GLenum(GL_BLEND))
        glBlendFunc(GLenum(GL_ONE), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        
        self.renderContext.draw(outputImage, in: self.displayViewBounds, from: drawFrame)
        
        self.displayView.display()
    }
}
