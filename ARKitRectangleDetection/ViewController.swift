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
    
    var displaySurfaces = true {
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
    
    // Dictionary of VNRectangleObservation UUIDs to drawn rectangle nodes
    private var rectangleNodes = [UUID:RectangleNode]()
    
    
    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegates
        sceneView.delegate = self
        
        // Comment out to disable rectangle tracking
//        sceneView.session.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        sceneView.autoenablesDefaultLighting = true
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
                    
                    print("\(results.count) rectangles found")
                    
                    // Remove old bounding boxes
                    for view in self.foundRectangleViews.values {
                        view.removeFromSuperview()
                    }
                    self.foundRectangleViews.removeAll()
                    
                    if self.displayFoundRectangles {
                        // Display bounding boxes
                        for result in results {
                            let convertedRect = self.sceneView.convertFromCamera(result.boundingBox)
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
                        let convertedRect = self.sceneView.convertFromCamera(result.boundingBox)
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
        // Remove old outline & 3d rect
        if let lastObservation = lastObservation,
            let layer = outlineLayers[lastObservation.uuid] {
            outlineLayers.removeValue(forKey: lastObservation.uuid)
            rectangleNodes.removeValue(forKey: lastObservation.uuid)
            layer.removeFromSuperlayer()
        }
        
        lastObservation = result
        
        // Convert points to view
        // VNObservation coordinates are in camera coordinates, which depend on the phone's orientation
        let points = [result.topLeft, result.topRight, result.bottomRight, result.bottomLeft]
        let convertedPoints = points.map { sceneView.convertFromCamera($0) }
        
        // Outline the rectangle
        if displayRectangleOutline {
            let layer = drawPolygon(convertedPoints)
            sceneView.layer.addSublayer(layer)
            outlineLayers[result.uuid] = layer
        }
        
        // Convert to 3D coordinates
        guard let planeRectangle = PlaneRectangle(for: result, in: sceneView) else {
            print("No plane for this rectangle")
            return
        }
        
        let rectangleNode = RectangleNode(planeRectangle)
        rectangleNodes[result.uuid] = rectangleNode
        sceneView.scene.rootNode.addChildNode(rectangleNode)
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
