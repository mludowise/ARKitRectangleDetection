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
    
    // Observed rectangle currently being touched
    private var selectedRectangleObservation: VNRectangleObservation?
    
    // Current touch location
    private var currTouchLocation: CGPoint?
    
    // The time the current rectangle selection was last updated
    private var selectedRectangleLastUpdated: Date?
    
    // Displayed RectangleNodes with keys for rectangleObservation.uuid
    private var rectangleNodes = [UUID:RectangleNode]()
    
    // Gets set to true when actively searching for rectangles in the current frame
    private var searchingForRectangles = false
    
    // MARK: - Debug properties
    
    // Displays all rectangles found in a blue outline
    var showFoundRectangles = false {
        didSet {
            if showFoundRectangles == false {
                for layer in foundRectangleOutlineLayers.values {
                    layer.removeFromSuperlayer()
                }
                foundRectangleOutlineLayers.removeAll()
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
        sceneView.session.delegate = self
        
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
        
        currTouchLocation = touch.location(in: sceneView)
        findRectangle(locationInScene: currTouchLocation!, frame: currentFrame)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Ignore if we're currently searching for a rect
        if searchingForRectangles {
            return
        }
        
        guard let touch = touches.first,
            let currentFrame = sceneView.session.currentFrame else {
                return
        }
        
        currTouchLocation = touch.location(in: sceneView)
        findRectangle(locationInScene: currTouchLocation!, frame: currentFrame)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        currTouchLocation = nil
        
        guard let selectedRect = selectedRectangleObservation else {
            return
        }
        
        // Create a planeRect and add a RectangleNode
        addPlaneRect(for: selectedRect)
    }
    
    // MARK: - ARSessionDelegate
    
    // Update selected rectangle if it's been more than 1 second and the screen is still being touched
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if searchingForRectangles {
            return
        }
        
        guard let currTouchLocation = currTouchLocation,
            let currentFrame = sceneView.session.currentFrame else {
                return
        }
        
        if selectedRectangleLastUpdated?.timeIntervalSinceNow ?? 0 < 1 {
            return
        }
        
        findRectangle(locationInScene: currTouchLocation, frame: currentFrame)
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
    
    private func findRectangle(locationInScene location: CGPoint, frame currentFrame: ARFrame) {
        // Note that we're actively searching for rectangles
        searchingForRectangles = true
        selectedRectangleObservation = nil
        
        // Perform request on background thread
        DispatchQueue.global(qos: .background).async {
            let request = VNDetectRectanglesRequest(completionHandler: { (request, error) in
                
                // Jump back onto the main thread
                DispatchQueue.main.async {
                    
                    // Mark that we've finished searching for rectangles
                    self.searchingForRectangles = false
                    
                    // Access the first result in the array after casting the array as a VNClassificationObservation array
                    guard let observations = request.results as? [VNRectangleObservation],
                        let _ = observations.first else {
                            print ("No results")
                            return
                    }
                    
                    print("\(observations.count) rectangles found")
                    
                    // Remove outlines for all found rectangles
                    for layer in self.foundRectangleOutlineLayers.values {
                        layer.removeFromSuperlayer()
                    }
                    self.foundRectangleOutlineLayers.removeAll()
                    
                    // Remove outline for selected rectangle
                    if let layer = self.selectedRectangleOutlineLayer {
                        layer.removeFromSuperlayer()
                        self.selectedRectangleOutlineLayer = nil
                    }
                    
                    // Display outlines for all found rectangles
                    if self.showFoundRectangles {
                        // Display bounding boxes
                        for observedRect in observations {
                            let points = [observedRect.topLeft, observedRect.topRight, observedRect.bottomRight, observedRect.bottomLeft]
                            let convertedPoints = points.map { self.sceneView.convertFromCamera($0) }
                            let layer = self.drawPolygon(convertedPoints, color: UIColor.blue)
                            self.foundRectangleOutlineLayers[observedRect.uuid] = layer
                            self.sceneView.layer.addSublayer(layer)
                        }
                    }
                    
                    // Find the rect that overlaps with the given location in sceneView
                    guard let selectedRect = observations.filter({ (result) -> Bool in
                        let convertedRect = self.sceneView.convertFromCamera(result.boundingBox)
                        return convertedRect.contains(location)
                    }).first else {
                        return
                    }
                    
                    // Outline selected rectangle
                    let points = [selectedRect.topLeft, selectedRect.topRight, selectedRect.bottomRight, selectedRect.bottomLeft]
                    let convertedPoints = points.map { self.sceneView.convertFromCamera($0) }
                    self.selectedRectangleOutlineLayer = self.drawPolygon(convertedPoints, color: UIColor.red)
                    self.sceneView.layer.addSublayer(self.selectedRectangleOutlineLayer!)
                    
                    // Do stuff with the observed rectangle
                    self.selectedRectangleObservation = selectedRect
                    self.selectedRectangleLastUpdated = Date()
                }
            })
            
            // Don't limit resulting number of observations
            request.maximumObservations = 0
            
            // Perform request
            let handler = VNImageRequestHandler(cvPixelBuffer: currentFrame.capturedImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    private func addPlaneRect(for observedRect: VNRectangleObservation) {
        // Remove old outline of selected rectangle
        if let layer = selectedRectangleOutlineLayer {
            layer.removeFromSuperlayer()
            selectedRectangleOutlineLayer = nil
        }
        
        // Convert to 3D coordinates
        guard let planeRectangle = PlaneRectangle(for: observedRect, in: sceneView) else {
            print("No plane for this rectangle")
            return
        }
        
        let rectangleNode = RectangleNode(planeRectangle)
        rectangleNodes[observedRect.uuid] = rectangleNode
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
