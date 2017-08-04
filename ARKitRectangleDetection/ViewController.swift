//
//  ViewController.swift
//  ARKitRectangleDetection
//
//  Created by Melissa Ludowise on 8/3/17.
//  Copyright © 2017 Mel Ludowise. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    // Debug settings
    var displayFoundRectangles = true {
        didSet {
            if displayFoundRectangles == false {
                for view in foundRectangleViews.values {
                    view.removeFromSuperview()
                }
                foundRectangleViews.removeAll()
            }
        }
    }
    
    var displayRectangleOutline = true {
        didSet {
            if displayRectangleOutline == false {
                for layer in outlineLayers.values {
                    layer.removeFromSuperlayer()
                }
                outlineLayers.removeAll()
            }
        }
    }
    
    var displaySurfaces = false {
        didSet {
            if displaySurfaces == false {
                for surface in surfaces.values {
                    surface.removeFromParentNode()
                }
                surfaces.removeAll()
            }
        }
    }
    
    private var surfaces = [UUID:SurfaceNode]()
    
    // Dictionary of VNRectangleObservation UUIDs to drawn layers
    private var outlineLayers = [UUID:CAShapeLayer]()
    
    // Dictionary of VNRectangleObservation UUIDs to views of bounding boxes
    private var foundRectangleViews = [UUID:UIView]()
    
    // Last rectangle observed
    private var lastObservation: VNRectangleObservation?
    
    
    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegates
        sceneView.delegate = self
        
        // Comment out to disable rectangle tracking
