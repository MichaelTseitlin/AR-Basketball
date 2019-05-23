//
//  ViewController.swift
//  AR Basketball
//
//  Created by Michael Tseitlin on 5/23/19.
//  Copyright © 2019 Michael Tseitlin. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    private var placeCounter = 0
    private var isHoodPlaced = false
    
    @IBOutlet var sceneView: ARSCNView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        configuration.planeDetection = [.vertical]

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
}

// MARK: - IB Actions
extension ViewController {
    @IBAction func screenTaped(_ sender: UITapGestureRecognizer) {
        if isHoodPlaced {
            
        } else {
            let location = sender.location(in: sceneView)
            guard let result = sceneView.hitTest(location, types: [.existingPlaneUsingExtent]).first else { return }
            addHoop(at: result)
        }
    }
}

// MARK: - Custom methods
extension ViewController {
    private func addHoop(at result: ARHitTestResult) {
        let hoofScene = SCNScene(named: "art.scnassets/Hoop.dae")
        guard let hoopNode = hoofScene?.rootNode.childNode(withName: "Hoop", recursively: false) else { return }
        
        hoopNode.simdTransform = result.worldTransform
        hoopNode.eulerAngles = SCNVector3(0, 0, 0)
        
        sceneView.scene.rootNode.enumerateChildNodes { node, _ in
            if node.name == "Hoop" {
                node.removeFromParentNode()
            }
        }
        
        sceneView.scene.rootNode.addChildNode(hoopNode)
        isHoodPlaced = true
    }
    
    private func createFloor(planeAnchor: ARPlaneAnchor) -> SCNNode {
        let extent = planeAnchor.extent
        let width = CGFloat(extent.x)
        let height = CGFloat(extent.z)
        
        let plane = SCNPlane(width: width, height: height)
        plane.firstMaterial?.diffuse.contents = UIColor.blue
        
        let node = SCNNode(geometry: plane)
        node.eulerAngles.x = -.pi / 2
        node.opacity = 0.125
        
        return node
    }
}

// MARK: - ARSCNViewDelegate
extension ViewController {
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        guard !isHoodPlaced else { return }
        
        let floor = createFloor(planeAnchor: planeAnchor)
        floor.name = "Hoop"
        node.addChildNode(floor)
        
        placeCounter += 1
        print(placeCounter)
    }
}
