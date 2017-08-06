//
//  RectangleNode.swift
//  ARKitRectangleDetection
//
//  Created by Melissa Ludowise on 8/3/17.
//  Copyright © 2017 Mel Ludowise. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision

private let meters2inches = CGFloat(39.3701)

class RectangleNode: SCNNode {
    
    init(_ planeRectangle: PlaneRectangle) {
        super.init()
        
        // Debug
        print("position: \(planeRectangle.position) width: \(planeRectangle.size.width) (\(planeRectangle.size.width * meters2inches)\") height: \(planeRectangle.size.height) (\(planeRectangle.size.height * meters2inches)\")")
        
        // Create the 3D plane geometry with the dimensions calculated from corners
        let planeGeometry = SCNPlane(width: planeRectangle.size.width, height: planeRectangle.size.height)
        let rectNode = SCNNode(geometry: planeGeometry)

        // Planes in SceneKit are vertical by default so we need to rotate
        // 90 degrees to match planes in ARKit
        var transform = SCNMatrix4MakeRotation(-Float.pi / 2.0, 1.0, 0.0, 0.0)
        
        // Set rotation to the corner of the rectangle
        transform = SCNMatrix4Rotate(transform, planeRectangle.orientation, 0, 1, 0)
        
        rectNode.transform = transform
        
        // We add the new node to ourself since we inherited from SCNNode
        self.addChildNode(rectNode)
        
        // Set position to the center of rectangle
        self.position = planeRectangle.position
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }    
}


