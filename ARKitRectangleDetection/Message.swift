//
//  Message.swift
//  ARKitRectangleDetection
//
//  Created by Melissa Ludowise on 8/6/17.
//  Copyright © 2017 Mel Ludowise. All rights reserved.
//

import Foundation

enum Message {
    
    // Help message to instruct the user to move their phone to identify a surface
    case helpFindSurface
    
    // Help message to instruct the user to tap on a rectangle to identify it
    case helpTapRect
    
    // Error message displays when the user taps but no rectangle is detected
    case errNoRect
    
    // Error message displays when a surface cannot be found for the identified rectangle
    case errNoPlaneForRect
}

extension Message {
    var localizedString: String {
        get {
            switch(self) {
            case .helpFindSurface:
                return NSLocalizedString("Move your phone until you see a blue grid covering the surface of your rectangle", comment: "")
            case .helpTapRect:
                return NSLocalizedString("Tap on a rectangle", comment: "")
            case .errNoRect:
                return NSLocalizedString("", comment: "")
            case .errNoPlaneForRect:
                return NSLocalizedString("", comment: "")
            }
        }
    }
}
