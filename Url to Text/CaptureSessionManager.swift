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

protocol CaptureSessionManagerDelegate {
    func orientation(for captureSessionManager: CaptureSessionManager) -> AVCaptureVideoOrientation
    func filter(for captureSessionManager: CaptureSessionManager) -> ((CIImage) -> CIImage?)?
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
    
    let sessionQueue: DispatchQueue
    
    var filter: ((CIImage) -> CIImage?)?
    var orientation: AVCaptureVideoOrientation!
    
    init(in superview: UIView, with delegate: CaptureSessionManagerDelegate) {
        self.delegate = delegate
        
        orientation = .portrait
        
        displayView = GLKView(frame: superview.bounds, context: EAGLContext(api: .openGLES2))
        displayView.enableSetNeedsDisplay = false
        displayView.frame = superview.bounds
        superview.addSubview(displayView)
        superview.sendSubview(toBack: displayView)
        
        renderContext = CIContext(eaglContext: displayView.context)
        
        sessionQueue = DispatchQueue(label: "AVSessionQueue")
        
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
        superview.addSubview(displayView)
        superview.sendSubview(toBack: displayView)
        
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
        filter = delegate.filter(for: self)
        orientation = delegate.orientation(for: self)
        
        if captureSession == nil {
            captureSession = createCaptureSession()!
        }

        captureSession?.startRunning()
    }
    
    func stopFiltering() {
        captureSession?.stopRunning()
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

    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        let opaqueBuffer = Unmanaged<CVImageBuffer>.passUnretained(imageBuffer).toOpaque()
        let pixelBuffer = Unmanaged<CVPixelBuffer>.fromOpaque(opaqueBuffer).takeUnretainedValue()
        
        let sourceImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        var drawFrame = sourceImage.extent
        let viewAR = displayViewBounds.width / displayViewBounds.height

        drawFrame.origin.y = drawFrame.size.height / 2
        drawFrame.size.height = drawFrame.width / viewAR
        
        var outputImage = sourceImage.cropping(to: drawFrame)
        
        let detectionResult = filter?(outputImage)
        if detectionResult != nil {
            outputImage = detectionResult!
        }

        drawFrame = outputImage.extent
        
        DispatchQueue.main.async {
            self.displayView.bindDrawable()
            if self.displayView.context != EAGLContext.current() {
                EAGLContext.setCurrent(self.displayView.context)
            }
            
//            glClearColor(0.5, 0.5, 0.5, 1.0)
            glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
            
//            glEnable(GLenum(GL_BLEND))
//            glBlendFunc(GLenum(GL_ONE), GLenum(GL_ONE_MINUS_SRC_ALPHA))
            
            self.renderContext.draw(outputImage, in: self.displayViewBounds, from: drawFrame)
        
            self.displayView.display()
        }
    }
}
