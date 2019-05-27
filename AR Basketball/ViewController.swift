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

class ViewController: UIViewController {
    
    private let noneCategory = 0
    private let ballCategory:UInt32 = 0x1 << 0 // 1
    private let topCheckerCategory: UInt32 = 0x1 << 1 // 2
    private let bottomChekerCategory: UInt32 = 0x1 << 2 // 4
    
    private var countBeginnings = 0
    private var countEndings = 0
    
    private var placeCounter = 0
    private var isHoodPlaced = false
    private var ballCollusion = false
    private var resultCollusion = false
    
    @IBOutlet var sceneView: ARSCNView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        sceneView.debugOptions = [.showWorldOrigin, .showFeaturePoints]
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
            createBasketball()
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
        let hoofScene = SCNScene(named: "art.scnassets/Hoop.scn")
        guard let hoopNode = hoofScene?.rootNode.childNode(withName: "Hoop", recursively: false) else { return }
        guard let hiddenHoopNode = hoofScene?.rootNode.childNode(withName: "HiddenHoop", recursively: false) else { return }
        
        setupCheckNodes(hiddenHoopNode: hiddenHoopNode)
        
        hoopNode.simdTransform = result.worldTransform
        hoopNode.eulerAngles = SCNVector3(0, 0, 0)
        
        hiddenHoopNode.simdTransform = result.worldTransform
        hiddenHoopNode.eulerAngles = SCNVector3(0, 0, 0)
        hiddenHoopNode.scale = SCNVector3(0.5, 0.5, 0.5)
        //        hiddenHoopNode.opacity = 0
        
        hiddenHoopNode.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: hiddenHoopNode, options: [SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron]))
        
        sceneView.scene.rootNode.enumerateChildNodes { node, _ in
            if node.name == "Hoop" {
                node.removeFromParentNode()
            }
        }
        
        sceneView.scene.physicsWorld.contactDelegate = self
        sceneView.scene.rootNode.addChildNode(hiddenHoopNode)
        sceneView.scene.rootNode.addChildNode(hoopNode)
        isHoodPlaced = true
    }
    
    private func createBasketball() {
        guard let frame = sceneView.session.currentFrame else { return }
        
        let ball = SCNNode(geometry: SCNSphere(radius: 0.125))
        ball.name = "ball"
        ball.geometry?.firstMaterial?.diffuse.contents = UIImage(named: "basketball")
        
        let cameraTransform = SCNMatrix4(frame.camera.transform)
        ball.transform = cameraTransform
        
        let physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: ball))
        ball.physicsBody = physicsBody
        
        ball.physicsBody?.categoryBitMask = Int(ballCategory)
        ball.physicsBody?.contactTestBitMask = Int(topCheckerCategory) | Int(bottomChekerCategory) | Int(ballCategory)
        ball.physicsBody?.collisionBitMask = Int(topCheckerCategory) | Int(bottomChekerCategory) | Int(ballCategory)
        
        let power = Float(5)
        let x = -cameraTransform.m31 * power
        let y = -cameraTransform.m32 * power
        let z = -cameraTransform.m33 * power
        let force = SCNVector3(x, y, z)
        ball.physicsBody?.applyForce(force, asImpulse: true)
        
        sceneView.scene.rootNode.addChildNode(ball)
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
    
    private func setupCheckNodes(hiddenHoopNode: SCNNode) {
        guard let ringNode = hiddenHoopNode.childNode(withName: "ring", recursively: false) else { return }
        
        guard let nodeA = ringNode.childNode(withName: "nodeA", recursively: false) else { return }
        nodeA.name = "nodeA"
        nodeA.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: nodeA.geometry!))
        
        guard let nodeB = ringNode.childNode(withName: "nodeB", recursively: false) else { return }
        nodeB.name = "nodeB"
        nodeB.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: nodeB.geometry!))
        
        nodeA.physicsBody?.categoryBitMask = Int(topCheckerCategory)
        nodeA.physicsBody?.collisionBitMask = Int(ballCategory)
        nodeA.physicsBody?.contactTestBitMask = Int(ballCategory)
        nodeB.physicsBody?.categoryBitMask = Int(bottomChekerCategory)
        nodeB.physicsBody?.contactTestBitMask = Int(ballCategory)
        nodeB.physicsBody?.collisionBitMask = Int(ballCategory)
        
    }
}

// MARK: - ARSCNViewDelegate
extension ViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        guard !isHoodPlaced else { return }
        
        let floor = createFloor(planeAnchor: planeAnchor)
        floor.name = "Hoop"
        node.addChildNode(floor)
        
        placeCounter += 1
    }
}

extension ViewController: SCNPhysicsContactDelegate {
    
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        //        print(#line, #function, "WORK")
        print("NodeA:", contact.nodeA.name)
        print("NodeB:", contact.nodeB.name)
        
        if ballCollusion == false {
            if (contact.nodeA.name! == "ball" && contact.nodeB.name! == "nodeA") {
                ballCollusion.toggle()
                print(#line, #function, "ballColliusstion = true")
            }
        }
        
        if (ballCollusion == true) && (resultCollusion == false) {
            if (contact.nodeA.name! == "ball" && contact.nodeB.name! == "nodeA") {
                ballCollusion.toggle()
                print(#line, #function, "SCORES +1")
            }
        }
    }
    
    func physicsWorld(_ world: SCNPhysicsWorld, didEnd contact: SCNPhysicsContact) {
        //        countEndings += 1
        //        print(#line, #function, "YES!")
        
        //        print("(" + String(countEndings) + ") " + contact.nodeA.name! + " ended contact with " + contact.nodeB.name!)
    }
}


