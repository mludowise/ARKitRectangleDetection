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

enum RectangleCorners {
    case topLeft(topLeft: SCNVector3, topRight: SCNVector3, bottomLeft: SCNVector3)
    case topRight(topLeft: SCNVector3, topRight: SCNVector3, bottomRight: SCNVector3)
    case bottomLeft(topLeft: SCNVector3, bottomLeft: SCNVector3, bottomRight: SCNVector3)
    case bottomRight(topRight: SCNVector3, bottomLeft: SCNVector3, bottomRight: SCNVector3)
}

class RectangleNode: SCNNode {
    
    private var surfaceNode: SurfaceNode
    private var rectangle: VNRectangleObservation
    private var corners: RectangleCorners
    
//    private var topLeft: SCNVector3?
//    private var topRight: SCNVector3?
//    private var bottomLeft: SCNVector3?
//    private var bottomRight: SCNVector3?
    
    init?(sceneView: ARSCNView, rectangle: VNRectangleObservation) {
        self.rectangle = rectangle
        
        // Try to find intersecting planes for each corner of rectangle
        let tl = findIntersectingPlanes(rectangle.topLeft, in: sceneView)
        let tr = findIntersectingPlanes(rectangle.topRight, in: sceneView)
        let bl = findIntersectingPlanes(rectangle.bottomLeft, in: sceneView)
        let br = findIntersectingPlanes(rectangle.bottomRight, in: sceneView)
        
        // Check for three corners of rectangle that intersect with the same plane
        if let surfaceNode = intersect(tl.keys, tr.keys, bl.keys).last { // Try top & left corners
            corners = .topLeft(topLeft: tl[surfaceNode]!.worldCoordinates,
                               topRight: tr[surfaceNode]!.worldCoordinates,
                               bottomLeft: bl[surfaceNode]!.worldCoordinates)
            self.surfaceNode = surfaceNode
        } else if let surfaceNode = intersect(tl.keys, tr.keys, bl.keys).last { // Try top & right corners
            corners = .topRight(topLeft: tl[surfaceNode]!.worldCoordinates,
                                topRight: tr[surfaceNode]!.worldCoordinates,
                                bottomRight: br[surfaceNode]!.worldCoordinates)
            self.surfaceNode = surfaceNode
        } else if let surfaceNode = intersect(tl.keys, tr.keys, bl.keys).last { // Try bottom & left corners
            corners = .bottomLeft(topLeft: tl[surfaceNode]!.worldCoordinates,
                                  bottomLeft: bl[surfaceNode]!.worldCoordinates,
                                  bottomRight: br[surfaceNode]!.worldCoordinates)
            self.surfaceNode = surfaceNode
        } else if let surfaceNode = intersect(tl.keys, tr.keys, bl.keys).last { // Try bottom & right corners
            corners = .bottomRight(topRight: tr[surfaceNode]!.worldCoordinates,
                                   bottomLeft: bl[surfaceNode]!.worldCoordinates,
                                   bottomRight: br[surfaceNode]!.worldCoordinates)
            self.surfaceNode = surfaceNode
        } else {
            return nil
        }
        
        super.init()
        
        // We add the new node to ourself since we inherited from SCNNode
        let node = createNode()
        self.addChildNode(node)
    }
    
    private func createNode() -> SCNNode {
        
        // Set width & height
        let planeGeometry = SCNPlane(width: findWidth(), height: findHeight())
        let rectNode = SCNNode(geometry: planeGeometry)

        // Move the rectangle to the center
        rectNode.position = findCenter()
        
        // Planes in SceneKit are vertical by default so we need to rotate
        // 90 degrees to match planes in ARKit
        rectNode.transform = SCNMatrix4MakeRotation(-Float.pi / 2.0, 1.0, 0.0, 0.0)
        
        // Rotate to align corners
        // TODO
        
        return rectNode
    }

//    private func transform(hitResult: ARHitTestResult) -> SCNVector3 {
//        let hitTransform = SCNMatrix4(hitResult.worldTransform)
//        return SCNVector3Make(hitTransform.m41,
//                              hitTransform.m42,
//                              hitTransform.m43)
//    }
    
    private func findWidth() -> CGFloat {
        switch corners {
            case .topLeft(let left, let right, _),
                 .topRight(let left, let right, _),
                 .bottomLeft(_, let left, let right),
                 .bottomRight(_, let left, let right):
                return right.distance(from: left)
        }
    }
    
    private func findHeight() -> CGFloat {
        switch corners {
        case .topLeft(let top, _, let bottom),
             .topRight(_, let top, let bottom),
             .bottomLeft(let top, let bottom, _),
             .bottomRight(let top, _, let bottom):
            return top.distance(from: bottom)
        }
    }
    
    private func findCenter() -> SCNVector3 {
        switch corners {
        case .topLeft(_, let c1, let c2),
             .topRight(let c1, _, let c2),
             .bottomRight(let c1, let c2, _),
             .bottomLeft(let c1, _, let c2):
            return c1.midpoint(from: c2)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// Finds all known planes that intersect with the specified point
fileprivate func findIntersectingPlanes(_ point: CGPoint, in sceneView: ARSCNView) -> [SurfaceNode:SCNHitTestResult] {
    let hitList = sceneView.hitTest(point, options: nil)
    //            .hitTest(point, types: [.featurePoint])
    
    var hitPlanes = [SurfaceNode:SCNHitTestResult]()
    for hitResult in hitList {
        if let plane = hitResult.node as? SurfaceNode {
            hitPlanes[plane] = hitResult
        }
    }
    
    return hitPlanes
}

