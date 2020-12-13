//
//  UIView+Extensions.swift
//  ARKitRectangleDetection
//
//  Created by Melissa Ludowise on 8/4/17.
//  Copyright © 2017 Mel Ludowise. All rights reserved.
//

import Foundation
import UIKit

extension UIView {
    
    // Converts a point from camera coordinates (0 to 1 or -1 to 0, depending on orientation)
    // into a point within the given view
//    func convertFromCamera(_ point: CGPoint) -> CGPoint {
//        let orientation = UIApplication.shared.statusBarOrientation
//
//        switch orientation {
//        case .landscapeLeft:
//            return CGPoint(x: (1 - point.x) * frame.width, y: point.y * frame.height)
//        case .landscapeRight:
//            return CGPoint(x: point.x * frame.width, y: (1 - point.y) * frame.height)
//        case .portraitUpsideDown:
//            return CGPoint(x: (1 - point.y) * frame.width, y: (1 - point.x) * frame.height)
//        case .portrait,
//             .unknown:
//            fallthrough
//        @unknown default:
//            return CGPoint(x: point.y * frame.width, y: point.x * frame.height)
//        }
//    }
//
//    // Converts a rect from camera coordinates (0 to 1 or -1 to 0, depending on orientation)
//    // into a point within the given view
//    func convertFromCamera(_ rect: CGRect) -> CGRect {
//        let orientation = UIApplication.shared.statusBarOrientation
//        let x, y, w, h: CGFloat
//
//        switch orientation {
//        case .landscapeLeft:
//            w = rect.width
//            h = rect.height
//            x = 1 - rect.origin.x - w
//            y = rect.origin.y
//        case .landscapeRight:
//            w = rect.width
//            h = rect.height
//            x = rect.origin.x
//            y = 1 - rect.origin.y - h
//        case .portraitUpsideDown:
//            w = rect.height
//            h = rect.width
//            x = 1 - rect.origin.y - w
//            y = 1 - rect.origin.x - h
//        case .portrait,
//             .unknown:
//            fallthrough
//        @unknown default:
//            w = rect.height
//            h = rect.width
//            x = rect.origin.y
//            y = rect.origin.x
//        }
//
//        return CGRect(x: x * frame.width, y: y * frame.height, width: w * frame.width, height: h * frame.height)
//    }
    
}

