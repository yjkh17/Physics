//
//  GameViewController.swift
//  Physics
//
//  Created by Yousef Jawdat on 15/05/2025.
//

import Cocoa
import MetalKit

// Our macOS specific view controller
class GameViewController: NSViewController {

    var renderer: Renderer!
    var mtkView: MTKView!

    private var keysHeld = Set<UInt16>()

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let mtkView = self.view as? MTKView else {
            print("View attached to GameViewController is not an MTKView")
            return
        }

        // Select the device to render with.  We choose the default device
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported on this device")
            return
        }

        mtkView.device = defaultDevice

        guard let newRenderer = Renderer(metalKitView: mtkView) else {
            print("Renderer cannot be initialized")
            return
        }

        renderer = newRenderer

        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)

        mtkView.delegate = renderer
    }

    // REPLACE: keyDown / keyUp to update set & forward to renderer
    override func keyDown(with event: NSEvent) {
        keysHeld.insert(event.keyCode)
        renderer.keysHeld = keysHeld          // forward
    }

    override func keyUp(with event: NSEvent) {
        keysHeld.remove(event.keyCode)
        renderer.keysHeld = keysHeld
    }

    // override first-responder (already present or add if missing)
    override var acceptsFirstResponder: Bool { true }
}
