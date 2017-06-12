//
//  MPCameraView.swift
//  MPCameraView
//
//  Created by Mathias Palm on 2017-06-12.
//  Copyright © 2017 mathiaspalm.me. All rights reserved.
//

import UIKit
import AVFoundation

class MPCameraView: UIView {
    
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
}

extension MPCameraView {
    func setup() {
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
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        guard captureSession.canAddOutput(metadataOutput) else {
            return
        }
        captureSession.addOutput(metadataOutput)
        
        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
//        metadataOutput.metadataObjectTypes = [AVMetadataob]
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = layer.bounds
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        
        layer.addSublayer(previewLayer)
        
        captureSession.startRunning()
    }
}

extension MPCameraView: AVCaptureMetadataOutputObjectsDelegate {
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
        
        if let metadataObject = metadataObjects.first {
            let readableObject = metadataObject as! AVMetadataMachineReadableCodeObject
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            
            found(code: readableObject.stringValue);

        }
    }
    
    func found(code: String) {
        print(code)
    }
}
