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
    static let hitTestTypes: ARHitTestResult.ResultType = [.existingPlaneUsingExtent]
    static let hitResultAnchorComparator: (ARHitTestResult, ARHitTestResult) -> Bool = { (hit1, hit2) in
        hit1.anchor?.identifier == hit2.anchor?.identifier
    }
    
    enum RectangleCorners {
        case topLeft(topLeft: SCNVector3, topRight: SCNVector3, bottomLeft: SCNVector3)
        case topRight(topLeft: SCNVector3, topRight: SCNVector3, bottomRight: SCNVector3)
        case bottomLeft(topLeft: SCNVector3, bottomLeft: SCNVector3, bottomRight: SCNVector3)
        case bottomRight(topRight: SCNVector3, bottomLeft: SCNVector3, bottomRight: SCNVector3)
    }
    
    private var rectangle: VNRectangleObservation
    private var corners: RectangleCorners
    private var anchor: ARPlaneAnchor
    
    init?(sceneView: ARSCNView, rectangle: VNRectangleObservation) {
        guard let cornersAndAnchor = getCorners(for: rectangle, in: sceneView) else {
            return nil
        }
        
        self.rectangle = rectangle
        self.corners = cornersAndAnchor.corners
        self.anchor = cornersAndAnchor.anchor
        super.init()
        
        // Find width, height, & center from corners
        let width = findWidth()
        let height = findHeight()
        let center = findCenter()
        let angle = getYRotation()
        
        // Debug
        print("center: \(center) width: \(width) (\(width * meters2inches)\") height: \(height) (\(height * meters2inches)\")")
        
        // Create the 3D plane geometry with the dimensions calculated from corners
        let planeGeometry = SCNPlane(width: width, height: height)
        let rectNode = SCNNode(geometry: planeGeometry)

        // Move the rectangle to the center
        rectNode.position = center

        // Planes in SceneKit are vertical by default so we need to rotate
        // 90 degrees to match planes in ARKit
        var transform = SCNMatrix4MakeRotation(-Float.pi / 2.0, 1.0, 0.0, 0.0)
        
        // Set rotation to the corner of the rectangle
        transform = SCNMatrix4Rotate(transform, angle, 0, 1, 0)
        
        rectNode.transform = transform
        
        // We add the new node to ourself since we inherited from SCNNode
        self.addChildNode(rectNode)
        
        // Set position to the center of rectangle
        self.position = center
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
    
    private func getCornerAngle() -> CGFloat {
        switch corners {
        case .topLeft(let c, let a, let b),
             .topRight(let a, let c, let b),
             .bottomLeft(let a, let c, let b),
             .bottomRight(let a, let b, let c):
            
            return getAngle(point: a, point: b, vertex: c)
        }
    }
    
    private func getYRotation() -> Float {
        switch corners {
        case .topLeft(let l, let r, _):
            let distX = r.x - l.x
            let distZ = r.z - l.z
            return -atan(distZ / distX)
        default:
            return 0
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// Finds 3d vector points
fileprivate func getCorners(for rectangle: VNRectangleObservation, in sceneView: ARSCNView) -> (corners: RectangleNode.RectangleCorners, anchor: ARPlaneAnchor)? {
    // Try to find intersecting surfaces for each corner of rectangle
    let tl = sceneView.hitTest(sceneView.convertFromCamera(rectangle.topLeft), types: RectangleNode.hitTestTypes)
    let tr = sceneView.hitTest(sceneView.convertFromCamera(rectangle.topRight), types: RectangleNode.hitTestTypes)
    let bl = sceneView.hitTest(sceneView.convertFromCamera(rectangle.bottomLeft), types: RectangleNode.hitTestTypes)
    let br = sceneView.hitTest(sceneView.convertFromCamera(rectangle.bottomRight), types: RectangleNode.hitTestTypes)
    
    print("tl: \(tl.count) tr: \(tr.count) br: \(br.count) bl: \(bl.count)")
    
    // Check for three corners of rectangle that intersect with the same plane
    
    // Try top & left corners
    var surfaces = filterByIntersection([tl, tr, bl], where: RectangleNode.hitResultAnchorComparator)
    print("tl surfaces: \(surfaces.count)")
    if let tlHit = surfaces[0].first,
        let trHit = surfaces[1].first,
        let blHit = surfaces[2].first,
        let anchor = tlHit.anchor as? ARPlaneAnchor {
        
        print("Corner vectors: \(tlHit.worldVector), \(trHit.worldVector), \(blHit.worldVector)")
        
        return (.topLeft(topLeft: tlHit.worldVector,
                        topRight: trHit.worldVector,
                        bottomLeft: blHit.worldVector),
                anchor)
    }
    
    // Try top & right corners
    surfaces = filterByIntersection([tl, tr, br], where: RectangleNode.hitResultAnchorComparator)
    print("tr surfaces: \(surfaces.count)")
    if let tlHit = surfaces[0].first,
        let trHit = surfaces[1].first,
        let brHit = surfaces[2].first,
        let anchor = tlHit.anchor as? ARPlaneAnchor {
        
        return (.topRight(topLeft: tlHit.worldVector,
                         topRight: trHit.worldVector,
                         bottomRight: brHit.worldVector),
                anchor)
    }
    
    // Try bottom & left corners
    surfaces = filterByIntersection([tl, bl, br], where: RectangleNode.hitResultAnchorComparator)
    print("bl surfaces: \(surfaces.count)")
    if let tlHit = surfaces[0].first,
        let blHit = surfaces[1].first,
        let brHit = surfaces[2].first,
        let anchor = tlHit.anchor as? ARPlaneAnchor {
        
        return (.bottomLeft(topLeft: tlHit.worldVector,
                           bottomLeft: blHit.worldVector,
                           bottomRight: brHit.worldVector),
                anchor)
    }
    
    // Try bottom & right corners
    print("br surfaces: \(surfaces.count)")
    surfaces = filterByIntersection([tr, bl, br], where: RectangleNode.hitResultAnchorComparator)
    if let trHit = surfaces[0].first,
        let blHit = surfaces[2].first,
        let brHit = surfaces[1].first,
        let anchor = trHit.anchor as? ARPlaneAnchor {
        
        return (.bottomRight(topRight: trHit.worldVector,
                            bottomLeft: blHit.worldVector,
                            bottomRight: brHit.worldVector),
                anchor)
    }
    
    // No 3 points on the same plane
    return nil
}

fileprivate func getAngle(point a: SCNVector3, point b: SCNVector3, vertex c: SCNVector3) -> CGFloat {
    let distA = c.distance(from: b)
    let distB = c.distance(from: a)
    let distC = a.distance(from: b)
    
    let cosC = ((distA * distA) + (distB * distB) - (distC * distC)) / (2 * distA * distB)
    return acos(cosC)
}



