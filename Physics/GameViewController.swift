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
    private var speedSlider: NSSlider!
    private var muscleSlider: NSSlider!
    private var gravitySlider: NSSlider!
    private var dampingSlider: NSSlider!
    
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
        
        speedSlider = NSSlider(value: 1.0,
                               minValue: 0.1,
                               maxValue: 2.0,
                               target: self,
                               action: #selector(speedChanged))
        speedSlider.frame = CGRect(x: 200, y: view.bounds.height - 30,
                                   width: 150, height: 20)
        speedSlider.isContinuous = true
        speedSlider.autoresizingMask = [.minYMargin, .maxXMargin]
        view.addSubview(speedSlider)

        muscleSlider = NSSlider(value: 0.5,
                                minValue: 0.1,
                                maxValue: 1.0,
                                target: self,
                                action: #selector(muscleChanged))
        muscleSlider.frame = CGRect(x: 370, y: view.bounds.height - 30,
                                    width: 150, height: 20)
        muscleSlider.isContinuous = true
        muscleSlider.autoresizingMask = [.minYMargin, .maxXMargin]
        view.addSubview(muscleSlider)

        gravitySlider = NSSlider(value: 1.0,
                                 minValue: 0.1,
                                 maxValue: 2.0,
                                 target: self,
                                 action: #selector(gravityChanged))
        gravitySlider.frame = CGRect(x: 540, y: view.bounds.height - 30,
                                     width: 150, height: 20)
        gravitySlider.isContinuous = true
        gravitySlider.autoresizingMask = [.minYMargin, .maxXMargin]
        view.addSubview(gravitySlider)

        dampingSlider = NSSlider(value: 0.98,
                                 minValue: 0.90,
                                 maxValue: 1.0,
                                 target: self,
                                 action: #selector(dampingChanged))
        dampingSlider.frame = CGRect(x: 710, y: view.bounds.height - 30,
                                     width: 150, height: 20)
        dampingSlider.isContinuous = true
        dampingSlider.autoresizingMask = [.minYMargin, .maxXMargin]
        view.addSubview(dampingSlider)
    }
    
    // REPLACE: keyDown / keyUp to update set & forward to renderer
    override func keyDown(with event: NSEvent) {
        // toggle debug printout
        if event.charactersIgnoringModifiers?.lowercased() == "d" {
            renderer.debugEnabled.toggle()
            return
        }
        
        keysHeld.insert(event.keyCode)
        renderer.keysHeld = keysHeld          // forward
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
    
    // MARK: - Slider
    @objc private func speedChanged() {
        renderer.timeScale = Float(speedSlider.doubleValue)
    }

    @objc private func muscleChanged() {
        renderer.muscleScale = Float(muscleSlider.doubleValue)
    }

    @objc private func gravityChanged() {
        renderer.gravityScale = Float(gravitySlider.doubleValue)
    }

    @objc private func dampingChanged() {
        renderer.damping = Float(dampingSlider.doubleValue)
    }
}
