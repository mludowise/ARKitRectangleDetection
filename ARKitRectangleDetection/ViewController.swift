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
    
    // Only used if showFoundRectangles is true
    // UIViews used to draw bounding boxes of found rectangles with keys for rectangleObservation.uuid
    private var foundRectangleOutlineLayers = [UUID:CAShapeLayer]()
    
    // Only used if showSelectedRectangleOutline is true
    // Displayed rectangle outline
    private var selectedRectangleOutlineLayer: CAShapeLayer?
    
    // Only used if showSurfaces is true
    // SurfaceNodes used to draw found surfaces with keys for anchor.identifier
    private var surfaceNodes = [UUID:SurfaceNode]()
    
    // Last rectangle observed
    private var lastObservation: VNRectangleObservation?
    
    // Displayed RectangleNodes with keys for rectangleObservation.uuid
    private var rectangleNodes = [UUID:RectangleNode]()    
    
    // MARK: - Debug properties
    
    // Displays all rectangles found in a blue outline
    var showFoundRectangles = true {
        didSet {
            if showFoundRectangles == false {
                for layer in foundRectangleOutlineLayers.values {
                    layer.removeFromSuperlayer()
                }
                foundRectangleOutlineLayers.removeAll()
            }
        }
    }
    
    // Draws a red outline around the selected rectangle that was found
    var showSelectedRectangleOutline = true {
        didSet {
            if showSelectedRectangleOutline == false {
                selectedRectangleOutlineLayer?.removeFromSuperlayer()
                selectedRectangleOutlineLayer = nil
            }
        }
    }
    
    // Renders a blue grid for any found surfaces
    var showSurfaces = true {
        didSet {
            if showSurfaces == false {
                for surface in surfaceNodes.values {
                    surface.removeFromParentNode()
                }
                surfaceNodes.removeAll()
            }
        }
    }
    
    // Display yellow dots representing feature points
    var showFeaturePoints = true {
        didSet {
            if showFeaturePoints {
                sceneView.debugOptions.insert(ARSCNDebugOptions.showFeaturePoints)
            } else {
                sceneView.debugOptions.remove(ARSCNDebugOptions.showFeaturePoints)
            }
        }
    }
    
    // Display origin
    var showWorldOrigin = true {
        didSet {
            if showWorldOrigin {
                sceneView.debugOptions.insert(ARSCNDebugOptions.showWorldOrigin)
            } else {
                sceneView.debugOptions.remove(ARSCNDebugOptions.showWorldOrigin)
            }
        }
    }
    
    // Show statistics
    var showStatistics = false {
        didSet {
            sceneView.showsStatistics = showStatistics
        }
    }
    
    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegates
        sceneView.delegate = self
        
        // Comment out to disable rectangle tracking
//        sceneView.session.delegate = self
        
        // Show statistics, world origin, and feature points if desired
        sceneView.showsStatistics = showStatistics
        sceneView.debugOptions = []
        if showFeaturePoints {
            sceneView.debugOptions.insert(ARSCNDebugOptions.showFeaturePoints)
        }
        if showWorldOrigin {
            sceneView.debugOptions.insert(ARSCNDebugOptions.showWorldOrigin)
        }

        // Enable default lighting
        sceneView.autoenablesDefaultLighting = true
        
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
                    for layer in self.foundRectangleOutlineLayers.values {
                        layer.removeFromSuperlayer()
                    }
                    self.foundRectangleOutlineLayers.removeAll()
                    
                    if self.showFoundRectangles {
                        // Display bounding boxes
                        for result in results {
                            let points = [result.topLeft, result.topRight, result.bottomRight, result.bottomLeft]
                            let convertedPoints = points.map { self.sceneView.convertFromCamera($0) }
                            let layer = self.drawPolygon(convertedPoints, color: UIColor.blue)
                            self.foundRectangleOutlineLayers[result.uuid] = layer
                            self.sceneView.layer.addSublayer(layer)
                        }
                    }
                    
                    guard let result = results.filter({ (result) -> Bool in
                        let convertedRect = self.sceneView.convertFromCamera(result.boundingBox)
                        return convertedRect.contains(touchLocation)
                    }).first else {
                        return
                    }
                    
                    self.handleRectangleObservation(result)
                }
            })
            request.maximumObservations = 0
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
        if !showSurfaces {
            return
        }
        
        guard let anchor = anchor as? ARPlaneAnchor else {
            return
        }
        
        let surface = SurfaceNode(anchor: anchor)
        surfaceNodes[anchor.identifier] = surface
        node.addChildNode(surface)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // See if this is a plane we are currently rendering
        guard let surface = surfaceNodes[anchor.identifier],
            let anchor = anchor as? ARPlaneAnchor else {
                return
        }
        
        surface.update(anchor)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard let surface = surfaceNodes[anchor.identifier] else {
                return
        }
        
        surface.removeFromParentNode()
        
        surfaceNodes.removeValue(forKey: anchor.identifier)
    }
    
    // MARK: - Helper Methods
    
    private func handleRectangleObservation(_ result: VNRectangleObservation) {
        // Remove old outline of selected rectangle
        if let layer = selectedRectangleOutlineLayer {
            layer.removeFromSuperlayer()
            selectedRectangleOutlineLayer = nil
        }
        
        lastObservation = result
        
        // Convert points to view
        // VNObservation coordinates are in camera coordinates, which depend on the phone's orientation
        let points = [result.topLeft, result.topRight, result.bottomRight, result.bottomLeft]
        let convertedPoints = points.map { sceneView.convertFromCamera($0) }
        
        // Outline the rectangle
        if showSelectedRectangleOutline {
            selectedRectangleOutlineLayer = drawPolygon(convertedPoints, color: UIColor.red)
            sceneView.layer.addSublayer(selectedRectangleOutlineLayer!)
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
        
    private func drawPolygon(_ points: [CGPoint], color: UIColor) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.fillColor = nil
        layer.strokeColor = color.cgColor
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
