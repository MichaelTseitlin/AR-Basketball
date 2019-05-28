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

enum CategoriesBitMask: Int {
    case none = 0b0000
    case ball = 0b0100
    case hoop = 0b1111
}

class ViewController: UIViewController {
    
    private var goalCounter = 0
    private var totalBallsCounter = 0
    
    private var placeCounter = 0
    private var isHoodPlaced = false
    
    @IBOutlet var sceneView: ARSCNView!
    
    @IBOutlet var goalsLabel: UILabel!
    @IBOutlet var totalBalls: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.scene.physicsWorld.contactDelegate = self
        
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
        
        guard let ringNode = hiddenHoopNode.childNode(withName: "ring", recursively: false) else { return }
        
        let ringPosition = ringNode.position
        
        hoopNode.simdTransform = result.worldTransform
        hoopNode.eulerAngles.x -= .pi / 2
        
        hiddenHoopNode.simdTransform = result.worldTransform
        hiddenHoopNode.eulerAngles.x -= .pi / 2
        hiddenHoopNode.scale = SCNVector3(0.5, 0.5, 0.5)
        hiddenHoopNode.opacity = 0
        
        hiddenHoopNode.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: hiddenHoopNode, options: [SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron]))
        
        hiddenHoopNode.physicsBody?.categoryBitMask = CategoriesBitMask.hoop.rawValue
        hiddenHoopNode.physicsBody?.collisionBitMask = CategoriesBitMask.hoop.rawValue
        hiddenHoopNode.physicsBody?.contactTestBitMask = CategoriesBitMask.none.rawValue
        
        
        sceneView.scene.rootNode.enumerateChildNodes { node, _ in
            if node.name == "Hoop" {
                node.removeFromParentNode()
            }
        }
        
        settingGoalChekers(for: hiddenHoopNode, with: ringPosition)
        
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
        
        ball.physicsBody?.categoryBitMask = CategoriesBitMask.ball.rawValue
        ball.physicsBody?.collisionBitMask = CategoriesBitMask.ball.rawValue
        ball.physicsBody?.contactTestBitMask = CategoriesBitMask.none.rawValue
        
        let power = Float(5)
        let x = -cameraTransform.m31 * power
        let y = -cameraTransform.m32 * power
        let z = -cameraTransform.m33 * power
        let force = SCNVector3(x, y, z)
        ball.physicsBody?.applyForce(force, asImpulse: true)
        
        totalBallsCounter += 1
        totalBalls.text = "Out of: \(totalBallsCounter)"
        
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
    
    private func settingGoalChekers(for node: SCNNode, with position: SCNVector3 ) {
        let topChecker = createCheker()
        topChecker.name = "topChecker"
        node.addChildNode(topChecker)
        node.childNode(withName: "topChecker", recursively: false)?.position = SCNVector3(position.x,
                                                                                          position.y + 0.3,
                                                                                          position.z)
        
        let bottomChecker = createCheker()
        bottomChecker.name = "bottomChecker"
        node.addChildNode(bottomChecker)
        node.childNode(withName: "bottomChecker", recursively: false)?.position = SCNVector3(position.x,
                                                                                             position.y - 0.3,
                                                                                             position.z)
        
    }
    
    private func createCheker() -> SCNNode {
        
        let plane = SCNNode(geometry: SCNPlane(width: 0.25, height: 0.25))
        plane.geometry?.firstMaterial?.diffuse.contents = UIColor.clear
        plane.eulerAngles.x = -.pi / 2
        
        let body = SCNPhysicsBody(type: .kinematic, shape: SCNPhysicsShape(node: plane))
        plane.physicsBody = body
        plane.physicsBody?.categoryBitMask = CategoriesBitMask.none.rawValue
        plane.physicsBody?.collisionBitMask = CategoriesBitMask.none.rawValue
        plane.physicsBody?.contactTestBitMask = CategoriesBitMask.ball.rawValue
        
        return plane
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

// MARK: - SCNPhysicsContactDelegate
extension ViewController: SCNPhysicsContactDelegate {
    
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        
        let nodeA = contact.nodeA
        let nodeB = contact.nodeB
        
        let nameA = nodeA.name
        let nameB = nodeB.name
        
        if nameA == "topChecker", nameB == "ball" {
            nodeB.name = "topChekerIsPassed"
        }
        
        if nameA == "bottomChecker", nameB == "topChekerIsPassed" {
            nodeB.name = "Goal"
            
            goalCounter += 1
            
            DispatchQueue.main.async {
                self.goalsLabel.text = "Hits: \(self.goalCounter)"
            }
        }
    }
}
