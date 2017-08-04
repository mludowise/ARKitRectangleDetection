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

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    var surfaces = [UUID:SurfaceNode]()
    
    // Dictionary of VNRectangleObservation UUIDs to drawn layers
    var outlineLayers = [UUID:CAShapeLayer]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
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
        //        guard let touch = touches.first else {
        //            return
        //        }
        
        //        let location = touch.location(in: sceneView)
        
        guard let currentFrame = sceneView.session.currentFrame else {
            print("No frame")
            return
        }
        
        DispatchQueue.global(qos: .background).async {
            let request = VNDetectRectanglesRequest(completionHandler: { (request, error) in
                // Jump onto the main thread
                DispatchQueue.main.async {
                    
                    // Access the first result in the array after casting the array as a VNClassificationObservation array
                    guard let results = request.results as? [VNRectangleObservation],
                        let result = results.first else {
                            print ("No results")
                            return
                    }
                    
                    // Convert points to view
                    let points = [result.topLeft, result.topRight, result.bottomRight, result.bottomLeft]
                    let convertedPoints = points.map({ (point) -> CGPoint in
                        return CGPoint(x: point.x * self.sceneView.frame.width, y: (1 - point.y) * self.sceneView.frame.height)
                    })
                    
                    // Outline the rectangle
                    let layer = self.drawPolygon(convertedPoints)
                    self.sceneView.layer.addSublayer(layer)
                    self.outlineLayers[result.uuid] = layer
                    
//                    guard let rectangleNode = RectangleNode(sceneView: self.sceneView, rectangle: result) else {
//                        print("No rectangle on plane")
//                        return
//                    }
//
//                    self.sceneView.scene.rootNode.addChildNode(rectangleNode)
                }
            })
            let handler = VNImageRequestHandler(cvPixelBuffer: currentFrame.capturedImage, options: [:])
            try? handler.perform([request])
        }
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

    
    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
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
}
