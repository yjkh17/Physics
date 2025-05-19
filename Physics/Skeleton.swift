//
//  Skeleton.swift
//  Physics
//
//  Single source-of-truth for the physics data-model.
//

import simd

// MARK: - Joint helper type
fileprivate struct Joint {
    let i: Int;  let aIsA: Bool   // endpoint on bone i  (true = pA, false = pB)
    let j: Int;  let bIsA: Bool   // endpoint on bone j
}

// MARK: ‑ Core structs
struct Bone {
    var pA : SIMD2<Float>            // joint A position
    var pB : SIMD2<Float>            // joint B position
    let rest : Float                 // anatomical length
    var prevPA : SIMD2<Float> = .zero
    var prevPB : SIMD2<Float> = .zero
}

struct Muscle {
    // attaches to bone i at u ∈ [0,1] and bone j at v ∈ [0,1]
    let i : Int;  let u : Float
    let j : Int;  let v : Float
    var rest : Float                 // dynamic rest length
    let rest0 : Float                // reference rest length
    let maxF : Float                 // (unused)
}

// MARK: ‑ Skeleton container
final class Skeleton {
    var bones   : [Bone]
    var muscles : [Muscle]
    fileprivate var joints  : [Joint]

    // convenience factory: simple biped starting above the ground
    static func twoLegs() -> Skeleton {
        // ── Key reference points ───────────────────────────────
        let pelvis   = SIMD2<Float>(0, 4.0)        // initial body origin
        let spineLen : Float = 2.0                 // pelvis → chest
        let legSeg   : Float = 2.0                 // thigh / shin
        let armSeg   : Float = 1.4                 // shorter upper / lower arm

        // Helper to seed prev-frame positions
        func makeBone(a: SIMD2<Float>, b: SIMD2<Float>) -> Bone {
            var bone = Bone(pA: a, pB: b, rest: length(b - a))
            bone.prevPA = a
            bone.prevPB = b
            return bone
        }

        // ── Build skeleton ─────────────────────────────────────
        // 1. Spine + neck
        let chest = pelvis + SIMD2<Float>(0, spineLen)
        let spine = makeBone(a: pelvis, b: chest)

        let head  = chest + SIMD2<Float>(0, 1.0)
        let neck  = makeBone(a: chest, b: head)

        // 2. Legs
        let hipOffset : Float = 0.5
        // Pelvis bone – short horizontal bar so the pelvis becomes visible
        let pelvisBone = makeBone(a: pelvis + SIMD2<Float>(-hipOffset, 0),
                                  b: pelvis + SIMD2<Float>( hipOffset, 0))
        let thighL = makeBone(a: pelvis + SIMD2<Float>(-hipOffset, 0),
                              b: pelvis + SIMD2<Float>(-hipOffset, -legSeg))
        let shinL  = makeBone(a: thighL.pB,
                              b: thighL.pB + SIMD2<Float>(0, -legSeg))

        let thighR = makeBone(a: pelvis + SIMD2<Float>( hipOffset, 0),
                              b: pelvis + SIMD2<Float>( hipOffset, -legSeg))
        let shinR  = makeBone(a: thighR.pB,
                              b: thighR.pB + SIMD2<Float>(0, -legSeg))

        // 3. Shoulder girdle + arms
        let shoulderOffset : Float = 1.0

        // clavicles: small horizontal links from chest to shoulder
        let clavicleL = makeBone(a: chest,
                                 b: chest + SIMD2<Float>(-shoulderOffset, 0))
        let clavicleR = makeBone(a: chest,
                                 b: chest + SIMD2<Float>( shoulderOffset, 0))

        // upper / lower arms originate from the outer clavicle tips
        // arms angled 45° downward
        let diag = Float(0.70710678)           // cos(45°) = sin(45°)
        let upperArmLDir = SIMD2<Float>(-armSeg * diag, -armSeg * diag)
        let upperArmRDir = SIMD2<Float>( armSeg * diag, -armSeg * diag)

        let upperArmL = makeBone(a: clavicleL.pB,
                                 b: clavicleL.pB + upperArmLDir)
        let forearmL  = makeBone(a: upperArmL.pB,
                                 b: upperArmL.pB + upperArmLDir * 0.8)

        let upperArmR = makeBone(a: clavicleR.pB,
                                 b: clavicleR.pB + upperArmRDir)
        let forearmR  = makeBone(a: upperArmR.pB,
                                 b: upperArmR.pB + upperArmRDir * 0.8)

        // Final bone order (indices referenced below)
        // 0 thighL 1 shinL 2 thighR 3 shinR 4 spine 5 neck
        // 6 clavicleL 7 clavicleR 8 upperArmL 9 forearmL 10 upperArmR 11 forearmR 12 pelvis
        let bones : [Bone] = [
            thighL, shinL,
            thighR, shinR,
            spine,  neck,
            clavicleL, clavicleR,
            upperArmL, forearmL,
            upperArmR, forearmR,
            pelvisBone                          // new visible pelvis bar
        ]

        // muscles  (quad / ham legs, flex / ext arms)
        func quad(f: Int, t: Int) -> Muscle {
            Muscle(i: f, u: 0.3,
                   j: t, v: 0.7,
                   rest: 1.5, rest0: 1.5, maxF: 30)
        }
        func ham (f: Int, t: Int) -> Muscle {
            Muscle(i: f, u: 0.7,
                   j: t, v: 0.3,
                   rest: 1.5, rest0: 1.5, maxF: 30)
        }
        func flex(b: Int) -> Muscle {   // biceps‑like
            Muscle(i: b, u: 0.3, j: b, v: 0.7,
                   rest: 1.0, rest0: 1.0, maxF: 20)
        }
        func ext(b: Int) -> Muscle {    // triceps‑like
            Muscle(i: b, u: 0.7, j: b, v: 0.3,
                   rest: 1.0, rest0: 1.0, maxF: 20)
        }

        let muscles : [Muscle] = [
            quad(f:0, t:1), ham(f:0, t:1),        // left leg
            quad(f:2, t:3), ham(f:2, t:3),        // right leg
            flex(b:8), ext(b:8),                  // left arm
            flex(b:10), ext(b:10)                 // right arm
        ]

        // each tuple: (boneIdx, usesA‑end?, boneIdx, usesA‑end?)
        // ── Inter‑bone joints ─────────────────────────────────────────────
        let joints: [Joint] = [
            // --- lower‑limb articulations
            Joint(i: 0, aIsA: false, j: 1, bIsA:  true),  // left knee
            Joint(i: 2, aIsA: false, j: 3, bIsA:  true),  // right knee

            // --- spine / head
            Joint(i: 4, aIsA: false, j: 5, bIsA:  true),  // neck base

            // --- trunk ↔ clavicles
            Joint(i: 4, aIsA: false, j: 6, bIsA:  true),  // chest‑to‑clavL root
            Joint(i: 4, aIsA: false, j: 7, bIsA:  true),  // chest‑to‑clavR root

            // --- clavicle ↔ upper‑arm articulations (shoulders)
            Joint(i: 6, aIsA: false, j: 8, bIsA:  true),  // left shoulder
            Joint(i: 7, aIsA: false, j:10, bIsA:  true),  // right shoulder

            // --- upper‑limb articulations
            Joint(i: 8, aIsA: false, j: 9, bIsA:  true),  // left elbow
            Joint(i:10, aIsA: false, j:11, bIsA:  true),  // right elbow

            // --- tie all pelvis roots together so the skeleton is a single connected body
            Joint(i: 0, aIsA:  true, j: 2, bIsA:  true),  // left‑hip root ↔ right‑hip root
            Joint(i: 0, aIsA:  true, j: 4, bIsA:  true),  // left‑hip root ↔ spine root
            Joint(i: 2, aIsA:  true, j: 4, bIsA:  true),  // right‑hip root ↔ spine root

            // --- pelvis bar welded to both hip roots ---
            Joint(i: 12, aIsA:  true, j: 0,  bIsA:  true),  // pelvis left → thighL root
            Joint(i: 12, aIsA: false, j: 2,  bIsA:  true),  // pelvis right → thighR root
        ]

        return Skeleton(bones: bones, muscles: muscles, joints: joints)
    }

