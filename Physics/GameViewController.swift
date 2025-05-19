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
    private var pauseBtn: NSButton!
    private var resetBtn: NSButton!
    
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

        newRenderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)
        renderer = newRenderer
        mtkView.delegate = renderer
        
        func makeButton(title: String, action: Selector, x: CGFloat) -> NSButton {
            let b = NSButton(title: title, target: self, action: action)
            b.bezelStyle = .rounded
            b.frame = CGRect(x: x, y: view.bounds.height - 34, width: 80, height: 24)
            b.autoresizingMask = [.minYMargin, .maxXMargin]
            view.addSubview(b)
            return b
        }
        pauseBtn = makeButton(title: "Pause",  action: #selector(togglePause), x: 10)
        resetBtn = makeButton(title: "Reset",  action: #selector(doReset),    x: 100)
        
    }
    
    // REPLACE: keyDown / keyUp to update set & forward to renderer
    override func keyDown(with event: NSEvent) {
        if let char = event.charactersIgnoringModifiers?.lowercased() {
            if char == "d" {
                renderer.debugEnabled.toggle()
                return
            } else if char == "m" {
                renderer.showMuscles.toggle()
                return
            } else if char == "+" || char == "=" {
                renderer.timeScale = min(renderer.timeScale + 0.25, 4.0)
                return
            } else if char == "-" {
                renderer.timeScale = max(renderer.timeScale - 0.25, 0.25)
                return
            }
        }

        keysHeld.insert(event.keyCode)
        renderer.keysHeld = keysHeld
    }
    
    override func keyUp(with event: NSEvent) {
        keysHeld.remove(event.keyCode)
        renderer.keysHeld = keysHeld
    }
    
    // override first-responder (already present or add if missing)
    override var acceptsFirstResponder: Bool { true }
    
    // MARK: - Button actions
    @objc private func togglePause() {
        renderer.paused.toggle()
        pauseBtn.title = renderer.paused ? "Resume" : "Pause"
    }
    
    @objc private func doReset() {
        renderer.resetSkeleton()
    }
    
}
