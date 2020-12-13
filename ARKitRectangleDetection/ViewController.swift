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

    // MARK: - IBOutlets
    
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var messageView: UIView!
    @IBOutlet weak var clearButton: UIButton!
    @IBOutlet weak var restartButton: UIButton!
    @IBOutlet weak var debugButton: UIButton!
    
    
    // MARK: - Internal properties used to identify the rectangle the user is selecting

    private var identifiedRectangleOutlineLayers: [CAShapeLayer] = []
    
    // Displayed rectangle outline
    private var selectedRectangleOutlineLayer: CAShapeLayer?
    
    // Observed rectangle currently being touched
    private var selectedRectangleObservation: VNRectangleObservation?

    private var cameraTransform: CGAffineTransform = .identity
    
    // The time the current rectangle selection was last updated
    private var selectedRectangleLastUpdated: Date?
    
    // Current touch location
    private var currTouchLocation: CGPoint?
    
    // Gets set to true when actively searching for rectangles in the current frame
    private var searchingForRectangles = false
    
    
    // MARK: - Rendered items
    
    // RectangleNodes with keys for rectangleObservation.uuid
    private var rectangleNodes = [VNRectangleObservation:RectangleNode]()
    
    // Used to lookup SurfaceNodes by planeAnchor and update them
    private var surfaceNodes = [ARPlaneAnchor:SurfaceNode]()
    
    // MARK: - Debug properties
    
    var showDebugOptions = false {
        didSet {
            if showDebugOptions {
                sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
            } else {
              sceneView.debugOptions = []
            }
        }
    }
    
    
    // MARK: - Message displayed to the user
    
    private var message: Message? {
        didSet {
            DispatchQueue.main.async {
                if let message = self.message {
                    self.messageView.isHidden = false
                    self.messageLabel.text = message.localizedString
                    self.messageLabel.numberOfLines = 0
                    self.messageLabel.sizeToFit()
                    self.messageLabel.superview?.setNeedsLayout()
                } else {
                    self.messageView.isHidden = true
                }
            }
        }
    }
    
    
    // MARK: - UIViewController
    
    override var prefersStatusBarHidden: Bool {
        get {
            return true
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegates
        sceneView.delegate = self
        
        // Comment out to disable rectangle tracking
        sceneView.session.delegate = self
        
        // Show world origin and feature points if desired
        if showDebugOptions {
            sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
        }

        // Enable default lighting
        sceneView.autoenablesDefaultLighting = true
        
        // Create a new scene
        let scene = SCNScene()
        sceneView.scene = scene
        
        // Don't display message
        message = nil
        
        // Style clear button
        styleButton(clearButton, localizedTitle: NSLocalizedString("Clear Rects", comment: ""))
        styleButton(restartButton, localizedTitle: NSLocalizedString("Restart", comment: ""))
        styleButton(debugButton, localizedTitle: NSLocalizedString("Debug", comment: ""))
        debugButton.isSelected = showDebugOptions
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        
        // Run the view's session
        sceneView.session.run(configuration)
        
        // Tell user to find the a surface if we don't know of any
        if surfaceNodes.isEmpty {
            message = .helpFindSurface
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
            let currentFrame = sceneView.session.currentFrame else {
            return
        }
        
        currTouchLocation = touch.location(in: sceneView)
        findRectangle(locationInScene: currTouchLocation!, frame: currentFrame)
        message = .helpTapReleaseRect
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
        message = .helpTapHoldRect

        guard let selectedRect = selectedRectangleObservation else {
            return
        }
        
        // Create a planeRect and add a RectangleNode
        addPlaneRect(for: selectedRect, transform: cameraTransform)
    }
    
    // MARK: - IBOutlets
    
    @IBAction func onClearButton(_ sender: Any) {
        rectangleNodes.forEach({ $1.removeFromParentNode() })
        rectangleNodes.removeAll()
    }
    
    @IBAction func onRestartButton(_ sender: Any) {
        // Remove all rectangles
        rectangleNodes.forEach({ $1.removeFromParentNode() })
        rectangleNodes.removeAll()
        
        // Remove all surfaces and tell session to forget about anchors
        surfaceNodes.forEach { (anchor, surfaceNode) in
            sceneView.session.remove(anchor: anchor)
            surfaceNode.removeFromParentNode()
        }
        surfaceNodes.removeAll()
        
        // Update message
        message = .helpFindSurface
    }
    
    @IBAction func onDebugButton(_ sender: Any) {
        showDebugOptions = !showDebugOptions
        debugButton.isSelected = showDebugOptions
        
        if showDebugOptions {
            debugButton.layer.backgroundColor = UIColor.yellow.cgColor
            debugButton.layer.borderColor = UIColor.yellow.cgColor
        } else {
            debugButton.layer.backgroundColor = UIColor.black.withAlphaComponent(0.5).cgColor
            debugButton.layer.borderColor = UIColor.white.cgColor
        }
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
        guard let anchor = anchor as? ARPlaneAnchor else {
            return
        }
        
        let surface = SurfaceNode(anchor: anchor)
        surfaceNodes[anchor] = surface
        node.addChildNode(surface)
        
        if message == .helpFindSurface {
            message = .helpTapHoldRect
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // See if this is a plane we are currently rendering
        guard let anchor = anchor as? ARPlaneAnchor,
            let surface = surfaceNodes[anchor] else {
                return
        }
        
        surface.update(anchor)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        guard let anchor = anchor as? ARPlaneAnchor,
            let surface = surfaceNodes[anchor] else {
                return
        }

        surface.removeFromParentNode()
        
        surfaceNodes.removeValue(forKey: anchor)
    }
    
    // MARK: - Helper Methods
    
    // Updates selectedRectangleObservation with the the rectangle found in the given ARFrame at the given location
    private func findRectangle(locationInScene location: CGPoint, frame currentFrame: ARFrame) {
        // Note that we're actively searching for rectangles
        searchingForRectangles = true
        selectedRectangleObservation = nil

        let interfaceOrientation = UIApplication.shared.statusBarOrientation
        let imageOrientation = interfaceOrientation.imageOrientation
        let sceneSize = sceneView.frame.size

        let fromCameraImageToViewTransform = currentFrame.displayTransformCorrected(
          for: interfaceOrientation,
          viewportSize: sceneSize
        )

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
                            self.message = .errNoRect
                            return
                    }
                    
                    print("\(observations.count) rectangles found")

                    // Remove outline for selected rectangle
                    if let layer = self.selectedRectangleOutlineLayer {
                        layer.removeFromSuperlayer()
                        self.selectedRectangleOutlineLayer = nil
                    }
                    self.identifiedRectangleOutlineLayers.forEach { $0.removeFromSuperlayer() }

                    // Draw outline for all detected rectangles
                    self.identifiedRectangleOutlineLayers = observations.map({ observation in
                        let normalizedPoints = [observation.topLeft, observation.topRight, observation.bottomRight, observation.bottomLeft]
                        let convertedPoints = normalizedPoints.map { $0.applying(fromCameraImageToViewTransform) }
                        let layer = self.drawPolygon(convertedPoints, color: .yellow)
                        self.sceneView.layer.addSublayer(layer)
                        return layer
                    })

                    // Find the rect that overlaps with the given location in sceneView
                    guard let selectedRect = observations.filter({ (result) -> Bool in
                        let convertedRect = result.boundingBox.applying(fromCameraImageToViewTransform)
                        return convertedRect.contains(location)
                    }).first else {
                        print("No results at touch location")
                        self.message = .errNoRect
                        return
                    }
                    
                    // Outline selected rectangle
                    let points = [selectedRect.topLeft, selectedRect.topRight, selectedRect.bottomRight, selectedRect.bottomLeft]
                    let convertedPoints = points.map { $0.applying(fromCameraImageToViewTransform) }
                    self.selectedRectangleOutlineLayer = self.drawPolygon(convertedPoints, color: UIColor.red)
                    self.sceneView.layer.addSublayer(self.selectedRectangleOutlineLayer!)
                    
                    // Track the selected rectangle and when it was found
                    self.selectedRectangleObservation = selectedRect
                    self.selectedRectangleLastUpdated = Date()
                    self.cameraTransform = fromCameraImageToViewTransform
                    
                    // Check if the user stopped touching the screen while we were in the background.
                    // If so, then we should add the planeRect here instead of waiting for touches to end.
                    if self.currTouchLocation == nil {
                        // Create a planeRect and add a RectangleNode
                        self.addPlaneRect(for: selectedRect, transform: fromCameraImageToViewTransform)
                    }
                }
            })
            
            // Don't limit resulting number of observations
            request.maximumObservations = 0
            
            // Perform request
            let handler = VNImageRequestHandler(cvPixelBuffer: currentFrame.capturedImage,
                                                orientation: imageOrientation,
                                                options: [:])
            try? handler.perform([request])
        }
    }
    
    private func addPlaneRect(for observedRect: VNRectangleObservation, transform: CGAffineTransform) {
        // Remove old outline of selected rectangle
        if let layer = selectedRectangleOutlineLayer {
            layer.removeFromSuperlayer()
            selectedRectangleOutlineLayer = nil
        }
        
        // Convert to 3D coordinates
        guard let planeRectangle = PlaneRectangle(for: observedRect, in: sceneView, with: transform) else {
            print("No plane for this rectangle")
            message = .errNoPlaneForRect
            return
        }
        
        let rectangleNode = RectangleNode(planeRectangle)
        rectangleNodes[observedRect] = rectangleNode
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

        layer.addSublayer(drawPoint(points[0], color: .red))
        layer.addSublayer(drawPoint(points[1], color: .green))
        layer.addSublayer(drawPoint(points[2], color: .blue))
        layer.addSublayer(drawPoint(points[3], color: .yellow))

        return layer
    }

    private func drawPoint(_ point: CGPoint, color: UIColor, radius: CGFloat = 5) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.fillColor = color.cgColor
        let path = UIBezierPath(ovalIn: CGRect(
            x: point.x - radius,
            y: point.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
        layer.path = path.cgPath
        return layer
    }
    
    private func styleButton(_ button: UIButton, localizedTitle: String?) {
        button.layer.borderColor = UIColor.white.cgColor
        button.layer.borderWidth = 1
        button.layer.cornerRadius = 4
        button.setTitle(localizedTitle, for: .normal)
    }
}
