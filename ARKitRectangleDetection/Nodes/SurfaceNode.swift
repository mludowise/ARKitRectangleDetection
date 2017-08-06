//
//  SurfaceNode.swift
//  ARKitRectangleDetection
//
//  Created by Melissa Ludowise on 8/3/17.
//  Copyright © 2017 Mel Ludowise. All rights reserved.
//

import ARKit

class SurfaceNode: SCNNode {
    
    private(set) var anchor: ARPlaneAnchor
    private(set) var planeGeometry: SCNPlane
    
    init(anchor: ARPlaneAnchor) {
        
        self.anchor = anchor
        
        // Create the 3D plane geometry with the dimensions reported
        // by ARKit in the ARPlaneAnchor instance
        self.planeGeometry = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
        
        super.init()
        
        // Instead of just visualizing the grid as a gray plane, we will render
        // it in some Tron style colours.
        let material = SCNMaterial()
        let img = #imageLiteral(resourceName: "tron_grid")
        material.diffuse.contents = img
        
        // Set grid image to 1" per square (image is 0.4064 m)
        material.diffuse.wrapT = .repeat
        material.diffuse.wrapS = .repeat
        material.diffuse.contentsTransform = SCNMatrix4MakeScale(2.46062992 * anchor.extent.x, 2.46062992 * anchor.extent.z, 0)
        self.planeGeometry.materials = [material]
        
        let planeNode = SCNNode(geometry: self.planeGeometry)
        
        // Move the plane to the position reported by ARKit
        self.position = SCNVector3(anchor.center.x, 0, anchor.center.z)
        
        // Planes in SceneKit are vertical by default so we need to rotate
        // 90 degrees to match planes in ARKit
        planeNode.transform = SCNMatrix4MakeRotation(-Float.pi / 2.0, 1.0, 0.0, 0.0)
        
        // We add the new node to ourself since we inherited from SCNNode
        self.addChildNode(planeNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(_ anchor: ARPlaneAnchor) {
        self.planeGeometry.width = CGFloat(anchor.extent.x)
        self.planeGeometry.height = CGFloat(anchor.extent.z)
        
        // When the plane is first created it's center is 0,0,0 and
        // the nodes transform contains the translation parameters.
        // As the plane is updated the planes translation remains the
        // same but it's center is updated so we need to update the 3D
        // geometry position
        self.position = SCNVector3Make(anchor.center.x, 0, anchor.center.z);
    }
}