//        sceneView.session.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        self.sceneView.autoenablesDefaultLighting = true
        sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin, ARSCNDebugOptions.showFeaturePoints]

        // Create a new scene
        let scene = SCNScene()
        sceneView.scene = scene
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingSessionConfiguration()
        configuration.planeDetection = .horizontal
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
            let currentFrame = sceneView.session.currentFrame else {
            return
        }
        
        let touchLocation = touch.location(in: sceneView)
        
        DispatchQueue.global(qos: .background).async {
            let request = VNDetectRectanglesRequest(completionHandler: { (request, error) in
                
                // Jump onto the main thread
                DispatchQueue.main.async {
                    
                    // Access the first result in the array after casting the array as a VNClassificationObservation array
                    guard let results = request.results as? [VNRectangleObservation],
                        let _ = results.first else {
                            print ("No results")
                            return
                    }
                    
                    print("\(results.count) results")
                    
                    // Remove old bounding boxes
                    for view in self.foundRectangleViews.values {
                        view.removeFromSuperview()
                    }
                    self.foundRectangleViews.removeAll()
                    
                    if self.displayFoundRectangles {
                        // Display bounding boxes
                        for result in results {
                            let convertedRect = self.convertRectFromCamera(result.boundingBox, to: self.sceneView)
                            let view = UIView(frame: convertedRect)
                            view.layer.borderColor = UIColor.blue.cgColor
                            view.layer.borderWidth = 4
                            view.backgroundColor = .clear
                            
                            self.foundRectangleViews[result.uuid] = view
                            self.sceneView.addSubview(view)
                        }
                    }
                    
                    // Retrieve the result with the highest confidence that overlaps with touchpoint
                    guard let result = results.filter({ (result) -> Bool in
                        let convertedRect = self.convertRectFromCamera(result.boundingBox, to: self.sceneView)
                        return convertedRect.contains(touchLocation)
                    }).sorted(by: { (result1, result2) -> Bool in
//                        let box1 = result1.boundingBox
//                        let box2 = result2.boundingBox
//                        return box1.width * box1.height < box2.width * box2.height
                        return result1.confidence >= result2.confidence
                    }).first else {
                        return
                    }
                    
                    self.handleRectangleObservation(result)
                }
            })
            request.maximumObservations = 10
//            request.minimumConfidence = 0.3
            let handler = VNImageRequestHandler(cvPixelBuffer: currentFrame.capturedImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let observation = lastObservation,
            let currentFrame = sceneView.session.currentFrame else {
                return
        }
        
        DispatchQueue.global(qos: .background).async {
            let request = VNTrackRectangleRequest(rectangleObservation: observation, completionHandler: { (request, error) in
                // Jump onto the main thread
                DispatchQueue.main.async {
                    
                    // Access the first result in the array after casting the array as a VNClassificationObservation array
                    guard let results = request.results as? [VNRectangleObservation],
                        let result = results.first else {
                            print ("No results")
                            return
                    }
                    
                    self.handleRectangleObservation(result)
                }
            })
            request.trackingLevel = .accurate
            let handler = VNImageRequestHandler(cvPixelBuffer: currentFrame.capturedImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if !displaySurfaces {
            return
        }
        
        guard let anchor = anchor as? ARPlaneAnchor else {
            return
        }
        
        let surface = SurfaceNode(anchor: anchor)
        surfaces[anchor.identifier] = surface
        node.addChildNode(surface)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // See if this is a plane we are currently rendering
        guard let surface = surfaces[anchor.identifier],
            let anchor = anchor as? ARPlaneAnchor else {
                return
        }
        
        surface.update(anchor)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard let surface = surfaces[anchor.identifier] else {
                return
        }
        
        surface.removeFromParentNode()
        
        surfaces.removeValue(forKey: anchor.identifier)
    }
    
    // MARK: - Helper Methods
    
    private func handleRectangleObservation(_ result: VNRectangleObservation) {
        // Remove old outline
        if let lastObservation = self.lastObservation,
            let layer = self.outlineLayers[lastObservation.uuid] {
            self.outlineLayers.removeValue(forKey: lastObservation.uuid)
            layer.removeFromSuperlayer()
        }
        
        self.lastObservation = result
        
        // Convert points to view
        // VNObservation coordinates are in camera coordinates, which depend on the phone's orientation
        let points = [result.topLeft, result.topRight, result.bottomRight, result.bottomLeft]
        let convertedPoints = points.map { self.convertPointFromCamera($0, to: self.sceneView) }
        
        // Outline the rectangle
        if displayRectangleOutline {
            let layer = self.drawPolygon(convertedPoints)
            self.sceneView.layer.addSublayer(layer)
            self.outlineLayers[result.uuid] = layer
        }
        
//        guard let rectangleNode = RectangleNode(sceneView: self.sceneView, rectangle: result) else {
//            print("No rectangle on plane")
//            return
//        }
//        
//        self.sceneView.scene.rootNode.addChildNode(rectangleNode)
    }
    
    // Converts a point from camera coordinates (0 to 1 or -1 to 0, depending on orientation)
    // into a point within the given view
    private func convertPointFromCamera(_ point: CGPoint, to view: SCNView) -> CGPoint {
        let orientation = UIApplication.shared.statusBarOrientation
        switch orientation {
        case .portrait, .unknown:
            return CGPoint(x: point.y * view.frame.width, y: point.x * view.frame.height)
        case .landscapeLeft:
            return CGPoint(x: (1 - point.x) * view.frame.width, y: point.y * view.frame.height)
        case .landscapeRight:
            return CGPoint(x: point.x * view.frame.width, y: (1 - point.y) * view.frame.height)
        case .portraitUpsideDown:
            return CGPoint(x: (1 - point.y) * view.frame.width, y: (1 - point.x) * view.frame.height)
        }
    }
    
    private func convertRectFromCamera(_ rect: CGRect, to view: SCNView) -> CGRect {
        let orientation = UIApplication.shared.statusBarOrientation
        let x, y, w, h: CGFloat
        
        switch orientation {
        case .portrait, .unknown:
            w = rect.height
            h = rect.width
            x = rect.origin.y
            y = rect.origin.x
        case .landscapeLeft:
            w = rect.width
            h = rect.height
            x = 1 - rect.origin.x - w
            y = rect.origin.y
        case .landscapeRight:
            w = rect.width
            h = rect.height
            x = rect.origin.x
            y = 1 - rect.origin.y - h
        case .portraitUpsideDown:
            w = rect.height
            h = rect.width
            x = 1 - rect.origin.y - w
            y = 1 - rect.origin.x - h
        }
        
        return CGRect(x: x * view.frame.width, y: y * view.frame.height, width: w * view.frame.width, height: h * view.frame.height)
    }
    
    private func drawPolygon(_ points: [CGPoint]) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.fillColor = nil
        layer.strokeColor = UIColor.red.cgColor
        layer.lineWidth = 2
        let path = UIBezierPath()
        path.move(to: points.last!)
        points.forEach { point in
            path.addLine(to: point)
        }
        layer.path = path.cgPath
        return layer
    }
}
