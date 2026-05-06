import SceneKit
import SwiftUI

/// A photoreal physically-based material rendered through SceneKit.
/// Consumes the standard PBR map set (color, normal, roughness, metalness,
/// ambient occlusion) from the asset catalog and lights it with a soft
/// directional key plus a warm ambient.
///
/// **Use sparingly.** Every PBRMaterialView is a 3D scene under the hood
/// — fine for a few hero elements (cigar wrapper, Light Up button face,
/// gold band) but expensive as a blanket background.
///
/// ### Asset naming convention
///
/// Pass a `set` like `"gold"` and the view loads:
///   - `gold_color`        (required)
///   - `gold_normal`       (optional but the whole point)
///   - `gold_roughness`    (optional)
///   - `gold_metalness`    (optional)
///   - `gold_ao`           (optional)
///
/// Drop each map into Assets.xcassets with those exact names. Missing
/// maps fall through to sensible defaults (uniform value).
///
/// ### Sourcing
///
/// PBR packs from https://ambientcg.com or https://polyhaven.com/textures
/// arrive with the maps named after their type. Rename or duplicate them
/// to fit the convention above when adding to the catalog.
struct PBRMaterialView: UIViewRepresentable {
    /// Asset prefix. e.g. "gold" -> loads `gold_color`, `gold_normal`, etc.
    let set: String

    /// Tint applied on top of the color map (via material.multiply). Use
    /// to bias gold toward your goldHi/goldLo tokens, leather toward
    /// warmth, etc. Default is white = no tint.
    var tint: UIColor = .white

    /// Direction of the key light, in radians. Default is upper-left to
    /// match how light falls in the rest of the app.
    var lightAzimuth: Float = -0.6  // x rotation
    var lightElevation: Float = -0.4 // y rotation

    /// Overall scene exposure. 1.0 is the default; raise to 1.4–1.8 for
    /// gold/metal surfaces, lower to ~0.8 for matte leather.
    var exposure: CGFloat = 1.0

    /// How tightly to crop the plane. 1.0 fills the view exactly; <1.0
    /// shows more of the texture (zoom out) and >1.0 zooms in.
    var coverage: CGFloat = 1.0

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.allowsCameraControl = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 30
        view.scene = makeScene()
        return view
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        // Re-apply when bindings change. Cheap because we just swap one node.
        scnView.scene = makeScene()
    }

    // MARK: Scene construction

    private func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        // Plane node — sized 1x1 in scene units, camera placed for full coverage.
        let plane = SCNPlane(width: 1, height: 1)
        plane.firstMaterial = makeMaterial()
        let planeNode = SCNNode(geometry: plane)
        scene.rootNode.addChildNode(planeNode)

        // Camera positioned to fill the view at the requested coverage.
        let camera = SCNCamera()
        camera.fieldOfView = 60
        camera.zNear = 0.05
        camera.zFar = 5
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        // Distance derived from FOV so the plane fills the frame at coverage = 1.
        let halfFov = 60.0 * .pi / 180 / 2
        let dist: Float = Float(0.5 / tan(halfFov)) / Float(coverage)
        cameraNode.position = SCNVector3(0, 0, dist)
        scene.rootNode.addChildNode(cameraNode)

        // Key light — directional, gives the surface its dimensionality.
        let key = SCNLight()
        key.type = .directional
        key.intensity = 900 * exposure
        key.color = UIColor(red: 1.0, green: 0.95, blue: 0.85, alpha: 1)
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.eulerAngles = SCNVector3(lightAzimuth, lightElevation, 0)
        scene.rootNode.addChildNode(keyNode)

        // Warm ambient — fills the shadow side so it doesn't read pure black.
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 220 * exposure
        ambient.color = UIColor(red: 0.95, green: 0.85, blue: 0.7, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        return scene
    }

    private func makeMaterial() -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased

        if let color = UIImage(named: "\(set)_color") {
            material.diffuse.contents = color
        } else {
            material.diffuse.contents = UIColor.darkGray
        }
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .repeat

        if let normal = UIImage(named: "\(set)_normal") {
            material.normal.contents = normal
            material.normal.intensity = 1.0
        }
        if let rough = UIImage(named: "\(set)_roughness") {
            material.roughness.contents = rough
        } else {
            material.roughness.contents = 0.4 as NSNumber
        }
        if let metal = UIImage(named: "\(set)_metalness") {
            material.metalness.contents = metal
        } else {
            material.metalness.contents = 0.0 as NSNumber
        }
        if let ao = UIImage(named: "\(set)_ao") {
            material.ambientOcclusion.contents = ao
        }

        if tint != .white {
            material.multiply.contents = tint
        }

        material.isDoubleSided = false
        return material
    }
}
