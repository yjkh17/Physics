//
//  Renderer.swift
//  Physics – minimal 2-D playground
//
import MetalKit
import simd
import Foundation

// MARK: ‑ Shared types
private struct SimpleVertex {
    var position : SIMD3<Float>
}

private struct Uniforms {
    var projectionMatrix : matrix_float4x4
    var modelViewMatrix  : matrix_float4x4
    var color            : SIMD4<Float>
}

// MARK: ‑ Renderer
final class Renderer: NSObject, MTKViewDelegate {
    
    // ── Metal objects ──────────────────────────────────────────────
    private let device       : MTLDevice
    private let queue        : MTLCommandQueue
    private let pipeline     : MTLRenderPipelineState
    
    // Buffers
    private let groundVB     : MTLBuffer
    private let boneVB       : MTLBuffer    // unit quad for limbs
    
    // ── Input / physics state ─────────────────────────────────────
    // Fixed simulation parameters (sliders removed)
    var muscleScale: Float = 0.0
    var gravityScale: Float = 1.0
    var damping: Float = 0.98
    var debugEnabled = false       // toggled by “D”
    /// Toggle drawing the yellow muscles.  Disabled while we’re working on the skeleton.
    var showMuscles = false
    var   keysHeld           = Set<UInt16>()          // updated by view-controller
    private var lastTime : CFTimeInterval = 0
    private var debugFrames = 0   // print first 120 frames
    
    private let groundY   : Float = Config.groundY          // y‑position of the ground plane
    private var skel = Skeleton.twoLegs()
    var paused = false
    var timeScale: Float = 1.0
 
    func resetSkeleton() { skel = Skeleton.twoLegs() }
    
    // MARK: ‑ Init
    init?(metalKitView view: MTKView) {
        guard let dev = view.device ?? MTLCreateSystemDefaultDevice() else { return nil }
        device = dev
        queue  = device.makeCommandQueue()!
        
        // Pipeline (simple colour pass)
        let lib   = device.makeDefaultLibrary()!
        let vDesc: MTLVertexDescriptor = {
            let vd = MTLVertexDescriptor()
            // position ─ float3 @ offset 0, buffer 0
            vd.attributes[0].format      = .float3
            vd.attributes[0].offset      = 0
            vd.attributes[0].bufferIndex = 0
            // single interleaved layout
            vd.layouts[0].stride         = MemoryLayout<SimpleVertex>.stride   // 12 bytes
            vd.layouts[0].stepFunction   = .perVertex
            return vd
        }()
        
        let desc  = MTLRenderPipelineDescriptor()
        desc.vertexFunction   = lib.makeFunction(name: "vertexShader")
        desc.fragmentFunction = lib.makeFunction(name: "fragmentShader")
        desc.colorAttachments[0].pixelFormat = view.colorPixelFormat
        desc.vertexDescriptor  = vDesc
        pipeline = try! device.makeRenderPipelineState(descriptor: desc)
        
        // Quad helpers
        func makeQuad(width: Float, height: Float) -> [SimpleVertex] {
            let hw = width  * 0.5, hh = height * 0.5
            return [
                .init(position:[-hw,-hh,0]),
                .init(position:[ hw,-hh,0]),
                .init(position:[-hw, hh,0]),
                .init(position:[ hw, hh,0])
            ]
        }
        
        // Ground (span ±10, thickness 0.2)
        let gVerts  = makeQuad(width: 20, height: 0.2)
        groundVB    = device.makeBuffer(bytes: gVerts,
                                        length: MemoryLayout<SimpleVertex>.stride*4)!
        
        // Unit quad (1 × 1) for bones
        let bVerts = makeQuad(width: 1, height: 1)
        boneVB = device.makeBuffer(bytes: bVerts,
                                   length: MemoryLayout<SimpleVertex>.stride * 4)!
        
        super.init()
    }
    
