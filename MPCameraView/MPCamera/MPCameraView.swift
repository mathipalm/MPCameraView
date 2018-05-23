//
//  MPCameraView.swift
//  MPCameraView
//
//  Created by Mathias Palm on 2017-06-12.
//  Copyright © 2017 mathiaspalm.me. All rights reserved.
//

import UIKit
import AVFoundation

enum MPCameraImageFilter {
    case blackAndWhite
    case normal
}

class MPCameraView: UIView {
    
    static let rectagleDetector = CIDetector(ofType: CIDetectorTypeRectangle, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    lazy var shapeLayer: CAShapeLayer = {
        let shapeLayer = CAShapeLayer()
        shapeLayer.fillColor = UIColor(red: 0.5, green: 1, blue: 0.5, alpha: 0.5).cgColor
        shapeLayer.strokeColor = UIColor.green.cgColor
        shapeLayer.lineWidth = 2.0
        return shapeLayer
    }()
    
    var lastDetectedRectangle: Quadrilateral? {
        didSet {
            if let rectangle = lastDetectedRectangle {
                shapeLayer.path = rectangle.path.cgPath
            }
        }
    }
    var numOfAtempts = 0
    var timer: Timer?
    

    var imageFilter: MPCameraImageFilter = .normal
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
}

extension MPCameraView {
    func setupCamera() {
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
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        previewLayer.frame = layer.bounds
        layer.addSublayer(previewLayer)

        layer.addSublayer(shapeLayer)

        captureSession.startRunning()
    }
}

extension MPCameraView {
    func biggestRectagle(_ ciImage: CIImage) -> Quadrilateral? {
        
        guard let features = MPCameraView.rectagleDetector?.features(in: ciImage) else {
            return nil
        }
        
        var biggestRectangle:Quadrilateral?
        var halfPerimeterValue = 0.0
        let xCorrection = bounds.width / ciImage.extent.size.width
        let yCorrection = bounds.height / ciImage.extent.size.height

        for feature in features as! [CIRectangleFeature] {
            
            var topLeft = feature.topLeft
            topLeft.x = topLeft.x * xCorrection
            topLeft.y = (ciImage.extent.size.height - topLeft.y) * yCorrection
            
            var topRight = feature.topRight
            topRight.x = topRight.x * xCorrection
            topRight.y = (ciImage.extent.size.height - topRight.y) * yCorrection
            
            var bottomLeft = feature.bottomLeft
            bottomLeft.x = bottomLeft.x * xCorrection
            bottomLeft.y = (ciImage.extent.size.height - bottomLeft.y) * yCorrection
            
            var bottomRight = feature.bottomRight
            bottomRight.x = bottomRight.x * xCorrection
            bottomRight.y = (ciImage.extent.size.height - bottomRight.y) * yCorrection
            
            let widht = hypotf(Float(topLeft.x - topRight.x), Float(topLeft.y - topRight.y))
            let height = hypotf(Float(topLeft.x - bottomLeft.x), Float(topLeft.y - bottomLeft.y))
            let currentHalfPerimeterValue = Double(height + widht)
            
            if halfPerimeterValue < currentHalfPerimeterValue {
                halfPerimeterValue = currentHalfPerimeterValue
                biggestRectangle = Quadrilateral(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight)
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

extension MPCameraView: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func contrastFilter(_ image: CIImage) -> CIImage {
        return CIFilter(name: "CIColorControls", withInputParameters: ["inputContrast":1.1, kCIInputImageKey: image])!.outputImage!
    }
    
    func enhanceFilter(_ image: CIImage) -> CIImage {
        // , "inputContrast":2.0, "inputSaturation":0.0
        return CIFilter(name: "CIColorControls", withInputParameters: ["inputBrightness":-0.0, kCIInputImageKey: image])!.outputImage!
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        guard CMSampleBufferIsValid(sampleBuffer) else {
            return
        }
        
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            var image = CIImage(cvImageBuffer: pixelBuffer)
            image = self.enhanceFilter(image)
            
            let biggestRectangle = biggestRectagle(image)
            guard let lastDetectedRectangle = lastDetectedRectangle, let rectangle = biggestRectangle else {
                self.lastDetectedRectangle = biggestRectangle
                return
            }
            
            if Quadrilateral.withinTolerance(lhs: lastDetectedRectangle, rhs: rectangle) {
                numOfAtempts = 0
                self.lastDetectedRectangle = rectangle
            } else {
                numOfAtempts += 1
            }
            
            if numOfAtempts >= 5 {
                numOfAtempts = 0
                self.lastDetectedRectangle = rectangle
            }
        }
    }
}













