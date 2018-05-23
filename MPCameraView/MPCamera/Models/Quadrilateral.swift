//
//  Quadrilateral.swift
//  MPCameraView
//
//  Created by Mathias Palm on 2017-06-17.
//  Copyright © 2017 mathiaspalm.me. All rights reserved.
//
import UIKit

private let tolerance:CGFloat = 10

struct Quadrilateral {
    
    var topLeft: CGPoint = .zero
    var topRight: CGPoint = .zero
    var bottomLeft: CGPoint = .zero
    var bottomRight: CGPoint = .zero
    
    var path : UIBezierPath {
        get {
            let tempPath = UIBezierPath()
            tempPath.move(to: topLeft)
            tempPath.addLine(to: topRight)
            tempPath.addLine(to: bottomRight)
            tempPath.addLine(to: bottomLeft)
            tempPath.addLine(to: topLeft)
            return tempPath
        }
    }
    
    init(topLeft topLeft_I: CGPoint, topRight topRight_I: CGPoint, bottomLeft bottomLeft_I: CGPoint, bottomRight bottomRight_I: CGPoint) {
        topLeft = topLeft_I
        topRight = topRight_I
        bottomLeft = bottomLeft_I
        bottomRight = bottomRight_I
    }
    
    var frame : CGRect {
        get {
            let highestPoint = max(topLeft.y, topRight.y, bottomLeft.y, bottomRight.y)
            let lowestPoint = min(topLeft.y, topRight.y, bottomLeft.y, bottomRight.y)
            let farthestPoint = max(topLeft.x, topRight.x, bottomLeft.x, bottomRight.x)
            let closestPoint = min(topLeft.x, topRight.x, bottomLeft.x, bottomRight.x)
            
            let origin = CGPoint(x: closestPoint, y: lowestPoint)
            let size = CGSize(width: farthestPoint, height: highestPoint)
            
            return CGRect(origin: origin, size: size)
        }
    }
    
    var size : CGSize {
        get {
            return frame.size
        }
    }
    
    var origin : CGPoint {
        get {
            return frame.origin
        }
    }
    
    static func withinTolerance(lhs: Quadrilateral, rhs: Quadrilateral) -> Bool {
        return
            abs(lhs.topLeft.x - rhs.topLeft.x) < tolerance &&
            abs(lhs.topLeft.y - rhs.topLeft.y) < tolerance &&
            abs(lhs.topRight.x - rhs.topRight.x) < tolerance &&
            abs(lhs.topRight.y - rhs.topRight.y) < tolerance &&
            abs(lhs.bottomLeft.x - rhs.bottomLeft.x) < tolerance &&
            abs(lhs.bottomLeft.y - rhs.bottomLeft.y) < tolerance &&
            abs(lhs.bottomRight.x - rhs.bottomRight.x) < tolerance &&
            abs(lhs.bottomRight.y - rhs.bottomRight.y) < tolerance
    }
}