    // MARK: ‑ MTKViewDelegate
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }
    
    func draw(in view: MTKView) {
        // ‑- timing
        guard !paused else { return }          // skip updates & drawing when paused
        let now = CACurrentMediaTime()
        let dt  = lastTime == 0 ? 1/60.0 : now - lastTime
        lastTime = now

        // ── fixed-timestep integration (max 1/120 s) ────────────────
        var simTime = Float(dt) * timeScale
        let stepSize: Float = 1.0 / 120.0          // 120 Hz physics
        while simTime > 0 {
            let subDt = min(stepSize, simTime)
            updateGame(dt: subDt)
            simTime   -= subDt
        }
        
        if debugEnabled && debugFrames < 120 {
            for (i, b) in skel.bones.enumerated() {
                print(String(format: "frame %03d  bone[%d]  A(%.2f,%.2f)  B(%.2f,%.2f)",
                             debugFrames, i,
                             b.pA.x, b.pA.y,
                             b.pB.x, b.pB.y))
            }
            debugFrames += 1
        }

        guard
            let pass = view.currentRenderPassDescriptor,
            let cmd  = queue.makeCommandBuffer(),
            let enc  = cmd.makeRenderCommandEncoder(descriptor: pass),
            let drawable = view.currentDrawable
        else { return }

        enc.setRenderPipelineState(pipeline)

        // orthographic projection
        let projScale: Float = 0.1
        let proj = matrix_float4x4(diagonal: [projScale, projScale, 1, 1])
        // camera: keep pelvis centred in view
        let cam = skel.bones.first?.pA ?? SIMD2<Float>(0,0)

        // ── draw ground ─────────────────────────────────────────
        // translate ground quad so its centre sits at groundY - halfThickness (-0.1)
        let groundCentreY: Float = groundY - 0.1 - cam.y          // apply camera
        let gMV = matrix_float4x4(columns: (
            SIMD4<Float>(1,0,0,0),
            SIMD4<Float>(0,1,0,0),
            SIMD4<Float>(0,0,1,0),
            SIMD4<Float>(-cam.x, groundCentreY, 0, 1)
        ))
        var gUni = Uniforms(projectionMatrix: proj,
                            modelViewMatrix: gMV,
                            color: SIMD4<Float>(1,0,0,1))
        enc.setVertexBytes(&gUni,
                           length: MemoryLayout<Uniforms>.stride,
                           index: 2)
        enc.setFragmentBytes(&gUni,
                             length: MemoryLayout<Uniforms>.stride,
                             index: 2)
        enc.setVertexBuffer(groundVB, offset: 0, index: 0)
        enc.drawPrimitives(type: MTLPrimitiveType.triangleStrip,
                           vertexStart: 0,
                           vertexCount: 4)

        // ── draw muscles (yellow) FIRST – bones (white) will be drawn on top ───────────
        if showMuscles {
            for m in skel.muscles {
                let bi = skel.bones[m.i]
                let bj = skel.bones[m.j]
                let pi = bi.pA + (bi.pB - bi.pA) * m.u
                let pj = bj.pA + (bj.pB - bj.pA) * m.v
                var d  = pj - pi
                let len = length(d)
                if len < 1e-5 { continue }
                let center = 0.5 * (pi + pj)
                d /= len
                let angle = atan2(d.y, d.x)
                let c = cos(angle), s = sin(angle)
                let rot = matrix_float4x4(columns: (
                    SIMD4<Float>( c, s,0,0),
                    SIMD4<Float>(-s, c,0,0),
                    SIMD4<Float>( 0, 0,1,0),
                    SIMD4<Float>( 0, 0,0,1)))
                let scale = matrix_float4x4(diagonal: [len, 0.25, 1, 1]) // thinner strap
                let trans = matrix_float4x4(columns: (
                    SIMD4<Float>(1,0,0,0),
                    SIMD4<Float>(0,1,0,0),
                    SIMD4<Float>(0,0,1,0),
                    SIMD4<Float>(center.x - cam.x, center.y - cam.y, 0, 1)))
                var mUni = Uniforms(projectionMatrix: proj,
                                    modelViewMatrix: trans * rot * scale,
                                    color: SIMD4<Float>(1,1,0,1))        // yellow muscles
                enc.setVertexBytes(&mUni, length: MemoryLayout<Uniforms>.stride, index: 2)
                enc.setFragmentBytes(&mUni, length: MemoryLayout<Uniforms>.stride, index: 2)
                enc.setVertexBuffer(boneVB, offset: 0, index: 0)
                enc.drawPrimitives(type: .triangleStrip,
                                   vertexStart: 0,
                                   vertexCount: 4)
            }
        }

        // ── draw bones ON TOP ─────────────────────────────────────
        for b in skel.bones {
            let len = length(b.pB - b.pA)
            if len < 1e-5 { continue }    // skip zero-length bone
            let center = 0.5*(b.pA + b.pB)
            let dir    = (b.pB - b.pA) / len
            let c = cos(atan2(dir.y, dir.x))
            let s = sin(atan2(dir.y, dir.x))
            let rot = matrix_float4x4(columns: (
                SIMD4<Float>( c, s,0,0),
                SIMD4<Float>(-s, c,0,0),
                SIMD4<Float>( 0, 0,1,0),
                SIMD4<Float>( 0, 0,0,1)))
            let scale = matrix_float4x4(diagonal:[len,0.15,1,1]) // very thin bone
            let trans = matrix_float4x4(columns: (
                SIMD4<Float>(1,0,0,0),
                SIMD4<Float>(0,1,0,0),
                SIMD4<Float>(0,0,1,0),
                // subtract camera to centre view
                SIMD4<Float>(center.x - cam.x, center.y - cam.y,0,1)))
            var uni = Uniforms(projectionMatrix: proj,
                               modelViewMatrix: trans * rot * scale,
                               color: SIMD4<Float>(1,1,1,1))   // white bones
            enc.setVertexBytes(&uni, length: MemoryLayout<Uniforms>.stride, index: 2)
            enc.setFragmentBytes(&uni, length: MemoryLayout<Uniforms>.stride, index: 2)
            enc.setVertexBuffer(boneVB, offset: 0, index: 0)     // limb quad
            enc.drawPrimitives(type: MTLPrimitiveType.triangleStrip,
                               vertexStart: 0,
                               vertexCount: 4)
        }

        enc.endEncoding()
        cmd.present(drawable)
        cmd.commit()
    }
    
    // MARK: ‑ Logic
    private func updateGame(dt: Float) {
        // Muscle input temporarily disabled

        // Advance the simulation with the current parameters
        skel.step(dt: dt,
                 groundY: groundY,
                 applyFriction: keysHeld.isEmpty,
                 muscleScale: muscleScale,
                 gravityScale: gravityScale,
                 damping: damping)
    }
}
