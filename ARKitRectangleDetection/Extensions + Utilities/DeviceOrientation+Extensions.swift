//
//  DeviceOrientation+Extensions.swift
//  ARKitRectangleDetection
//
//  Created by Melissa Ludowise on 11/29/20.
//  Copyright © 2020 Mel Ludowise. All rights reserved.
//

import UIKit

extension UIDeviceOrientation {

    var imageOrientation: CGImagePropertyOrientation {
        switch self {
        case .portraitUpsideDown:
            return .left
        case .landscapeLeft:
            return .up
        case .landscapeRight:
            return .down
        case .portrait,
             .unknown,
             .faceUp,
             .faceDown:
            fallthrough
        @unknown default:
            return .right
        }
    }
}

extension UIInterfaceOrientation {
    var imageOrientation: CGImagePropertyOrientation {
        switch self {
        case .portraitUpsideDown:
            return .left
        case .landscapeLeft:
            return .up
        case .landscapeRight:
            return .down
        case .unknown,
             .portrait:
            fallthrough
        @unknown default:
            return .right
        }
    }
}
