//
//  ARHitTestResult+Extensions.swift
//  ARKitRectangleDetection
//
//  Created by Melissa Ludowise on 8/4/17.
//  Copyright © 2017 Mel Ludowise. All rights reserved.
//

import Foundation
import ARKit

extension ARHitTestResult {
    var worldVector: SCNVector3 {
        get {
            return SCNVector3Make(worldTransform.columns.3.x,
                                  worldTransform.columns.3.y,
                                  worldTransform.columns.3.z)
        }
    }
}

extension Array where Element:ARHitTestResult {
    var closest: ARHitTestResult? {
        get {
            return sorted { (result1, result2) -> Bool in
                return result1.distance < result2.distance
            }.first
        }
    }
    
}
