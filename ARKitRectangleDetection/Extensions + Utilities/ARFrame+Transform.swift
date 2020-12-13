//
//  ARFrame+Transform.swift
//  ARKitRectangleDetection
//
//  Created by Melissa Ludowise on 12/12/20.
//  Copyright © 2020 Mel Ludowise. All rights reserved.
//

import ARKit

extension ARFrame {
    // The `displayTransform` method doesn't do what's advertised. This corrects for it
    func displayTransformCorrected(for interfaceOrientation: UIInterfaceOrientation,
                                 viewportSize: CGSize) -> CGAffineTransform {
        let flipYAxis: Bool
        let flipXAxis: Bool
        var imageResolution = camera.imageResolution
        switch interfaceOrientation {
        case .landscapeLeft,
             .landscapeRight:
          flipYAxis = false
          flipXAxis = true
        default:
            imageResolution = CGSize(width: imageResolution.height, height: imageResolution.width)
          flipYAxis = true
          flipXAxis = false
        }

        // Assume width cut off
        var height, width, translateX, translateY: CGFloat
        if imageResolution.width / imageResolution.height > viewportSize.width / viewportSize.height {
          height = viewportSize.height
          width = imageResolution.width / imageResolution.height * viewportSize.height
          translateX = (viewportSize.width - width)/2
          translateY = 0
        } else {
          width = viewportSize.width
          height = imageResolution.height / imageResolution.width * viewportSize.width
          translateX = 0
          translateY = (viewportSize.height - height)/2
        }

        if flipYAxis {
          translateY += height
          height = -height
        }
        if flipXAxis {
          translateX += width
          width = -width
        }

        return CGAffineTransform(scaleX: width, y: height)
          .concatenating(CGAffineTransform(translationX: translateX, y: translateY))
    }
}
