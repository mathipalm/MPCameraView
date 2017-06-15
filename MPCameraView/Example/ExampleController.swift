//
//  ExampleController.swift
//  MPCameraView
//
//  Created by Mathias Palm on 2017-06-13.
//  Copyright © 2017 mathiaspalm.me. All rights reserved.
//

import UIKit

class ExampleController: UIViewController {

    let cameraView: MPCameraView = {
        let view = MPCameraView()
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(cameraView)
        view.addConstraintsWithFormat("H:|[v0]|", views: cameraView)
        view.addConstraintsWithFormat("V:|[v0]|", views: cameraView)
        cameraView.setupCamera()
    }
}
