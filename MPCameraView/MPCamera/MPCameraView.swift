//
//  MPCameraView.swift
//  MPCameraView
//
//  Created by Mathias Palm on 2017-06-12.
//  Copyright © 2017 mathiaspalm.me. All rights reserved.
//

import UIKit
import AVFoundation
import GLKit

enum MPCameraImageFilter {
    case blackAndWhite
    case normal
}

class MPCameraView: UIView {
    
    static let rectagleDetector = CIDetector(ofType: CIDetectorTypeRectangle, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    var glkView: GLKView?
    var coreImageContext: CIContext?
    var context: EAGLContext?
    var renderBuffer: GLuint = 0
    
    var lastDetectedRectagle: CIRectangleFeature?
    var detectionConfidence = 0.0
    var detectedFrame = true
    
    var borderColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.5)

    var imageFilter: MPCameraImageFilter = .normal {
        didSet {
            if let glkView = glkView {
                let effect = UIBlurEffect(style: .dark)
                let effectView = UIVisualEffectView(effect: effect)
                effectView.frame = self.bounds
                insertSubview(effectView, aboveSubview: glkView)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(Int64(0.25 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) {
                    effectView.removeFromSuperview()
                }
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
}

extension MPCameraView {
    func setupCamera() {
        setupGLK()
        
        captureSession = AVCaptureSession()
        
        let captureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        let input: AVCaptureDeviceInput
        
        do {
            input = try AVCaptureDeviceInput(device: captureDevice)
        } catch {
            return
        }
        
        guard captureSession.canAddInput(input) else {
            return
        }
        captureSession.addInput(input)
        captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        guard captureSession.canAddOutput(metadataOutput) else {
            return
        }
        
        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        captureSession.addOutput(metadataOutput)

        let dataOutput = AVCaptureVideoDataOutput()
        
        guard captureSession.canAddOutput(dataOutput) else {
            return
        }
        dataOutput.alwaysDiscardsLateVideoFrames = true
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
        captureSession.addOutput(dataOutput)
        
        if let connection = dataOutput.connections.first as? AVCaptureConnection {
            connection.videoOrientation = .portrait
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = layer.bounds
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        
        layer.addSublayer(previewLayer)
        bringSubview(toFront: glkView!)
        
        captureSession.startRunning()
    }
}

extension MPCameraView {
    func setupGLK() {
        guard context == nil else {
            return
        }
        
        context = EAGLContext(api: .openGLES2)
        glkView = GLKView(frame: bounds, context: context!)
        glkView?.autoresizingMask = ([.flexibleWidth, .flexibleHeight])
        glkView?.translatesAutoresizingMaskIntoConstraints = true
        glkView?.contentScaleFactor = 1.0
        glkView?.drawableDepthFormat = .format24
        insertSubview(glkView!, at: 0)
        glGenRenderbuffers(1, &renderBuffer)
        glBindBuffer(GLenum(GL_RENDERBUFFER), renderBuffer)
        
        coreImageContext = CIContext(eaglContext: context!, options: [kCIContextUseSoftwareRenderer: true])
        EAGLContext.setCurrent(context!)
    }
}

extension MPCameraView {
    func biggestRectagle(_ rectangles: [CIRectangleFeature]) -> CIRectangleFeature? {
        guard rectangles.count > 0 else {
            return nil
        }
        
        var biggestRectangle = rectangles.first!
        
        var halfPerimeterValue = 0.0
        
        for rectangle in rectangles {
            let topLeft = rectangle.topLeft
            let topRight = rectangle.topRight
            let widht = hypotf(Float(topLeft.x - topRight.x), Float(topLeft.y - topRight.y))
            
            let bottomLeft = rectangle.bottomLeft
            let height = hypotf(Float(topLeft.x - bottomLeft.x), Float(topLeft.y - bottomLeft.y))
            
            let currentHalfPerimeterValue = Double(height + widht)
            
            if halfPerimeterValue < currentHalfPerimeterValue {
                halfPerimeterValue = currentHalfPerimeterValue
                biggestRectangle = rectangle
            }
        }
        
        return biggestRectangle
    }
}

extension MPCameraView: AVCaptureMetadataOutputObjectsDelegate {
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
        
        if let metadataObject = metadataObjects.first {
            let readableObject = metadataObject as! AVMetadataMachineReadableCodeObject
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            
            found(code: readableObject.stringValue!)
            
        }
    }
    
    func found(code: String) {
        print(code)
    }
}

extension MPCameraView {
    func imageOverLay(_ image: CIImage, feature: CIRectangleFeature) -> CIImage {
        var overlay = CIImage(color: CIColor(color: borderColor))
        overlay = overlay.cropping(to: image.extent)
        overlay = overlay.applyingFilter("CIPerspectiveTransformWithExtent", withInputParameters:
            ["inputExtent":     CIVector(cgRect: image.extent),
             "inputTopLeft":    CIVector(cgPoint: feature.topLeft),
             "inputTopRight":   CIVector(cgPoint: feature.topRight),
             "inputBottomLeft": CIVector(cgPoint: feature.bottomLeft),
             "inputBottomRight": CIVector(cgPoint: feature.bottomRight)])
        return overlay.compositingOverImage(image)
    }
}

extension MPCameraView: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func contrastFilter(_ image: CIImage) -> CIImage {
        return CIFilter(name: "CIColorControls", withInputParameters: ["inputContrast":1.1, kCIInputImageKey: image])!.outputImage!
    }
    
    func enhanceFilter(_ image: CIImage) -> CIImage {
        return CIFilter(name: "CIColorControls", withInputParameters: ["inputBrightness":0.0, "inputContrast":1.14, "inputSaturation":0.0, kCIInputImageKey: image])!.outputImage!
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        guard CMSampleBufferIsValid(sampleBuffer) else {
            return
        }
        
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            var image = CIImage(cvImageBuffer: pixelBuffer)
            
            switch self.imageFilter {
            case .blackAndWhite:
                image = self.contrastFilter(image)
            default:
                image = self.enhanceFilter(image)
            }
            
            if detectedFrame {
                lastDetectedRectagle = biggestRectagle(MPCameraView.rectagleDetector?.features(in: image) as! [CIRectangleFeature])
                detectedFrame = false
            }
            
            if let lastDetectedRectagle = lastDetectedRectagle {
                detectionConfidence += 0.5
                image = imageOverLay(image, feature: lastDetectedRectagle)
            } else {
                detectionConfidence = 0.0
            }
            
            if let context = context, let coreImageContext = coreImageContext, let glkView = glkView {
                coreImageContext.draw(image, in: bounds, from: image.extent)
                context.presentRenderbuffer(Int(GL_RENDERBUFFER))
                glkView.setNeedsDisplay()
            }
        }
    }
}