    fileprivate init(bones: [Bone], muscles: [Muscle], joints: [Joint]) {
        self.bones   = bones
        self.muscles = muscles
        self.joints  = joints
    }
}

// MARK: ‑ Dynamics
extension Skeleton {

    func applyUserInput(contractQuad : Bool,
                        contractHam  : Bool,
                        contractQuadR: Bool,
                        contractHamR : Bool,
                        dt: Float) {
        let rate: Float = 0.4 * dt
        func adjust(_ index: Int, shorten: Bool) {
            // keep rest length within ±20 % of anatomical value
            let newLen = muscles[index].rest + (shorten ? -rate : rate)
            let lo = 0.8 * muscles[index].rest0
            let hi = 1.2 * muscles[index].rest0
            muscles[index].rest = min(max(newLen, lo), hi)
        }
        adjust(0, shorten: contractQuad)
        adjust(1, shorten: contractHam)
        adjust(2, shorten: contractQuadR)
        adjust(3, shorten: contractHamR)
    }

    func step(dt: Float,
              groundY: Float,
              applyFriction: Bool,
              muscleScale: Float = 0.5,
              gravityScale: Float = 1.0,
              damping: Float = 0.98) {

        // Skeleton now fully dynamic – pelvis no longer anchored
        let anchoredRoots: Set<Int> = []

        // ── Verlet prediction ──────────────────────────────────
        // gravity (simpler form avoids operator-overload ambiguity)
        let gVec = SIMD2<Float>(0, -9.8 * gravityScale * dt * dt)
        // -------- Safety guard -------------------------------------------------
        // Keep every joint inside a finite “sandbox” so the math can never blow up
        // (large values were triggering numeric overflows → abort()).
        let posLimit: Float = 15        // keep every joint safely within view
        guard gVec.x.isFinite && gVec.y.isFinite else { return }

        for i in bones.indices {
            var b = bones[i]
            let vA0 = (b.pA - b.prevPA) * damping
            let vB0 = (b.pB - b.prevPB) * damping
            // clamp velocity magnitudes (≤ 25 m/s) to prevent numeric blow‑ups
            let maxVel: Float = 25 * dt          // distance allowed this step
            var vA = vA0, vB = vB0               // make mutable
            let lenA = length(vA)
            if lenA > maxVel { vA *= maxVel / lenA }
            let lenB = length(vB)
            if lenB > maxVel { vB *= maxVel / lenB }
            // NaN/Inf check for velocities
            if !vA.x.isFinite || !vA.y.isFinite || !vB.x.isFinite || !vB.y.isFinite {
                continue
            }
            b.prevPA = b.pA
            b.prevPB = b.pB
            // Verlet prediction + gravity
            b.pA += vA + gVec
            b.pB += vB + gVec

            // -- keep bone length rigid right after prediction --
            //   (anchored roots stay fixed, only the distal joint can move)
            let curLen = length(b.pB - b.pA)
            if curLen != 0 {
                let n = (b.pB - b.pA) / curLen
                if anchoredRoots.contains(i) {
                    // would fix the root joint if any bone were anchored
                    b.pB = b.pA + n * b.rest
                } else {
                    // adjust both ends around their midpoint to restore rest length
                    let centre = 0.5 * (b.pA + b.pB)
                    let half   = n * (b.rest * 0.5)
                    b.pA = centre - half
                    b.pB = centre + half
                }
            }

            // Clamp positions to the safe range to avoid runaway values
            b.pA.x = min(max(b.pA.x, -posLimit),  posLimit)
            b.pA.y = min(max(b.pA.y, -posLimit),  posLimit)
            b.pB.x = min(max(b.pB.x, -posLimit),  posLimit)
            b.pB.y = min(max(b.pB.y, -posLimit),  posLimit)
            bones[i] = b
        }

        // pelvis no longer anchored

        // ── Constraint solver ─────────────────────────────────
        // With no fixed anchor points the whole body is free to fall
        for _ in 0..<15 {     // more iterations → better stability

            // bone length constraints
            for i in bones.indices {
                var b = bones[i]
                let d   = b.pB - b.pA
                let len = length(d)
                if len == 0 { continue }
                let n   = d / len
                let err = len - b.rest

                if anchoredRoots.contains(i) {
                    // move only the distal end when a root is anchored
                    b.pB += n * (-err)
                } else {
                    // Distribute correction equally when both ends are free
                    b.pA += n * (-0.5 * err)
                    b.pB += n * ( 0.5 * err)
                }
                bones[i] = b
            }

            // joint position constraints – keep shared endpoints coincident
            for jnt in joints {
                var bi = bones[jnt.i]
                var bj = bones[jnt.j]
                let pa = jnt.aIsA ? bi.pA : bi.pB
                let pb = jnt.bIsA ? bj.pA : bj.pB
                var centre = 0.5 * (pa + pb)

                // If either endpoint is anchored, lock the centre to that anchor
                if anchoredRoots.contains(jnt.i) && jnt.aIsA ||
                   anchoredRoots.contains(jnt.j) && jnt.bIsA {
                    centre = anchoredRoots.contains(jnt.i) && jnt.aIsA ? pa : pb
                }

                let deltaA = centre - pa
                let deltaB = centre - pb
                if !deltaA.x.isFinite || !deltaA.y.isFinite ||
                   !deltaB.x.isFinite || !deltaB.y.isFinite { continue }

                if !(anchoredRoots.contains(jnt.i) && jnt.aIsA) {
                    if jnt.aIsA { bi.pA += deltaA } else { bi.pB += deltaA }
                }
                if !(anchoredRoots.contains(jnt.j) && jnt.bIsA) {
                    if jnt.bIsA { bj.pA += deltaB } else { bj.pB += deltaB }
                }
                bones[jnt.i] = bi
                bones[jnt.j] = bj
            }



            // muscle constraints
            for m in muscles {
                var bi = bones[m.i]
                var bj = bones[m.j]

                let pi = bi.pA + (bi.pB - bi.pA) * m.u
                let pj = bj.pA + (bj.pB - bj.pA) * m.v
                var delta = pj - pi
                let d = length(delta)
                if !d.isFinite { continue }
                if d == 0 { continue }
                delta /= d
                let err = d - m.rest
                // --- clamp one‑step correction to avoid runaway expansion ---
                var corr = delta * (-err) * muscleScale
                let maxCorr : Float = 0.3          // metres per solver pass (tighter)
                let corrLen = length(corr)
                if corrLen > maxCorr {
                    corr *= maxCorr / corrLen      // scale back softly
                }

                // Apply correction to bone i
                if anchoredRoots.contains(m.i) {
                    // Only the distal end may move on an anchored bone
                    bi.pB += corr * m.u
                } else {
                    bi.pA += corr * (1 - m.u) * 0.5
                    bi.pB += corr * m.u       * 0.5
                }

                // Apply correction to bone j
                if anchoredRoots.contains(m.j) {
                    bj.pB -= corr * m.v
                } else {
                    bj.pA -= corr * (1 - m.v) * 0.5
                    bj.pB -= corr * m.v       * 0.5
                }

                bones[m.i] = bi
                bones[m.j] = bj
            }



            // ── ground constraints  ───────────────
            // keep both feet (shin endpoints) above the ground plane
            let footIndices: [Int] = [1, 3]   // shinL, shinR
            for fi in footIndices {
                var foot = bones[fi]
                // constrain the distal end (pB) only – this is the “foot”
                foot.pB.y = max(foot.pB.y, groundY)
                bones[fi] = foot
            }
        }

        // ── Final pass: strictly enforce fixed bone lengths ────────────────
        for i in bones.indices {
            var b = bones[i]
            let d   = b.pB - b.pA
            let len = length(d)
            if len == 0 { continue }
            let n = d / len          // unit direction

            if anchoredRoots.contains(i) {
                // keep the root joint fixed – move only the distal end
                b.pB = b.pA + n * b.rest
            } else {
                // adjust both ends around their midpoint to preserve rest length
                let centre = 0.5 * (b.pA + b.pB)
                let half   = n * (b.rest * 0.5)
                b.pA = centre - half
                b.pB = centre + half
            }
            bones[i] = b
        }

        // ── Optional ground friction ──────────────────────────
        if applyFriction {
            let footIndices: [Int] = [1, 3]
            for fi in footIndices {
                var foot = bones[fi]
                let vx = (foot.pB.x - foot.prevPB.x) / dt
                if abs(vx) < 0.05 {
                    foot.pB.x = foot.prevPB.x     // lock when velocity ~ zero
                }
                bones[fi] = foot
            }
        }
    }
}
