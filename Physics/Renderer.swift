//
//  Renderer.swift
//  Physics – minimal 2-D playground
//

import MetalKit
import simd

// MARK: ‑ Shared types
private struct SimpleVertex {
    var position : SIMD3<Float>
    var texcoord : SIMD2<Float>
}

private struct Uniforms {
    var projectionMatrix : matrix_float4x4
    var modelViewMatrix  : matrix_float4x4
}

// MARK: ‑ Renderer
final class Renderer: NSObject, MTKViewDelegate {

    // ── Metal objects ──────────────────────────────────────────────
    private let device       : MTLDevice
    private let queue        : MTLCommandQueue
    private let pipeline     : MTLRenderPipelineState

    // Buffers
    private let playerVB     : MTLBuffer
    private let groundVB     : MTLBuffer

    // Textures (flat colours)
    private let whiteTex     : MTLTexture
    private let yellowTex    : MTLTexture

    // ── Input / physics state ─────────────────────────────────────
    var   keysHeld           = Set<UInt16>()          // updated by view-controller
    private var lastTime : CFTimeInterval = 0

    private let groundY   : Float = -8.9         // top edge of the ground quad near bottom of view.
    private let playerHalfHeight : Float = 0.5  // half of the 1‑unit player height.
    private var playerPos = SIMD2<Float>(0, -8.9 + 0.5)
    private var playerVel = SIMD2<Float>(0, 0)

    private let moveSpeed : Float = 4          // m·s⁻¹
    private let jumpImpulse: Float = 4.5
    private let gravity   : Float = -9.8

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
            // texcoord ─ float2 @ offset 12, buffer 0
            vd.attributes[1].format      = .float2
            vd.attributes[1].offset      = 12
            vd.attributes[1].bufferIndex = 0
            // single interleaved layout
            vd.layouts[0].stride         = MemoryLayout<SimpleVertex>.stride   // 20 bytes
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
                .init(position:[-hw,-hh,0], texcoord:[0,1]),
                .init(position:[ hw,-hh,0], texcoord:[1,1]),
                .init(position:[-hw, hh,0], texcoord:[0,0]),
                .init(position:[ hw, hh,0], texcoord:[1,0])
            ]
        }

        // Player (0.5×1.0 units)
        let pVerts  = makeQuad(width: 0.5, height: 1.0)
        playerVB    = device.makeBuffer(bytes: pVerts,
                                        length: MemoryLayout<SimpleVertex>.stride*4)!

        // Ground (span ±10, thickness 0.2)
        let gVerts  = makeQuad(width: 20, height: 0.2)
        groundVB    = device.makeBuffer(bytes: gVerts,
                                        length: MemoryLayout<SimpleVertex>.stride*4)!

        // Flat-colour textures
        whiteTex  = Renderer.makeSolidTexture(device: device, rgba: 0xFFFFFFFF)
        yellowTex = Renderer.makeSolidTexture(device: device, rgba: 0xFFFF00FF)

        super.init()
    }

    // MARK: ‑ MTKViewDelegate
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }

    func draw(in view: MTKView) {
        // ‑- timing
        let now = CACurrentMediaTime()
        let dt  = lastTime == 0 ? 1/60.0 : now - lastTime
        lastTime = now

        updateGame(dt: Float(dt))

        guard
            let pass = view.currentRenderPassDescriptor,
            let cmd  = queue.makeCommandBuffer(),
            let enc  = cmd.makeRenderCommandEncoder(descriptor: pass),
            let drawable = view.currentDrawable
        else { return }

        enc.setRenderPipelineState(pipeline)

        // helper: produces orthographic projection (already constant)
        let projScale : Float = 0.1
        let proj = matrix_float4x4(diagonal: [projScale, projScale, 1, 1])

        // ── draw ground ─────────────────────────────────────────
        // translate ground quad so its centre sits at groundY - halfThickness (‑0.1)
        let groundCentreY: Float = groundY - 0.1                  // thickness = 0.2
        let gMV = matrix_float4x4(columns: (
            SIMD4<Float>(1,0,0,0),
            SIMD4<Float>(0,1,0,0),
            SIMD4<Float>(0,0,1,0),
            SIMD4<Float>(0, groundCentreY, 0, 1)
        ))
        var gUni = Uniforms(projectionMatrix: proj,
                            modelViewMatrix: gMV)
        enc.setVertexBytes(&gUni,
                           length: MemoryLayout<Uniforms>.stride,
                           index: 2)
        enc.setVertexBuffer(groundVB, offset: 0, index: 0)
        enc.setFragmentTexture(yellowTex, index: 0)
        enc.drawPrimitives(type: MTLPrimitiveType.triangleStrip,
                           vertexStart: 0,
                           vertexCount: 4)

        // ── draw player ────────────────────────────────────────
        let pMV = matrix_float4x4(columns: (
            SIMD4<Float>(1,0,0,0),
            SIMD4<Float>(0,1,0,0),
            SIMD4<Float>(0,0,1,0),
            SIMD4<Float>(playerPos.x, playerPos.y, 0, 1)
        ))
        var pUni = Uniforms(projectionMatrix: proj, modelViewMatrix: pMV)
        enc.setVertexBytes(&pUni,
                           length: MemoryLayout<Uniforms>.stride,
                           index: 2)
        enc.setVertexBuffer(playerVB, offset: 0, index: 0)
        enc.setFragmentTexture(whiteTex, index: 0)
        enc.drawPrimitives(type: MTLPrimitiveType.triangleStrip,
                           vertexStart: 0,
                           vertexCount: 4)

        enc.endEncoding()
        cmd.present(drawable)
        cmd.commit()
    }

    // MARK: ‑ Logic
    private func updateGame(dt: Float) {
        // input
        var dx: Float = 0
        if keysHeld.contains(0) { dx -= moveSpeed }   // ‘A’
        if keysHeld.contains(2) { dx += moveSpeed }   // ‘D’
        playerVel.x = dx

        if keysHeld.contains(49) && playerPos.y - playerHalfHeight <= groundY + 0.0001 {
            playerVel.y = jumpImpulse
        }

        // physics
        playerVel.y += gravity * dt
        playerPos   += playerVel * dt

        if playerPos.y - playerHalfHeight < groundY {
            playerPos.y  = groundY + playerHalfHeight
            playerVel.y  = 0
        }
    }
}

extension Renderer {
    static func makeSolidTexture(device: MTLDevice, rgba: UInt32) -> MTLTexture {
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                                                            width: 1, height: 1,
                                                            mipmapped: false)
        desc.usage = .shaderRead
        let tex = device.makeTexture(descriptor: desc)!
        var px = rgba
        tex.replace(region: MTLRegionMake2D(0, 0, 1, 1),
                    mipmapLevel: 0,
                    withBytes: &px,
                    bytesPerRow: 4)
        return tex
    }
}
