// Mesh.swift — procedural geometry for placeholder rendering.
// WorldVertex layout MUST match the MTLVertexDescriptor in GameViewController:
//   attribute(0) float3 pos    offset  0  bufferIndex 2
//   attribute(1) float3 normal offset 12  bufferIndex 2
//   attribute(2) float2 uv    offset 24  bufferIndex 2
//   stride 32 bytes

import Metal

struct WorldVertex {
    var px, py, pz: Float  // position  (offset  0, 12 bytes)
    var nx, ny, nz: Float  // normal    (offset 12, 12 bytes)
    var u,  v:      Float  // texcoord  (offset 24,  8 bytes)
}  // total 32 bytes

// ── Shared mesh-building helpers used by the new asset meshes (mesh_id ≥ 15).
//    Existing meshes (capsule, tree, gargoyle, hero, …) keep their inline
//    helpers for stability — these are only for the new functions.
private func mbCylinder(_ verts: inout [WorldVertex], _ idxs: inout [UInt16],
                        _ p0x: Float, _ p0y: Float, _ p0z: Float,
                        _ p1x: Float, _ p1y: Float, _ p1z: Float,
                        r0: Float, r1: Float, sides: Int, uBase: Float) {
    let dx = p1x-p0x, dy = p1y-p0y, dz = p1z-p0z
    let len = (dx*dx + dy*dy + dz*dz).squareRoot() + 1e-6
    let ax = dx/len, ay = dy/len, az = dz/len
    var rx: Float, ry: Float, rz: Float
    if abs(ay) < 0.9 {
        let cl = (az*az + ax*ax).squareRoot() + 1e-6
        rx = az/cl; ry = 0; rz = -ax/cl
    } else {
        let cl = (az*az + ay*ay).squareRoot() + 1e-6
        rx = 0; ry = -az/cl; rz = ay/cl
    }
    let ux = ay*rz - az*ry, uy = az*rx - ax*rz, uz = ax*ry - ay*rx
    let base = UInt16(verts.count)
    for i in 0...sides {
        let t = 2.0 * Float.pi * Float(i) / Float(sides)
        let c = cos(t), s = sin(t)
        let nx = c*rx + s*ux, ny = c*ry + s*uy, nz = c*rz + s*uz
        let nl = (nx*nx + ny*ny + nz*nz).squareRoot() + 1e-6
        verts.append(WorldVertex(px: p0x+c*rx*r0+s*ux*r0, py: p0y+c*ry*r0+s*uy*r0, pz: p0z+c*rz*r0+s*uz*r0,
                                 nx: nx/nl, ny: ny/nl, nz: nz/nl, u: uBase, v: 1))
        verts.append(WorldVertex(px: p1x+c*rx*r1+s*ux*r1, py: p1y+c*ry*r1+s*uy*r1, pz: p1z+c*rz*r1+s*uz*r1,
                                 nx: nx/nl, ny: ny/nl, nz: nz/nl, u: uBase, v: 0))
    }
    for i in 0..<UInt16(sides) {
        let a = base + i*2
        idxs.append(contentsOf: [a, a+2, a+1,  a+1, a+2, a+3])
    }
}

private func mbSphere(_ verts: inout [WorldVertex], _ idxs: inout [UInt16],
                      _ cx: Float, _ cy: Float, _ cz: Float, _ r: Float,
                      slices: Int, rings: Int, uBase: Float) {
    let base = UInt16(verts.count)
    for ring in 0...rings {
        let phi = Float.pi * Float(ring) / Float(rings)
        let sinP = sin(phi), cosP = cos(phi)
        for sl in 0...slices {
            let theta = 2.0 * Float.pi * Float(sl) / Float(slices)
            let c = cos(theta), s = sin(theta)
            verts.append(WorldVertex(px: c*sinP*r+cx, py: -cosP*r+cy, pz: s*sinP*r+cz,
                                     nx: c*sinP, ny: -cosP, nz: s*sinP,
                                     u: uBase, v: Float(ring)/Float(rings)))
        }
    }
    for ring in 0..<rings { for sl in 0..<slices {
        let a = base + UInt16(ring*(slices+1)+sl)
        let b = a+1; let c2 = base + UInt16((ring+1)*(slices+1)+sl); let d = c2+1
        idxs.append(contentsOf: [a, c2, b,  b, c2, d])
    }}
}

private func mbBuffers(_ verts: [WorldVertex], _ idxs: [UInt16], _ device: MTLDevice)
    -> (vtx: MTLBuffer, idx: MTLBuffer, count: Int) {
    let vBuf = device.makeBuffer(bytes: verts, length: verts.count * MemoryLayout<WorldVertex>.size, options: .storageModeShared)!
    let iBuf = device.makeBuffer(bytes: idxs,  length: idxs.count  * MemoryLayout<UInt16>.size,      options: .storageModeShared)!
    return (vBuf, iBuf, idxs.count)
}

/// Flat ground quad, ±halfSize in XZ at y = 0.
func makeGround(device: MTLDevice, halfSize: Float = 380) -> (vtx: MTLBuffer, idx: MTLBuffer, count: Int) {
    let s = halfSize
    let verts: [WorldVertex] = [
        WorldVertex(px:-s, py:0, pz:-s, nx:0, ny:1, nz:0, u:0, v:0),
        WorldVertex(px: s, py:0, pz:-s, nx:0, ny:1, nz:0, u:4, v:0),
        WorldVertex(px:-s, py:0, pz: s, nx:0, ny:1, nz:0, u:0, v:4),
        WorldVertex(px: s, py:0, pz: s, nx:0, ny:1, nz:0, u:4, v:4),
    ]
    // CCW winding, normal = +Y (toward camera)
    let idxs: [UInt16] = [0, 2, 1,  1, 2, 3]

    let vBuf = device.makeBuffer(bytes: verts,
                                 length: verts.count * MemoryLayout<WorldVertex>.size,
                                 options: .storageModeShared)!
    let iBuf = device.makeBuffer(bytes: idxs,
                                 length: idxs.count * MemoryLayout<UInt16>.size,
                                 options: .storageModeShared)!
    return (vBuf, iBuf, idxs.count)
}

/// Capsule standing upright with its base at y = 0.
/// radius = 0.40, cylinder half-height = 0.40, total height ≈ 1.60.
/// 12 longitude slices × 8 latitude rings = 104 vertices, 504 indices.
func makeCapsule(device: MTLDevice) -> (vtx: MTLBuffer, idx: MTLBuffer, count: Int) {
    let radius: Float = 0.40
    let halfH:  Float = 0.40   // half the cylinder height
    let slices  = 12

    // 8 rings of latitude: 4 for bottom hemisphere + 4 for top hemisphere.
    // Rings 3 and 4 share phi=0 but differ in y-offset — this creates the cylinder walls.
    let phis:  [Float] = [-.pi/2, -.pi/3, -.pi/6, 0,   0, .pi/6, .pi/3, .pi/2]
    let yOffs: [Float] = [-halfH, -halfH, -halfH, -halfH, halfH, halfH, halfH, halfH]
    let numRows = phis.count   // 8

    var verts: [WorldVertex] = []
    var idxs:  [UInt16]      = []

    for row in 0 ..< numRows {
        let phi  = phis[row]
        let sinP = sin(phi)
        let cosP = cos(phi)
        let y    = sinP * radius + yOffs[row]
        for col in 0 ... slices {
            let theta = 2.0 * Float.pi * Float(col) / Float(slices)
            let cosT  = cos(theta)
            let sinT  = sin(theta)
            verts.append(WorldVertex(
                px: cosP * cosT * radius,
                py: y,
                pz: cosP * sinT * radius,
                nx: cosP * cosT,
                ny: sinP,
                nz: cosP * sinT,
                u:  Float(col) / Float(slices),
                v:  Float(row) / Float(numRows - 1)
            ))
        }
    }

    // Shift upward so the bottom of the capsule sits at y = 0
    let minY = -radius - halfH
    for i in 0 ..< verts.count { verts[i].py -= minY }

    // Emit two CCW triangles per quad (a, c, b) + (b, c, d)
    for row in 0 ..< (numRows - 1) {
        for col in 0 ..< slices {
            let a = UInt16(row       * (slices + 1) + col)
            let b = UInt16(row       * (slices + 1) + col + 1)
            let c = UInt16((row + 1) * (slices + 1) + col)
            let d = UInt16((row + 1) * (slices + 1) + col + 1)
            idxs.append(contentsOf: [a, c, b,  b, c, d])
        }
    }

    let vBuf = device.makeBuffer(bytes: verts,
                                 length: verts.count * MemoryLayout<WorldVertex>.size,
                                 options: .storageModeShared)!
    let iBuf = device.makeBuffer(bytes: idxs,
                                 length: idxs.count * MemoryLayout<UInt16>.size,
                                 options: .storageModeShared)!
    return (vBuf, iBuf, idxs.count)
}

/// Small flat rock: oblate spheroid sitting on the ground, wider than tall.
func makeRock(device: MTLDevice) -> (vtx: MTLBuffer, idx: MTLBuffer, count: Int) {
    var verts: [WorldVertex] = []
    var idxs:  [UInt16]     = []

    let slices = 8; let rings = 6
    let rx: Float = 0.42   // wide
    let ry: Float = 0.22   // flat

    for ring in 0 ... rings {
        let phi = Float.pi * Float(ring) / Float(rings)  // 0 (top) → π (bottom)
        let sinP = sin(phi), cosP = cos(phi)
        let y    = -cosP * ry + ry   // shift so bottom sits at y=0
        let hr   = sinP * rx
        for sl in 0 ... slices {
            let theta = 2.0 * Float.pi * Float(sl) / Float(slices)
            let c = cos(theta), s = sin(theta)
            let nx = c * sinP / rx, ny = cosP / ry, nz = s * sinP / rx
            let nlen = sqrt(nx*nx + ny*ny + nz*nz) + 1e-6
            verts.append(WorldVertex(px: c * hr, py: y, pz: s * hr,
                                     nx: nx/nlen, ny: ny/nlen, nz: nz/nlen,
                                     u: Float(sl)/Float(slices),
                                     v: Float(ring)/Float(rings)))
        }
    }
    for ring in 0 ..< rings {
        for sl in 0 ..< slices {
            let a = UInt16(ring       * (slices + 1) + sl)
            let b = UInt16(ring       * (slices + 1) + sl + 1)
            let c = UInt16((ring + 1) * (slices + 1) + sl)
            let d = UInt16((ring + 1) * (slices + 1) + sl + 1)
            idxs.append(contentsOf: [a, c, b,  b, c, d])
        }
    }

    let vBuf = device.makeBuffer(bytes: verts, length: verts.count * MemoryLayout<WorldVertex>.size, options: .storageModeShared)!
    let iBuf = device.makeBuffer(bytes: idxs,  length: idxs.count  * MemoryLayout<UInt16>.size,      options: .storageModeShared)!
    return (vBuf, iBuf, idxs.count)
}

/// Small flower: 6 flat upward-facing petals + thin stem. Visible from top-down camera.
func makeFlower(device: MTLDevice) -> (vtx: MTLBuffer, idx: MTLBuffer, count: Int) {
    var verts: [WorldVertex] = []
    var idxs:  [UInt16]     = []

    // Petals — flat star facing up at y=0.06
    let petalCount = 6
    let innerR: Float = 0.07   // petal base width
    let outerR: Float = 0.20   // petal tip reach
    let py: Float = 0.06

    let center = UInt16(verts.count)
    verts.append(WorldVertex(px: 0, py: py, pz: 0, nx: 0, ny: 1, nz: 0, u: 0.5, v: 0.5))

    // Alternating outer (tip) / inner (between petals) rim vertices
    let rimCount = petalCount * 2
    for i in 0 ..< rimCount {
        let angle = Float.pi * Float(i) / Float(petalCount)
        let r: Float = i % 2 == 0 ? outerR : innerR
        let c = cos(angle), s = sin(angle)
        verts.append(WorldVertex(px: c * r, py: py, pz: s * r,
                                 nx: 0, ny: 1, nz: 0,
                                 u: (c * r / outerR) * 0.5 + 0.5,
                                 v: (s * r / outerR) * 0.5 + 0.5))
    }
    for i in 0 ..< UInt16(rimCount) {
        let next = (i + 1) % UInt16(rimCount)
        idxs.append(contentsOf: [center, center + 1 + i, center + 1 + next])
    }

    // Thin stem
    let stemSides = 4;  let stemR: Float = 0.03;  let stemH: Float = 0.22
    let ts = UInt16(verts.count)
    for i in 0 ... stemSides {
        let theta = 2.0 * Float.pi * Float(i) / Float(stemSides)
        let c = cos(theta), s = sin(theta)
        verts.append(WorldVertex(px: c * stemR, py: 0,      pz: s * stemR, nx: c, ny: 0, nz: s, u: Float(i)/Float(stemSides), v: 1))
        verts.append(WorldVertex(px: c * stemR, py: stemH,  pz: s * stemR, nx: c, ny: 0, nz: s, u: Float(i)/Float(stemSides), v: 0))
    }
    for i in 0 ..< UInt16(stemSides) {
        let a = ts + i * 2
        idxs.append(contentsOf: [a, a + 2, a + 1,  a + 1, a + 2, a + 3])
    }

    let vBuf = device.makeBuffer(bytes: verts, length: verts.count * MemoryLayout<WorldVertex>.size, options: .storageModeShared)!
    let iBuf = device.makeBuffer(bytes: idxs,  length: idxs.count  * MemoryLayout<UInt16>.size,      options: .storageModeShared)!
    return (vBuf, iBuf, idxs.count)
}

/// Bushy deciduous tree: single thick trunk + cluster of 7 overlapping domes for a full canopy.
/// Trunk uses u≥10 bark-color marker (same as makeTree). Base sits at y=0.
func makeForestTree(device: MTLDevice) -> (vtx: MTLBuffer, idx: MTLBuffer, count: Int) {
    var verts: [WorldVertex] = []
    var idxs:  [UInt16]     = []

    // Helper: append a hemisphere dome at (cx,cy,cz) with radius r
    func addDome(_ cx: Float, _ cy: Float, _ cz: Float, _ r: Float) {
        let slices = 10; let rings = 6
        let base = UInt16(verts.count)
        for ring in 0 ... rings {
            let phi = Float.pi / 2.0 * Float(ring) / Float(rings)
            let sinP = sin(phi), cosP = cos(phi)
            let ry = sinP * r + cy
            let hr = cosP * r
            for sl in 0 ... slices {
                let theta = 2.0 * Float.pi * Float(sl) / Float(slices)
                let c = cos(theta), s = sin(theta)
                verts.append(WorldVertex(
                    px: c * hr + cx, py: ry, pz: s * hr + cz,
                    nx: c * cosP,    ny: sinP, nz: s * cosP,
                    u:  Float(sl) / Float(slices),
                    v:  Float(ring) / Float(rings)))
            }
        }
        for ring in 0 ..< rings {
            for sl in 0 ..< slices {
                let a = base + UInt16(ring       * (slices + 1) + sl)
                let b = base + UInt16(ring       * (slices + 1) + sl + 1)
                let c = base + UInt16((ring + 1) * (slices + 1) + sl)
                let d = base + UInt16((ring + 1) * (slices + 1) + sl + 1)
                idxs.append(contentsOf: [a, c, b,  b, c, d])
            }
        }
    }

    // Tapered trunk: wide at base (0.38), narrower at top (0.22) — more natural oak shape
    let trunkSides = 10;  let trunkH: Float = 2.1
    let baseR: Float = 0.38;  let topR: Float = 0.22
    let ts = UInt16(verts.count)
    for i in 0 ... trunkSides {
        let theta = 2.0 * Float.pi * Float(i) / Float(trunkSides)
        let c = cos(theta), s = sin(theta)
        let uEnc = 10.0 + Float(i) / Float(trunkSides) * 0.9
        verts.append(WorldVertex(px: c * baseR, py: 0,       pz: s * baseR, nx: c, ny: 0, nz: s, u: uEnc, v: 1))
        verts.append(WorldVertex(px: c * topR,  py: trunkH,  pz: s * topR,  nx: c, ny: 0, nz: s, u: uEnc, v: 0))
    }
    for i in 0 ..< UInt16(trunkSides) {
        let a = ts + i * 2
        idxs.append(contentsOf: [a, a + 2, a + 1,  a + 1, a + 2, a + 3])
    }

    // Canopy: 1 central + 6 primary + 4 small accent puffs for an irregular, full crown
    addDome(0, 2.3, 0, 1.65)   // central — largest

    // 6 primary domes: varying sizes and heights so crown looks irregular
    let od: Float = 1.12
    let outerSizes:   [Float] = [1.08, 0.92, 1.14, 0.88, 1.05, 0.96]
    let outerHeights: [Float] = [1.85, 2.30, 1.75, 2.20, 2.05, 1.95]
    for i in 0 ..< 6 {
        let a = Float(i) * Float.pi / 3.0
        addDome(cos(a) * od, outerHeights[i], sin(a) * od, outerSizes[i])
    }

    // 4 small accent puffs at irregular positions — break up the dome symmetry
    let accents: [(Float, Float, Float, Float)] = [
        ( 0.55,  3.20,  0.80, 0.58),
        (-0.65,  2.85, -0.45, 0.62),
        ( 0.10,  3.50, -0.65, 0.50),
        (-0.50,  2.60,  0.72, 0.55),
    ]
    for (ax, ay, az, ar) in accents { addDome(ax, ay, az, ar) }

    let vBuf = device.makeBuffer(bytes: verts, length: verts.count * MemoryLayout<WorldVertex>.size, options: .storageModeShared)!
    let iBuf = device.makeBuffer(bytes: idxs,  length: idxs.count  * MemoryLayout<UInt16>.size,      options: .storageModeShared)!
    return (vBuf, iBuf, idxs.count)
}

/// Small flying gargoyle: stone body + head + horns + arms + legs + tail + bat wings.
/// Wings use uBase=30 so the vertex shader can animate them independently.
func makeGargoyle(device: MTLDevice) -> (vtx: MTLBuffer, idx: MTLBuffer, count: Int) {
    var verts: [WorldVertex] = []
    var idxs:  [UInt16]      = []

    func addCylinder(_ p0x: Float, _ p0y: Float, _ p0z: Float,
                     _ p1x: Float, _ p1y: Float, _ p1z: Float,
                     r0: Float, r1: Float, sides: Int, uBase: Float) {
        let dx = p1x-p0x, dy = p1y-p0y, dz = p1z-p0z
        let len = (dx*dx + dy*dy + dz*dz).squareRoot() + 1e-6
        let ax = dx/len, ay = dy/len, az = dz/len
        var rx: Float, ry: Float, rz: Float
        if abs(ay) < 0.9 {
            let cl = (az*az + ax*ax).squareRoot() + 1e-6
            rx = az/cl; ry = 0; rz = -ax/cl
        } else {
            let cl = (az*az + ay*ay).squareRoot() + 1e-6
            rx = 0; ry = -az/cl; rz = ay/cl
        }
        let ux = ay*rz - az*ry, uy = az*rx - ax*rz, uz = ax*ry - ay*rx
        let base = UInt16(verts.count)
        for i in 0...sides {
            let t = 2.0 * Float.pi * Float(i) / Float(sides)
            let c = cos(t), s = sin(t)
            let nx = c*rx + s*ux, ny = c*ry + s*uy, nz = c*rz + s*uz
            let nl = (nx*nx + ny*ny + nz*nz).squareRoot() + 1e-6
            let uEnc = uBase + Float(i)/Float(sides) * 0.9
            verts.append(WorldVertex(px: p0x+c*rx*r0+s*ux*r0, py: p0y+c*ry*r0+s*uy*r0, pz: p0z+c*rz*r0+s*uz*r0, nx: nx/nl, ny: ny/nl, nz: nz/nl, u: uEnc, v: 1))
            verts.append(WorldVertex(px: p1x+c*rx*r1+s*ux*r1, py: p1y+c*ry*r1+s*uy*r1, pz: p1z+c*rz*r1+s*uz*r1, nx: nx/nl, ny: ny/nl, nz: nz/nl, u: uEnc, v: 0))
        }
        for i in 0..<UInt16(sides) {
            let a = base + i*2; idxs.append(contentsOf: [a, a+2, a+1,  a+1, a+2, a+3])
        }
    }

    func addSphere(_ cx: Float, _ cy: Float, _ cz: Float, _ r: Float,
                   slices: Int, rings: Int, uBase: Float) {
        let base = UInt16(verts.count)
        for ring in 0...rings {
            let phi = Float.pi * Float(ring) / Float(rings)
            let sinP = sin(phi), cosP = cos(phi)
            for sl in 0...slices {
                let theta = 2.0 * Float.pi * Float(sl) / Float(slices)
                let c = cos(theta), s = sin(theta)
                verts.append(WorldVertex(px: c*sinP*r+cx, py: -cosP*r+cy, pz: s*sinP*r+cz,
                                         nx: c*sinP, ny: -cosP, nz: s*sinP,
                                         u: uBase, v: Float(ring)/Float(rings)))
            }
        }
        for ring in 0..<rings { for sl in 0..<slices {
            let a = base + UInt16(ring*(slices+1)+sl)
            let b = a+1; let c2 = base + UInt16((ring+1)*(slices+1)+sl); let d = c2+1
            idxs.append(contentsOf: [a, c2, b,  b, c2, d])
        }}
    }

    // ── Stone body (uBase=0) ──────────────────────────────────────────────────
    addSphere(0, 0.46, 0, 0.22, slices: 10, rings: 6, uBase: 0)         // torso
    addCylinder(0, 0.63, -0.02,  0, 0.71, -0.04,  r0: 0.095, r1: 0.085, sides: 6, uBase: 0) // neck
    addSphere(0, 0.78, -0.04, 0.16, slices: 10, rings: 6, uBase: 0)     // head

    // Massive demon horns — three-segment, arcing back then forward like ram horns
    addCylinder(-0.10, 0.90, -0.03,  -0.18, 1.10, -0.14,  r0: 0.055, r1: 0.034, sides: 6, uBase: 0)
    addCylinder(-0.18, 1.10, -0.14,  -0.24, 1.32, -0.08,  r0: 0.034, r1: 0.020, sides: 5, uBase: 0)
    addCylinder(-0.24, 1.32, -0.08,  -0.20, 1.46,  0.06,  r0: 0.020, r1: 0.000, sides: 4, uBase: 0)
    addCylinder( 0.10, 0.90, -0.03,   0.18, 1.10, -0.14,  r0: 0.055, r1: 0.034, sides: 6, uBase: 0)
    addCylinder( 0.18, 1.10, -0.14,   0.24, 1.32, -0.08,  r0: 0.034, r1: 0.020, sides: 5, uBase: 0)
    addCylinder( 0.24, 1.32, -0.08,   0.20, 1.46,  0.06,  r0: 0.020, r1: 0.000, sides: 4, uBase: 0)

    // Tall pointed bat ears
    addCylinder(-0.14, 0.82, -0.05, -0.22, 0.98, -0.07, r0: 0.032, r1: 0.000, sides: 3, uBase: 0)
    addCylinder( 0.14, 0.82, -0.05,  0.22, 0.98, -0.07, r0: 0.032, r1: 0.000, sides: 3, uBase: 0)

    // Heavy brow ridge over the eyes
    addCylinder(-0.13, 0.85, -0.14,  0.13, 0.85, -0.14,  r0: 0.026, r1: 0.026, sides: 4, uBase: 0)

    // Big glowing eye gems (uBase=8 — emissive crimson)
    addSphere(-0.06, 0.81, -0.17, 0.036, slices: 5, rings: 4, uBase: 8)
    addSphere( 0.06, 0.81, -0.17, 0.036, slices: 5, rings: 4, uBase: 8)

    // Lower jaw — short forward-jutting cylinder
    addCylinder(0, 0.71, -0.10,  0, 0.69, -0.21,  r0: 0.085, r1: 0.060, sides: 6, uBase: 0)

    // Upper fangs (longer)
    addCylinder(-0.06, 0.74, -0.18, -0.06, 0.64, -0.18, r0: 0.020, r1: 0.000, sides: 3, uBase: 0)
    addCylinder( 0.06, 0.74, -0.18,  0.06, 0.64, -0.18, r0: 0.020, r1: 0.000, sides: 3, uBase: 0)
    // Lower fangs (point upward from the jutting jaw)
    addCylinder(-0.04, 0.69, -0.21, -0.04, 0.76, -0.21, r0: 0.014, r1: 0.000, sides: 3, uBase: 0)
    addCylinder( 0.04, 0.69, -0.21,  0.04, 0.76, -0.21, r0: 0.014, r1: 0.000, sides: 3, uBase: 0)

    // CHEST CRYSTAL — large emissive heart-gem (uBase=8 = same shader branch as eyes)
    addSphere(0, 0.52, -0.20, 0.062, slices: 8, rings: 6, uBase: 8)

    // Pauldrons — stone shoulder armor
    addSphere(-0.20, 0.62, 0, 0.085, slices: 6, rings: 5, uBase: 0)
    addSphere( 0.20, 0.62, 0, 0.085, slices: 6, rings: 5, uBase: 0)

    // Arms (thicker, hanging forward-down)
    addCylinder(-0.22, 0.55, -0.05,  -0.32, 0.30, 0.08,  r0: 0.078, r1: 0.048, sides: 6, uBase: 0)
    addCylinder( 0.22, 0.55, -0.05,   0.32, 0.30, 0.08,  r0: 0.078, r1: 0.048, sides: 6, uBase: 0)
    // Bigger claw tips — three claws splayed aggressively
    for sx in [Float(-1), Float(1)] {
        let baseX: Float = sx * 0.32, baseY: Float = 0.30, baseZ: Float = 0.08
        for j in 0 ..< 3 {
            let off = Float(j - 1) * 0.028
            addCylinder(baseX + off, baseY, baseZ,
                        baseX + off + sx * 0.07, baseY - 0.12, baseZ + 0.12,
                        r0: 0.020, r1: 0.000, sides: 3, uBase: 0)
        }
    }

    // Legs (thicker)
    addCylinder(-0.10, 0.30, 0,  -0.11, 0.02, 0.08,  r0: 0.075, r1: 0.054, sides: 6, uBase: 0)
    addCylinder( 0.10, 0.30, 0,   0.11, 0.02, 0.08,  r0: 0.075, r1: 0.054, sides: 6, uBase: 0)

    // Tail — three-segment, tapering, longer
    addCylinder(0, 0.40, 0.12,  0, 0.32, 0.28,  r0: 0.055, r1: 0.038, sides: 5, uBase: 0)
    addCylinder(0, 0.32, 0.28,  0, 0.22, 0.42,  r0: 0.038, r1: 0.022, sides: 5, uBase: 0)
    addCylinder(0, 0.22, 0.42,  0, 0.16, 0.54,  r0: 0.022, r1: 0.000, sides: 4, uBase: 0)

    // Spine SPIKES — large cones along the back, neck → tail base
    let spines: [[Float]] = [
        [0,  0.68,  0.06,  0.05,  0.86,  0.06],
        [0,  0.60,  0.13,  0.05,  0.78,  0.13],
        [0,  0.52,  0.18,  0.04,  0.68,  0.18],
        [0,  0.44,  0.22,  0.04,  0.58,  0.22],
        [0,  0.36,  0.25,  0.03,  0.48,  0.25],
    ]
    for s in spines {
        addCylinder(s[0], s[1], s[2], s[3], s[4], s[5], r0: 0.030, r1: 0.000, sides: 4, uBase: 0)
    }

    // ── Bat wings (uBase=30, animated in vert_world) ──────────────────────────
    // Right wing fan: root → 4 tip vertices.  uv.x=30, uv.y encodes wing extension.
    let wingPts: [(Float, Float, Float, Float)] = [  // x, y, z, extension t
        ( 0.22,  0.58,  0.00,  0.0),  // root (shoulder)
        ( 0.68,  0.54, -0.18,  1.0),  // primary forward tip
        ( 0.60,  0.50,  0.04,  1.0),  // mid-outer
        ( 0.46,  0.46,  0.18,  1.0),  // secondary back tip
        ( 0.22,  0.42,  0.22,  0.4),  // lower root attach
    ]
    for mirror in [false, true] {
        let mx: Float = mirror ? -1 : 1
        let wb = UInt16(verts.count)
        for (px, py, pz, t) in wingPts {
            let nx: Float = 0, ny: Float = 1, nz: Float = 0
            verts.append(WorldVertex(px: mx*px, py: py, pz: pz,
                                     nx: mx*nx, ny: ny, nz: nz, u: 30.0, v: t))
        }
        // Fan triangles from root [wb+0], both faces so wing visible from above and below
        let tris: [(UInt16,UInt16,UInt16)] = [(0,1,2),(0,2,3),(0,3,4)]
        for (a,b,c2) in tris {
            if !mirror {
                idxs.append(contentsOf: [wb+a, wb+b, wb+c2,  wb+a, wb+c2, wb+b])
            } else {
                idxs.append(contentsOf: [wb+a, wb+c2, wb+b,  wb+a, wb+b, wb+c2])
            }
        }
    }

    let vBuf = device.makeBuffer(bytes: verts, length: verts.count * MemoryLayout<WorldVertex>.size, options: .storageModeShared)!
    let iBuf = device.makeBuffer(bytes: idxs,  length: idxs.count  * MemoryLayout<UInt16>.size,      options: .storageModeShared)!
    return (vBuf, iBuf, idxs.count)
}

/// Lightning bolt: two perpendicular zigzag planes forming a cross (visible from any angle),
/// plus a flat impact disc at the ground. Colored purely via emissive in the shader.
func makeLightning(device: MTLDevice) -> (vtx: MTLBuffer, idx: MTLBuffer, count: Int) {
    var verts: [WorldVertex] = []
    var idxs:  [UInt16]      = []

    let totalH: Float = 16.0
    let w: Float = 0.04   // half-width — thin crisp bolt

    // Kink heights and lateral offsets — tighter zigzag for a sharper bolt
    let ys: [Float] = [0.0, 1.4, 2.9, 4.6, 6.5, 8.8, 11.4, totalH]
    let ks: [Float] = [0.0, 0.14, -0.11, 0.18, -0.13, 0.10, -0.09, 0.0]
    let n = ys.count - 1

    // Two perpendicular planes: XY (kinks in X) and ZY (kinks in Z)
    for pass in 0..<2 {
        for i in 0..<n {
            let y0 = ys[i], y1 = ys[i+1]
            let k0 = ks[i], k1 = ks[i+1]
            let base = UInt16(verts.count)
            let uv0 = Float(i)   / Float(n)
            let uv1 = Float(i+1) / Float(n)
            if pass == 0 {
                verts.append(WorldVertex(px: k0-w, py: y0, pz: 0,    nx: 0, ny: 0, nz: 1, u: 0, v: uv0))
                verts.append(WorldVertex(px: k0+w, py: y0, pz: 0,    nx: 0, ny: 0, nz: 1, u: 1, v: uv0))
                verts.append(WorldVertex(px: k1-w, py: y1, pz: 0,    nx: 0, ny: 0, nz: 1, u: 0, v: uv1))
                verts.append(WorldVertex(px: k1+w, py: y1, pz: 0,    nx: 0, ny: 0, nz: 1, u: 1, v: uv1))
            } else {
                verts.append(WorldVertex(px: 0,    py: y0, pz: k0-w, nx: 1, ny: 0, nz: 0, u: 0, v: uv0))
                verts.append(WorldVertex(px: 0,    py: y0, pz: k0+w, nx: 1, ny: 0, nz: 0, u: 1, v: uv0))
                verts.append(WorldVertex(px: 0,    py: y1, pz: k1-w, nx: 1, ny: 0, nz: 0, u: 0, v: uv1))
                verts.append(WorldVertex(px: 0,    py: y1, pz: k1+w, nx: 1, ny: 0, nz: 0, u: 1, v: uv1))
            }
            // Front + back faces so bolt is visible from any camera angle
            idxs.append(contentsOf: [base, base+2, base+1,  base+1, base+2, base+3])
            idxs.append(contentsOf: [base, base+1, base+2,  base+1, base+3, base+2])
        }
    }

    // Ground impact disc (flat ring at y=0.05)
    let discR: Float = 0.90;  let discSides = 16
    let center = UInt16(verts.count)
    verts.append(WorldVertex(px: 0, py: 0.05, pz: 0, nx: 0, ny: 1, nz: 0, u: 0.5, v: 0.5))
    for i in 0...discSides {
        let theta = 2.0 * Float.pi * Float(i) / Float(discSides)
        let c = cos(theta), s = sin(theta)
        verts.append(WorldVertex(px: c*discR, py: 0.05, pz: s*discR,
                                 nx: 0, ny: 1, nz: 0, u: c*0.5+0.5, v: s*0.5+0.5))
    }
    for i in 0..<UInt16(discSides) {
        idxs.append(contentsOf: [center, center+1+i, center+2+i])
    }

    let vBuf = device.makeBuffer(bytes: verts, length: verts.count * MemoryLayout<WorldVertex>.size, options: .storageModeShared)!
    let iBuf = device.makeBuffer(bytes: idxs,  length: idxs.count  * MemoryLayout<UInt16>.size,      options: .storageModeShared)!
    return (vBuf, iBuf, idxs.count)
}

/// Mage hero: skin head/neck, wide flared purple robe, tall wizard hat, glowing staff.
/// UV: 0=skin, 1=robe/brim, 3=hat cone, 22=right arm, 23=left arm, 24=staff, 25=orb.
func makeHero(device: MTLDevice) -> (vtx: MTLBuffer, idx: MTLBuffer, count: Int) {
    var verts: [WorldVertex] = []
    var idxs:  [UInt16]      = []

    // addCylinder: oriented frustum from (p0x,p0y,p0z)→(p1x,p1y,p1z)
    // r0 = bottom radius, r1 = top radius.  uBase encodes animation part ID.
    func addCylinder(_ p0x: Float, _ p0y: Float, _ p0z: Float,
                     _ p1x: Float, _ p1y: Float, _ p1z: Float,
                     r0: Float, r1: Float, sides: Int, uBase: Float) {
        let dx = p1x-p0x, dy = p1y-p0y, dz = p1z-p0z
        let len = (dx*dx + dy*dy + dz*dz).squareRoot() + 1e-6
        let ax = dx/len, ay = dy/len, az = dz/len
        // right = normalize(cross(ref, axis));  choose ref to avoid degeneracy
        var rx: Float, ry: Float, rz: Float
        if abs(ay) < 0.9 {
            // cross(Y=(0,1,0), axis) = (az, 0, -ax)
            let cl = (az*az + ax*ax).squareRoot() + 1e-6
            rx = az/cl; ry = 0; rz = -ax/cl
        } else {
            // cross(X=(1,0,0), axis) = (0, -az, ay)
            let cl = (az*az + ay*ay).squareRoot() + 1e-6
            rx = 0; ry = -az/cl; rz = ay/cl
        }
        // up = cross(axis, right)
        let ux = ay*rz - az*ry, uy = az*rx - ax*rz, uz = ax*ry - ay*rx
        let base = UInt16(verts.count)
        for i in 0...sides {
            let t = 2.0 * Float.pi * Float(i) / Float(sides)
            let c = cos(t), s = sin(t)
            let nx = c*rx + s*ux, ny = c*ry + s*uy, nz = c*rz + s*uz
            let nl = (nx*nx + ny*ny + nz*nz).squareRoot() + 1e-6
            let uEnc = uBase + Float(i)/Float(sides) * 0.9
            verts.append(WorldVertex(
                px: p0x+c*rx*r0+s*ux*r0, py: p0y+c*ry*r0+s*uy*r0, pz: p0z+c*rz*r0+s*uz*r0,
                nx: nx/nl, ny: ny/nl, nz: nz/nl, u: uEnc, v: 1))
            verts.append(WorldVertex(
                px: p1x+c*rx*r1+s*ux*r1, py: p1y+c*ry*r1+s*uy*r1, pz: p1z+c*rz*r1+s*uz*r1,
                nx: nx/nl, ny: ny/nl, nz: nz/nl, u: uEnc, v: 0))
        }
        for i in 0..<UInt16(sides) {
            let a = base + i*2
            idxs.append(contentsOf: [a, a+2, a+1,  a+1, a+2, a+3])
        }
    }

    func addSphere(_ cx: Float, _ cy: Float, _ cz: Float, _ r: Float,
                   slices: Int, rings: Int, uBase: Float) {
        let base = UInt16(verts.count)
        for ring in 0...rings {
            let phi = Float.pi * Float(ring) / Float(rings)
            let sinP = sin(phi), cosP = cos(phi)
            let y = -cosP*r + cy
            let hr = sinP*r
            for sl in 0...slices {
                let theta = 2.0 * Float.pi * Float(sl) / Float(slices)
                let c = cos(theta), s = sin(theta)
                verts.append(WorldVertex(
                    px: c*hr+cx, py: y, pz: s*hr+cz,
                    nx: c*sinP, ny: -cosP, nz: s*sinP,
                    u: uBase, v: Float(ring)/Float(rings)))
            }
        }
        for ring in 0..<rings {
            for sl in 0..<slices {
                let a = base + UInt16(ring*(slices+1)+sl)
                let b = base + UInt16(ring*(slices+1)+sl+1)
                let c = base + UInt16((ring+1)*(slices+1)+sl)
                let d = base + UInt16((ring+1)*(slices+1)+sl+1)
                idxs.append(contentsOf: [a, c, b,  b, c, d])
            }
        }
    }

    // ── Head + neck (skin, uBase=0) ───────────────────────────────────────────
    addSphere(0, 1.92, 0, 0.20, slices: 10, rings: 8, uBase: 0)
    addCylinder(0, 1.73, 0,  0, 1.82, 0,  r0: 0.085, r1: 0.085, sides: 6,  uBase: 0)

    // ── Robe (uBase=1): fitted torso + waist + wide two-section flared skirt ──
    addCylinder(0, 1.28, 0,  0, 1.70, 0,  r0: 0.295, r1: 0.215, sides: 12, uBase: 1)  // torso
    addCylinder(0, 1.05, 0,  0, 1.28, 0,  r0: 0.275, r1: 0.295, sides: 12, uBase: 1)  // waist
    addCylinder(0, 1.05, 0,  0, 0.46, 0,  r0: 0.275, r1: 0.530, sides: 14, uBase: 1)  // upper skirt
    addCylinder(0, 0.46, 0,  0, 0.00, 0,  r0: 0.530, r1: 0.670, sides: 14, uBase: 1)  // lower flare

    // ── Wizard hat (flat brim uBase=1, tall pointed cone uBase=3) ────────────
    addCylinder(0, 2.10, 0,  0, 2.13, 0,  r0: 0.275, r1: 0.275, sides: 14, uBase: 1)  // brim
    addCylinder(0, 2.13, 0,  0, 2.88, 0,  r0: 0.195, r1: 0.016, sides: 10, uBase: 3)  // cone

    // ── Right arm/sleeve (uBase=22) ───────────────────────────────────────────
    addCylinder( 0.28, 1.68, 0,   0.32, 1.28, 0,  r0: 0.072, r1: 0.058, sides: 6, uBase: 22)
    addCylinder( 0.32, 1.28, 0,   0.35, 0.90, 0,  r0: 0.058, r1: 0.044, sides: 6, uBase: 22)
    addSphere( 0.36, 0.86, 0, 0.054, slices: 6, rings: 4, uBase: 22)

    // ── Left arm/sleeve (uBase=23) ────────────────────────────────────────────
    addCylinder(-0.28, 1.68, 0,  -0.32, 1.28, 0,  r0: 0.072, r1: 0.058, sides: 6, uBase: 23)
    addCylinder(-0.32, 1.28, 0,  -0.35, 0.90, 0,  r0: 0.058, r1: 0.044, sides: 6, uBase: 23)
    addSphere(-0.36, 0.86, 0, 0.054, slices: 6, rings: 4, uBase: 23)

    // ── Staff in right hand (uBase=24 shaft, 25 orb) ─────────────────────────
    // Pivots around shoulder with no clamp — both ends tilt as a rigid rod.
    // All staff parts use uBase ≥ 24 so the walk animation in vert_world swings them together.
    let staffX: Float = 0.40
    // Tapered shaft, slightly taller than before
    addCylinder(staffX, 0.05, 0,  staffX, 2.05, 0,  r0: 0.028, r1: 0.022, sides: 8, uBase: 24)
    // Lower grip wrap (thicker band, suggests bound leather)
    addCylinder(staffX, 0.85, 0,  staffX, 1.05, 0,  r0: 0.040, r1: 0.040, sides: 8, uBase: 24)
    // Upper grip wrap
    addCylinder(staffX, 1.15, 0,  staffX, 1.32, 0,  r0: 0.040, r1: 0.040, sides: 8, uBase: 24)
    // Decorative metal collar just below the head
    addCylinder(staffX, 2.02, 0,  staffX, 2.12, 0,  r0: 0.054, r1: 0.046, sides: 10, uBase: 24)
    // Pointed butt-spike below the lower wrap
    addCylinder(staffX, 0.00, 0,  staffX, 0.05, 0,  r0: 0.000, r1: 0.028, sides: 6, uBase: 24)
    // Four crystal claws cradling the orb — splayed outward, curving up around the gem
    let orbY: Float = 2.32
    let orbR: Float = 0.105
    for i in 0 ..< 4 {
        let angle = Float.pi * 0.5 * Float(i) + Float.pi * 0.25
        let cx = cos(angle), sz = sin(angle)
        // base just above the metal collar
        let bx = staffX + cx * 0.045, bz = sz * 0.045
        // tip wraps just over the equator of the orb
        let tx = staffX + cx * 0.075, tz = sz * 0.075
        // uBase=25 → claws share the orb's emissive crystal shader treatment
        addCylinder(bx, 2.14, bz,  tx, orbY + 0.04, tz,
                    r0: 0.022, r1: 0.010, sides: 4, uBase: 25)
    }
    // The magic orb itself (uBase=25, animated emissive in shader)
    addSphere(staffX, orbY, 0, orbR, slices: 10, rings: 8, uBase: 25)

    let vBuf = device.makeBuffer(bytes: verts, length: verts.count * MemoryLayout<WorldVertex>.size, options: .storageModeShared)!
    let iBuf = device.makeBuffer(bytes: idxs,  length: idxs.count  * MemoryLayout<UInt16>.size,      options: .storageModeShared)!
    return (vBuf, iBuf, idxs.count)
}

/// Magic cone tree: three layered tiers, each with a drooping skirt + 12-sided for roundness.
/// Tiers are slightly rotated per layer giving a natural twisted silhouette.
func makeTree(device: MTLDevice) -> (vtx: MTLBuffer, idx: MTLBuffer, count: Int) {
    let sides = 12   // 12-sided = smooth, no harsh triangular panels
    var verts: [WorldVertex] = []
    var idxs:  [UInt16]     = []

    // Each tier: apex at topY, cone narrows from skirtY (coneR) down to apex.
    // A flared skirt ring at baseY (skirtR > coneR) creates a pine-branch droop.
    // rotOff staggers each tier slightly for a natural twisted look.
    let tiers: [(skirtY: Float, baseY: Float, topY: Float, coneR: Float, skirtR: Float, rotOff: Float)] = [
        (skirtY: 1.8,  baseY: 0.9,  topY: 5.2, coneR: 1.28, skirtR: 1.62, rotOff: 0.00),
        (skirtY: 3.6,  baseY: 2.8,  topY: 6.4, coneR: 0.80, skirtR: 1.02, rotOff: 0.26),
        (skirtY: 5.0,  baseY: 4.3,  topY: 7.4, coneR: 0.43, skirtR: 0.56, rotOff: 0.52),
    ]

    for tier in tiers {
        let hCone = tier.topY - tier.skirtY
        let nLen  = (hCone * hCone + tier.coneR * tier.coneR).squareRoot()

        // Apex
        let apexIdx = UInt16(verts.count)
        verts.append(WorldVertex(px: 0, py: tier.topY, pz: 0, nx: 0, ny: 1, nz: 0, u: 0.5, v: 0))

        // Cone ring (transition from cone to skirt)
        let coneBase = UInt16(verts.count)
        for i in 0 ... sides {
            let theta = tier.rotOff + 2.0 * Float.pi * Float(i) / Float(sides)
            let c = cos(theta), s = sin(theta)
            verts.append(WorldVertex(
                px: c * tier.coneR, py: tier.skirtY, pz: s * tier.coneR,
                nx: c * hCone / nLen, ny: tier.coneR / nLen, nz: s * hCone / nLen,
                u: Float(i) / Float(sides), v: 0.5))
        }

        // Skirt ring (drooping outward brim — like pine branch tips)
        let skirtBase = UInt16(verts.count)
        for i in 0 ... sides {
            let theta = tier.rotOff + 2.0 * Float.pi * Float(i) / Float(sides)
            let c = cos(theta), s = sin(theta)
            verts.append(WorldVertex(
                px: c * tier.skirtR, py: tier.baseY, pz: s * tier.skirtR,
                nx: c * 0.72, ny: -0.28, nz: s * 0.72,   // drooping outward normal
                u: Float(i) / Float(sides), v: 1.0))
        }

        // Apex → cone ring triangles
        for i in 0 ..< UInt16(sides) {
            idxs.append(contentsOf: [apexIdx, coneBase + i, coneBase + i + 1])
        }

        // Cone ring → skirt ring quads (capsule winding: [lower_i, upper_i, lower_i+1, …])
        for i in 0 ..< UInt16(sides) {
            let a = skirtBase + i;      let b = skirtBase + i + 1
            let c = coneBase  + i;      let d = coneBase  + i + 1
            idxs.append(contentsOf: [a, c, b,  b, c, d])
        }
    }

    // Three leaning trunks — converge at base, splay at top; bark UV marker ≥ 10
    let trunkSides = 6
    let trunkR: Float = 0.22;  let baseDist: Float = 0.06;  let topDist: Float = 0.58
    let trunkDefs: [(angle: Float, height: Float)] = [
        (0.5236, 2.0), (1.5708, 3.2), (2.6180, 2.5),
    ]
    for (k, td) in trunkDefs.enumerated() {
        let bx = cos(td.angle) * baseDist;  let bz = sin(td.angle) * baseDist
        let tx = cos(td.angle) * topDist;   let tz = sin(td.angle) * topDist
        let kf = Float(k);  let ts = UInt16(verts.count)
        for i in 0 ... trunkSides {
            let theta = 2.0 * Float.pi * Float(i) / Float(trunkSides)
            let c = cos(theta), s = sin(theta)
            let uEnc = 10.0 + kf + Float(i) / Float(trunkSides) * 0.9
            verts.append(WorldVertex(px: bx + c * trunkR, py: 0,         pz: bz + s * trunkR, nx: c, ny: 0, nz: s, u: uEnc, v: 1))
            verts.append(WorldVertex(px: tx + c * trunkR, py: td.height, pz: tz + s * trunkR, nx: c, ny: 0, nz: s, u: uEnc, v: 0))
        }
        for i in 0 ..< UInt16(trunkSides) {
            let a = ts + i * 2
            idxs.append(contentsOf: [a, a + 2, a + 1,  a + 1, a + 2, a + 3])
        }
    }

    let vBuf = device.makeBuffer(bytes: verts, length: verts.count * MemoryLayout<WorldVertex>.size, options: .storageModeShared)!
    let iBuf = device.makeBuffer(bytes: idxs,  length: idxs.count  * MemoryLayout<UInt16>.size,      options: .storageModeShared)!
    return (vBuf, iBuf, idxs.count)
}

/// Stone tower (mesh_id 8): octagonal body with crenellated top.
/// All vertices use u=0 so the world.metal stone-treatment branch applies uniformly.
func makeTower(device: MTLDevice) -> (vtx: MTLBuffer, idx: MTLBuffer, count: Int) {
    var verts: [WorldVertex] = []
    var idxs:  [UInt16]      = []

    let sides   = 8
    let radius: Float = 0.7
    let height: Float = 5.0
    let crenH:  Float = 0.45
    let toothFraction: Float = 0.5

    // ── Body: extruded octagon ──
    let bodyStart = UInt16(verts.count)
    for s in 0 ... sides {
        let theta = 2.0 * Float.pi * Float(s) / Float(sides)
        let cx = cos(theta), sz = sin(theta)
        verts.append(WorldVertex(px: cx*radius, py: 0,      pz: sz*radius,
                                 nx: cx, ny: 0, nz: sz, u: 0, v: 1))
        verts.append(WorldVertex(px: cx*radius, py: height, pz: sz*radius,
                                 nx: cx, ny: 0, nz: sz, u: 0, v: 0))
    }
    for i in 0 ..< UInt16(sides) {
        let a = bodyStart + i * 2
        idxs.append(contentsOf: [a, a + 2, a + 1,  a + 1, a + 2, a + 3])
    }

    // ── Top cap (octagon disc at body height) — fan from center ──
    let capCenter = UInt16(verts.count)
    verts.append(WorldVertex(px: 0, py: height, pz: 0, nx: 0, ny: 1, nz: 0, u: 0, v: 0.5))
    let rimStart = UInt16(verts.count)
    for s in 0 ... sides {
        let theta = 2.0 * Float.pi * Float(s) / Float(sides)
        verts.append(WorldVertex(px: cos(theta)*radius, py: height, pz: sin(theta)*radius,
                                 nx: 0, ny: 1, nz: 0, u: 0, v: 0))
    }
    for i in 0 ..< UInt16(sides) {
        idxs.append(contentsOf: [capCenter, rimStart + i + 1, rimStart + i])
    }

    // ── Crenellations: alternating teeth around the rim ──
    for s in 0 ..< sides {
        if s % 2 != 0 { continue }
        let theta0 = 2.0 * Float.pi * Float(s)     / Float(sides)
        let theta1 = 2.0 * Float.pi * Float(s + 1) / Float(sides)
        let pad = (theta1 - theta0) * (1.0 - toothFraction) * 0.5
        let t0 = theta0 + pad
        let t1 = theta1 - pad
        let inner: Float = radius * 0.85
        let r0x = cos(t0)*radius, r0z = sin(t0)*radius
        let r1x = cos(t1)*radius, r1z = sin(t1)*radius
        let i0x = cos(t0)*inner,  i0z = sin(t0)*inner
        let i1x = cos(t1)*inner,  i1z = sin(t1)*inner
        let yLo: Float = height
        let yHi: Float = height + crenH
        let base = UInt16(verts.count)
        verts.append(WorldVertex(px: r0x, py: yLo, pz: r0z, nx: cos(t0), ny: 0, nz: sin(t0), u: 0, v: 1))
        verts.append(WorldVertex(px: r0x, py: yHi, pz: r0z, nx: cos(t0), ny: 0, nz: sin(t0), u: 0, v: 0))
        verts.append(WorldVertex(px: r1x, py: yLo, pz: r1z, nx: cos(t1), ny: 0, nz: sin(t1), u: 0, v: 1))
        verts.append(WorldVertex(px: r1x, py: yHi, pz: r1z, nx: cos(t1), ny: 0, nz: sin(t1), u: 0, v: 0))
        verts.append(WorldVertex(px: i0x, py: yLo, pz: i0z, nx: -cos(t0), ny: 0, nz: -sin(t0), u: 0, v: 1))
        verts.append(WorldVertex(px: i0x, py: yHi, pz: i0z, nx: -cos(t0), ny: 0, nz: -sin(t0), u: 0, v: 0))
        verts.append(WorldVertex(px: i1x, py: yLo, pz: i1z, nx: -cos(t1), ny: 0, nz: -sin(t1), u: 0, v: 1))
        verts.append(WorldVertex(px: i1x, py: yHi, pz: i1z, nx: -cos(t1), ny: 0, nz: -sin(t1), u: 0, v: 0))
        idxs.append(contentsOf: [base + 0, base + 2, base + 1,  base + 1, base + 2, base + 3])
        idxs.append(contentsOf: [base + 1, base + 3, base + 5,  base + 5, base + 3, base + 7])
        idxs.append(contentsOf: [base + 4, base + 5, base + 6,  base + 6, base + 5, base + 7])
        idxs.append(contentsOf: [base + 0, base + 1, base + 4,  base + 4, base + 1, base + 5])
        idxs.append(contentsOf: [base + 2, base + 6, base + 3,  base + 3, base + 6, base + 7])
    }

    let vBuf = device.makeBuffer(bytes: verts, length: verts.count * MemoryLayout<WorldVertex>.size, options: .storageModeShared)!
    let iBuf = device.makeBuffer(bytes: idxs,  length: idxs.count  * MemoryLayout<UInt16>.size,      options: .storageModeShared)!
    return (vBuf, iBuf, idxs.count)
}

/// Wall torch (mesh_id 9): wooden pole + iron bowl + emissive flame cone.
/// uv.x bands: 0=pole, 1.5=bowl, 50=flame (>=50 marker triggers emissive shading).
func makeTorch(device: MTLDevice) -> (vtx: MTLBuffer, idx: MTLBuffer, count: Int) {
    var verts: [WorldVertex] = []
    var idxs:  [UInt16]      = []

    let poleSides = 6
    let poleR: Float = 0.05
    let poleH: Float = 1.4

    // ── Wooden pole ──
    let poleBase = UInt16(verts.count)
    for i in 0 ... poleSides {
        let theta = 2.0 * Float.pi * Float(i) / Float(poleSides)
        let cx = cos(theta), sz = sin(theta)
        verts.append(WorldVertex(px: cx*poleR, py: 0,     pz: sz*poleR,
                                 nx: cx, ny: 0, nz: sz, u: 0, v: 1))
        verts.append(WorldVertex(px: cx*poleR, py: poleH, pz: sz*poleR,
                                 nx: cx, ny: 0, nz: sz, u: 0, v: 0))
    }
    for i in 0 ..< UInt16(poleSides) {
        let a = poleBase + i * 2
        idxs.append(contentsOf: [a, a + 2, a + 1,  a + 1, a + 2, a + 3])
    }

    // ── Bowl: short tapered cylinder above the pole ──
    let bowlSides = 8
    let bowlR1: Float = 0.10
    let bowlR2: Float = 0.18
    let bowlH:  Float = 0.12
    let bowlY0: Float = poleH
    let bowlY1: Float = poleH + bowlH
    let bowlBase = UInt16(verts.count)
    for i in 0 ... bowlSides {
        let theta = 2.0 * Float.pi * Float(i) / Float(bowlSides)
        let cx = cos(theta), sz = sin(theta)
        verts.append(WorldVertex(px: cx*bowlR1, py: bowlY0, pz: sz*bowlR1,
                                 nx: cx, ny: 0, nz: sz, u: 1.5, v: 1))
        verts.append(WorldVertex(px: cx*bowlR2, py: bowlY1, pz: sz*bowlR2,
                                 nx: cx, ny: 0, nz: sz, u: 1.5, v: 0))
    }
    for i in 0 ..< UInt16(bowlSides) {
        let a = bowlBase + i * 2
        idxs.append(contentsOf: [a, a + 2, a + 1,  a + 1, a + 2, a + 3])
    }

    // ── Flame: tapered cone (u=50 marks emissive in world.metal) ──
    let flameSides = 8
    let flameR: Float = 0.16
    let flameH: Float = 0.42
    let flameY0: Float = bowlY1
    let flameY1: Float = bowlY1 + flameH
    let flameBase = UInt16(verts.count)
    for i in 0 ... flameSides {
        let theta = 2.0 * Float.pi * Float(i) / Float(flameSides)
        let cx = cos(theta), sz = sin(theta)
        verts.append(WorldVertex(px: cx*flameR, py: flameY0, pz: sz*flameR,
                                 nx: cx, ny: 0.5, nz: sz, u: 50.0, v: 1))
        verts.append(WorldVertex(px: 0,         py: flameY1, pz: 0,
                                 nx: 0, ny: 1, nz: 0, u: 50.0, v: 0))
    }
    for i in 0 ..< UInt16(flameSides) {
        let a = flameBase + i * 2
        idxs.append(contentsOf: [a, a + 2, a + 1])
    }

    let vBuf = device.makeBuffer(bytes: verts, length: verts.count * MemoryLayout<WorldVertex>.size, options: .storageModeShared)!
    let iBuf = device.makeBuffer(bytes: idxs,  length: idxs.count  * MemoryLayout<UInt16>.size,      options: .storageModeShared)!
    return (vBuf, iBuf, idxs.count)
}

/// Zone-transition portal (mesh_id 13): two stone pillars + arched top + vertical
/// emissive swirl disc between them. Stone parts use uBase=0; the swirl disc uses
/// uBase=60 (≥60 marker → emissive swirl shader branch).
func makePortal(device: MTLDevice) -> (vtx: MTLBuffer, idx: MTLBuffer, count: Int) {
    var verts: [WorldVertex] = []
    var idxs:  [UInt16]      = []

    func addCylinder(_ p0x: Float, _ p0y: Float, _ p0z: Float,
                     _ p1x: Float, _ p1y: Float, _ p1z: Float,
                     r0: Float, r1: Float, sides: Int, uBase: Float) {
        let dx = p1x-p0x, dy = p1y-p0y, dz = p1z-p0z
        let len = (dx*dx + dy*dy + dz*dz).squareRoot() + 1e-6
        let ax = dx/len, ay = dy/len, az = dz/len
        var rx: Float, ry: Float, rz: Float
        if abs(ay) < 0.9 {
            let cl = (az*az + ax*ax).squareRoot() + 1e-6
            rx = az/cl; ry = 0; rz = -ax/cl
        } else {
            let cl = (az*az + ay*ay).squareRoot() + 1e-6
            rx = 0; ry = -az/cl; rz = ay/cl
        }
        let ux = ay*rz - az*ry, uy = az*rx - ax*rz, uz = ax*ry - ay*rx
        let base = UInt16(verts.count)
        for i in 0...sides {
            let t = 2.0 * Float.pi * Float(i) / Float(sides)
            let c = cos(t), s = sin(t)
            let nx = c*rx + s*ux, ny = c*ry + s*uy, nz = c*rz + s*uz
            let nl = (nx*nx + ny*ny + nz*nz).squareRoot() + 1e-6
            let uEnc = uBase + Float(i)/Float(sides) * 0.9
            verts.append(WorldVertex(px: p0x+c*rx*r0+s*ux*r0, py: p0y+c*ry*r0+s*uy*r0, pz: p0z+c*rz*r0+s*uz*r0, nx: nx/nl, ny: ny/nl, nz: nz/nl, u: uEnc, v: 1))
            verts.append(WorldVertex(px: p1x+c*rx*r1+s*ux*r1, py: p1y+c*ry*r1+s*uy*r1, pz: p1z+c*rz*r1+s*uz*r1, nx: nx/nl, ny: ny/nl, nz: nz/nl, u: uEnc, v: 0))
        }
        for i in 0..<UInt16(sides) {
            let a = base + i*2
            idxs.append(contentsOf: [a, a+2, a+1,  a+1, a+2, a+3])
        }
    }

    func addSphere(_ cx: Float, _ cy: Float, _ cz: Float, _ r: Float,
                   slices: Int, rings: Int, uBase: Float) {
        let base = UInt16(verts.count)
        for ring in 0...rings {
            let phi = Float.pi * Float(ring) / Float(rings)
            let sinP = sin(phi), cosP = cos(phi)
            for sl in 0...slices {
                let theta = 2.0 * Float.pi * Float(sl) / Float(slices)
                let c = cos(theta), s = sin(theta)
                verts.append(WorldVertex(px: c*sinP*r+cx, py: -cosP*r+cy, pz: s*sinP*r+cz,
                                         nx: c*sinP, ny: -cosP, nz: s*sinP,
                                         u: uBase, v: Float(ring)/Float(rings)))
            }
        }
        for ring in 0..<rings { for sl in 0..<slices {
            let a = base + UInt16(ring*(slices+1)+sl)
            let b = a+1; let c2 = base + UInt16((ring+1)*(slices+1)+sl); let d = c2+1
            idxs.append(contentsOf: [a, c2, b,  b, c2, d])
        }}
    }

    // ── Foot disc: a single thick low cylinder underfoot, suggesting a worn
    //    threshold / footprint area for the gate (uBase=0 → stone treatment).
    addCylinder(0, 0, 0,  0, 0.12, 0,  r0: 1.7, r1: 1.6, sides: 12, uBase: 0)

    // ── Two outer buttress pillars (smaller, flanking the main arch) ──
    let buttressX: Float = 2.6
    let buttressH: Float = 3.1
    addCylinder(-buttressX, 0, 0,  -buttressX, buttressH, 0,  r0: 0.16, r1: 0.13, sides: 5, uBase: 0)
    addCylinder( buttressX, 0, 0,   buttressX, buttressH, 0,  r0: 0.16, r1: 0.13, sides: 5, uBase: 0)

    // ── Two side pillars (main arch supports) ──
    let pillarH: Float = 3.5
    let pillarX: Float = 1.2
    addCylinder(-pillarX, 0, 0,  -pillarX, pillarH, 0,  r0: 0.24, r1: 0.20, sides: 6, uBase: 0)
    addCylinder( pillarX, 0, 0,   pillarX, pillarH, 0,  r0: 0.24, r1: 0.20, sides: 6, uBase: 0)

    // ── Shoulder spans: short horizontal-ish links from buttress tops down to
    //    just below the main pillar tops, suggesting a continuous frame. ──
    addCylinder(-buttressX, buttressH, 0,  -pillarX, pillarH - 0.15, 0,  r0: 0.10, r1: 0.10, sides: 4, uBase: 0)
    addCylinder( buttressX, buttressH, 0,   pillarX, pillarH - 0.15, 0,  r0: 0.10, r1: 0.10, sides: 4, uBase: 0)

    // ── Decorative bands around main pillars (mid-height stone rings) ──
    addCylinder(-pillarX, 1.5, 0,  -pillarX, 1.65, 0,  r0: 0.30, r1: 0.27, sides: 8, uBase: 0)
    addCylinder( pillarX, 1.5, 0,   pillarX, 1.65, 0,  r0: 0.30, r1: 0.27, sides: 8, uBase: 0)

    // ── Glowing finials atop each pillar (uBase=80 → warm lantern shader branch) ──
    addSphere(-pillarX,   pillarH   + 0.18, 0, 0.16, slices: 6, rings: 4, uBase: 80)
    addSphere( pillarX,   pillarH   + 0.18, 0, 0.16, slices: 6, rings: 4, uBase: 80)
    addSphere(-buttressX, buttressH + 0.12, 0, 0.10, slices: 4, rings: 3, uBase: 80)
    addSphere( buttressX, buttressH + 0.12, 0, 0.10, slices: 4, rings: 3, uBase: 80)

    // ── Arched top: 4 cylinders following a parabolic-ish arc ──
    let archPts: [(Float, Float)] = [
        (-pillarX, pillarH),
        (-0.60,    pillarH + 0.40),
        ( 0.00,    pillarH + 0.55),
        ( 0.60,    pillarH + 0.40),
        ( pillarX, pillarH),
    ]
    for k in 0 ..< archPts.count - 1 {
        let p0 = archPts[k], p1 = archPts[k + 1]
        addCylinder(p0.0, p0.1, 0,  p1.0, p1.1, 0,  r0: 0.20, r1: 0.20, sides: 5, uBase: 0)
    }

    // ── Vertical light beacon: tall emissive cylinder rising from the arch peak.
    //    uBase=70 → beacon shader branch. Visible from anywhere on the map.
    let beaconBaseY: Float = pillarH + 0.55          // top of arch
    let beaconTopY:  Float = beaconBaseY + 14.0       // 14m beam (×scale at runtime)
    addCylinder(0, beaconBaseY, 0,  0, beaconTopY, 0,
                r0: 0.14, r1: 0.04, sides: 6, uBase: 70)

    // ── Inner emissive swirl disc (vertical quad in XY plane at z=0) ──
    // Marked with uBase=60 so the shader picks the portal-swirl branch.
    // Disc spans from y=0.4 to y=3.4, x=±1.05.
    let dHalfW: Float = 1.05
    let dyMin: Float = 0.4
    let dyMax: Float = 3.4
    let dBase = UInt16(verts.count)
    verts.append(WorldVertex(px: -dHalfW, py: dyMin, pz: 0, nx: 0, ny: 0, nz: 1, u: 60, v: 0))
    verts.append(WorldVertex(px:  dHalfW, py: dyMin, pz: 0, nx: 0, ny: 0, nz: 1, u: 60, v: 0))
    verts.append(WorldVertex(px: -dHalfW, py: dyMax, pz: 0, nx: 0, ny: 0, nz: 1, u: 60, v: 0))
    verts.append(WorldVertex(px:  dHalfW, py: dyMax, pz: 0, nx: 0, ny: 0, nz: 1, u: 60, v: 0))
    // Front face (CCW seen from +Z)
    idxs.append(contentsOf: [dBase + 0, dBase + 1, dBase + 2,  dBase + 2, dBase + 1, dBase + 3])
    // Back face (flipped winding so the swirl is visible from -Z too)
    idxs.append(contentsOf: [dBase + 0, dBase + 2, dBase + 1,  dBase + 2, dBase + 3, dBase + 1])

    let vBuf = device.makeBuffer(bytes: verts, length: verts.count * MemoryLayout<WorldVertex>.size, options: .storageModeShared)!
    let iBuf = device.makeBuffer(bytes: idxs,  length: idxs.count  * MemoryLayout<UInt16>.size,      options: .storageModeShared)!
    return (vBuf, iBuf, idxs.count)
}

/// Tall stone obelisk (mesh_id 14): 4-sided tapered pillar with a flat cap.
/// Used as a perimeter ring to mark the map edge visually.
func makeMonolith(device: MTLDevice) -> (vtx: MTLBuffer, idx: MTLBuffer, count: Int) {
    var verts: [WorldVertex] = []
    var idxs:  [UInt16]      = []

    let sides   = 4
    let baseR:  Float = 0.45
    let topR:   Float = 0.30
    let height: Float = 4.5

    let bodyStart = UInt16(verts.count)
    for s in 0 ... sides {
        let theta = 2.0 * Float.pi * Float(s) / Float(sides)
        let cx = cos(theta), sz = sin(theta)
        verts.append(WorldVertex(px: cx*baseR, py: 0,      pz: sz*baseR, nx: cx, ny: 0, nz: sz, u: 0, v: 1))
        verts.append(WorldVertex(px: cx*topR,  py: height, pz: sz*topR,  nx: cx, ny: 0, nz: sz, u: 0, v: 0))
    }
    for i in 0 ..< UInt16(sides) {
        let a = bodyStart + i * 2
        idxs.append(contentsOf: [a, a + 2, a + 1,  a + 1, a + 2, a + 3])
    }

    // Top cap (small flat top)
    let capCenter = UInt16(verts.count)
    verts.append(WorldVertex(px: 0, py: height, pz: 0, nx: 0, ny: 1, nz: 0, u: 0, v: 0.5))
    let rimStart = UInt16(verts.count)
    for s in 0 ... sides {
        let theta = 2.0 * Float.pi * Float(s) / Float(sides)
        verts.append(WorldVertex(px: cos(theta)*topR, py: height, pz: sin(theta)*topR, nx: 0, ny: 1, nz: 0, u: 0, v: 0))
    }
    for i in 0 ..< UInt16(sides) {
        idxs.append(contentsOf: [capCenter, rimStart + i + 1, rimStart + i])
    }

    let vBuf = device.makeBuffer(bytes: verts, length: verts.count * MemoryLayout<WorldVertex>.size, options: .storageModeShared)!
    let iBuf = device.makeBuffer(bytes: idxs,  length: idxs.count  * MemoryLayout<UInt16>.size,      options: .storageModeShared)!
    return (vBuf, iBuf, idxs.count)
}

// ── New asset 15: Stone Circle (mesh_id 15) ─ small henge of 6 standing stones
func makeStoneCircle(device: MTLDevice) -> (vtx: MTLBuffer, idx: MTLBuffer, count: Int) {
    var v: [WorldVertex] = []
    var i: [UInt16] = []
    let stones = 6
    let ringR: Float = 1.5
    for s in 0..<stones {
        let a = 2.0 * Float.pi * Float(s) / Float(stones)
        let bx = cos(a) * ringR
        let bz = sin(a) * ringR
        // Lean inward slightly: top is closer to center
        let tx = cos(a) * (ringR - 0.15)
        let tz = sin(a) * (ringR - 0.15)
        let tilt = Float.random(in: -0.05...0.05)
        mbCylinder(&v, &i, bx, 0, bz, tx + tilt, 0.95 + tilt, tz, r0: 0.20, r1: 0.13, sides: 5, uBase: 0)
    }
    return mbBuffers(v, i, device)
}

// ── New asset 16: Fallen Log (mesh_id 16) ─ horizontal mossy log lying on the ground
func makeFallenLog(device: MTLDevice) -> (vtx: MTLBuffer, idx: MTLBuffer, count: Int) {
    var v: [WorldVertex] = []
    var i: [UInt16] = []
    // Main trunk lying along X axis at y=0.4
    mbCylinder(&v, &i, -1.5, 0.4, 0,  1.5, 0.4, 0.05,  r0: 0.40, r1: 0.36, sides: 7, uBase: 10)
    // Bark caps at the ends (rough sphere stubs)
    mbSphere(&v, &i, -1.5, 0.4, 0,    0.40, slices: 6, rings: 4, uBase: 10)
    mbSphere(&v, &i,  1.5, 0.4, 0.05, 0.36, slices: 6, rings: 4, uBase: 10)
    // Two short broken side branches stubs
    mbCylinder(&v, &i, 0.3, 0.55, 0.0,  0.55, 0.78, 0.18, r0: 0.10, r1: 0.04, sides: 4, uBase: 10)
    mbCylinder(&v, &i, -0.6, 0.55, -0.05,  -0.85, 0.72, -0.20, r0: 0.09, r1: 0.03, sides: 4, uBase: 10)
    return mbBuffers(v, i, device)
}

// ── New asset 17: Tree Stump (mesh_id 17) ─ short cut trunk
func makeTreeStump(device: MTLDevice) -> (vtx: MTLBuffer, idx: MTLBuffer, count: Int) {
    var v: [WorldVertex] = []
    var i: [UInt16] = []
    // Stump body
    mbCylinder(&v, &i, 0, 0, 0,  0, 0.55, 0,  r0: 0.50, r1: 0.46, sides: 8, uBase: 10)
    // Flat top disc — thin wider cylinder gives the cut-wood look
    mbCylinder(&v, &i, 0, 0.55, 0,  0, 0.60, 0,  r0: 0.46, r1: 0.46, sides: 10, uBase: 11)
    // A small mushroom growing on the side
    mbCylinder(&v, &i, 0.42, 0.20, 0.10,  0.46, 0.30, 0.10,  r0: 0.04, r1: 0.04, sides: 4, uBase: 0)
    mbSphere(&v, &i, 0.46, 0.32, 0.10, 0.07, slices: 4, rings: 3, uBase: 8)
    return mbBuffers(v, i, device)
}

// ── New asset 18: Crystal Cluster (mesh_id 18) ─ emissive shards rising from ground
func makeCrystalCluster(device: MTLDevice) -> (vtx: MTLBuffer, idx: MTLBuffer, count: Int) {
    var v: [WorldVertex] = []
    var i: [UInt16] = []
    // 4 angled spires of different heights
    mbCylinder(&v, &i,  0.00, 0.0,  0.00,  0.05, 1.30, -0.10, r0: 0.18, r1: 0.0, sides: 4, uBase: 0)
    mbCylinder(&v, &i,  0.30, 0.0,  0.10,  0.45, 1.00,  0.15, r0: 0.13, r1: 0.0, sides: 4, uBase: 0)
    mbCylinder(&v, &i, -0.25, 0.0,  0.20, -0.32, 1.10,  0.30, r0: 0.11, r1: 0.0, sides: 4, uBase: 0)
    mbCylinder(&v, &i,  0.10, 0.0, -0.30,  0.18, 0.85, -0.45, r0: 0.09, r1: 0.0, sides: 4, uBase: 0)
    // Tiny base shard
    mbCylinder(&v, &i, -0.10, 0.0, -0.15, -0.05, 0.50, -0.20, r0: 0.06, r1: 0.0, sides: 3, uBase: 0)
    return mbBuffers(v, i, device)
}

// ── New asset 19: Bonfire (mesh_id 19) ─ stone ring + log pile + flame
func makeBonfire(device: MTLDevice) -> (vtx: MTLBuffer, idx: MTLBuffer, count: Int) {
    var v: [WorldVertex] = []
    var i: [UInt16] = []
    // Stone ring around the base (6 small rocks)
    for s in 0..<6 {
        let a = 2.0 * Float.pi * Float(s) / 6.0
        let cx = cos(a) * 0.7
        let cz = sin(a) * 0.7
        mbSphere(&v, &i, cx, 0.10, cz, 0.16, slices: 5, rings: 3, uBase: 0)
    }
    // Log pile — three crossed cylinders raising the fuel
    mbCylinder(&v, &i, -0.4, 0.18, -0.2,  0.4, 0.18, 0.2,  r0: 0.08, r1: 0.08, sides: 4, uBase: 10)
    mbCylinder(&v, &i, -0.4, 0.18,  0.2,  0.4, 0.18, -0.2, r0: 0.08, r1: 0.08, sides: 4, uBase: 10)
    mbCylinder(&v, &i, -0.2, 0.32, -0.3,  0.2, 0.32,  0.3, r0: 0.07, r1: 0.07, sides: 4, uBase: 10)
    // Flame cone — uBase=50 marks emissive flame in the shader
    let flameSides = 8
    let flameR: Float  = 0.40
    let flameY0: Float = 0.40
    let flameY1: Float = 1.45
    let flameBase = UInt16(v.count)
    for k in 0...flameSides {
        let theta = 2.0 * Float.pi * Float(k) / Float(flameSides)
        let cx = cos(theta), sz = sin(theta)
        v.append(WorldVertex(px: cx*flameR, py: flameY0, pz: sz*flameR, nx: cx, ny: 0.5, nz: sz, u: 50.0, v: 1))
        v.append(WorldVertex(px: 0,         py: flameY1, pz: 0,          nx: 0,  ny: 1,   nz: 0,  u: 50.0, v: 0))
    }
    for k in 0..<UInt16(flameSides) {
        let a = flameBase + k * 2
        i.append(contentsOf: [a, a + 2, a + 1])
    }
    return mbBuffers(v, i, device)
}

// ── New asset 20: Dead Tree (mesh_id 20) ─ twisted bare trunk + branches, no leaves
func makeDeadTree(device: MTLDevice) -> (vtx: MTLBuffer, idx: MTLBuffer, count: Int) {
    var v: [WorldVertex] = []
    var i: [UInt16] = []
    // Twisting trunk: two segments at slight bend
    mbCylinder(&v, &i,  0,    0,    0,      0.05, 1.3,  0.05, r0: 0.20, r1: 0.16, sides: 5, uBase: 0)
    mbCylinder(&v, &i,  0.05, 1.3,  0.05,  -0.04, 2.4,  0.10, r0: 0.16, r1: 0.10, sides: 5, uBase: 0)
    mbCylinder(&v, &i, -0.04, 2.4,  0.10,   0.10, 3.3, -0.05, r0: 0.10, r1: 0.05, sides: 4, uBase: 0)
    // Bare angular branches (no leaves)
    mbCylinder(&v, &i,  0.05, 1.6,  0.05,   0.6, 2.1,  0.30, r0: 0.07, r1: 0.02, sides: 4, uBase: 0)
    mbCylinder(&v, &i,  0.05, 1.6,  0.05,  -0.5, 2.0, -0.20, r0: 0.06, r1: 0.02, sides: 4, uBase: 0)
    mbCylinder(&v, &i, -0.04, 2.4,  0.10,   0.55, 3.1, 0.4,  r0: 0.06, r1: 0.02, sides: 4, uBase: 0)
    mbCylinder(&v, &i, -0.04, 2.4,  0.10,  -0.55, 3.0, -0.3, r0: 0.06, r1: 0.02, sides: 4, uBase: 0)
    mbCylinder(&v, &i,  0.10, 3.3, -0.05,   0.40, 3.7, -0.30, r0: 0.04, r1: 0.01, sides: 3, uBase: 0)
    mbCylinder(&v, &i,  0.10, 3.3, -0.05,  -0.30, 3.6,  0.25, r0: 0.04, r1: 0.01, sides: 3, uBase: 0)
    return mbBuffers(v, i, device)
}

// ── New asset 21: Giant Mushroom (mesh_id 21) ─ POE2-style oversized fungus
func makeGiantMushroom(device: MTLDevice) -> (vtx: MTLBuffer, idx: MTLBuffer, count: Int) {
    var v: [WorldVertex] = []
    var i: [UInt16] = []
    // Stem (slight bulge near base)
    mbCylinder(&v, &i, 0, 0,    0,  0, 0.30, 0,  r0: 0.30, r1: 0.22, sides: 8, uBase: 0)
    mbCylinder(&v, &i, 0, 0.30, 0,  0, 0.95, 0,  r0: 0.22, r1: 0.18, sides: 8, uBase: 0)
    // Cap underside (skirt at the top of the stem)
    mbCylinder(&v, &i, 0, 0.95, 0,  0, 1.05, 0,  r0: 0.30, r1: 0.55, sides: 10, uBase: 8)
    // Cap dome (uBase=8 → emissive in shader)
    mbSphere(&v, &i, 0, 1.05, 0, 0.55, slices: 10, rings: 5, uBase: 8)
    return mbBuffers(v, i, device)
}

// ── New asset 22: Banner Pole (mesh_id 22) ─ tall pole with hanging cloth banner
func makeBannerPole(device: MTLDevice) -> (vtx: MTLBuffer, idx: MTLBuffer, count: Int) {
    var v: [WorldVertex] = []
    var i: [UInt16] = []
    // Pole
    mbCylinder(&v, &i, 0, 0, 0,  0, 3.5, 0,  r0: 0.07, r1: 0.05, sides: 6, uBase: 10)
    // Crossbar
    mbCylinder(&v, &i, -0.65, 3.05, 0,  0.65, 3.05, 0,  r0: 0.04, r1: 0.04, sides: 4, uBase: 10)
    // Spear tip on top
    mbCylinder(&v, &i, 0, 3.5, 0,  0, 3.85, 0,  r0: 0.06, r1: 0.0, sides: 4, uBase: 10)
    // Banner cloth — vertical quad in the XY plane (uBase=25 = cloth shader branch)
    let dl: Float    = 0.55
    let dyMin: Float = 1.20
    let dyMax: Float = 3.00
    let dBase = UInt16(v.count)
    v.append(WorldVertex(px: -dl, py: dyMin, pz: 0, nx: 0, ny: 0, nz: 1, u: 25.0, v: 1))
    v.append(WorldVertex(px:  dl, py: dyMin, pz: 0, nx: 0, ny: 0, nz: 1, u: 25.0, v: 1))
    v.append(WorldVertex(px: -dl, py: dyMax, pz: 0, nx: 0, ny: 0, nz: 1, u: 25.0, v: 0))
    v.append(WorldVertex(px:  dl, py: dyMax, pz: 0, nx: 0, ny: 0, nz: 1, u: 25.0, v: 0))
    i.append(contentsOf: [dBase, dBase + 1, dBase + 2,  dBase + 2, dBase + 1, dBase + 3])
    i.append(contentsOf: [dBase, dBase + 2, dBase + 1,  dBase + 2, dBase + 3, dBase + 1])
    return mbBuffers(v, i, device)
}

// ── New asset 23: Berry Bush (mesh_id 23) ─ clumped foliage with glowing berries
func makeBerryBush(device: MTLDevice) -> (vtx: MTLBuffer, idx: MTLBuffer, count: Int) {
    var v: [WorldVertex] = []
    var i: [UInt16] = []
    // Foliage: 5 overlapping spheres
    mbSphere(&v, &i,  0.00, 0.30,  0.00, 0.36, slices: 6, rings: 4, uBase: 0)
    mbSphere(&v, &i,  0.25, 0.25,  0.15, 0.30, slices: 6, rings: 4, uBase: 0)
    mbSphere(&v, &i, -0.20, 0.35,  0.10, 0.30, slices: 6, rings: 4, uBase: 0)
    mbSphere(&v, &i,  0.10, 0.45, -0.15, 0.26, slices: 5, rings: 3, uBase: 0)
    mbSphere(&v, &i, -0.15, 0.30, -0.20, 0.26, slices: 5, rings: 3, uBase: 0)
    // Berries (uBase=8 → emissive red in shader)
    mbSphere(&v, &i,  0.20, 0.42,  0.10, 0.06, slices: 4, rings: 3, uBase: 8)
    mbSphere(&v, &i, -0.10, 0.50,  0.18, 0.06, slices: 4, rings: 3, uBase: 8)
    mbSphere(&v, &i,  0.02, 0.32, -0.25, 0.06, slices: 4, rings: 3, uBase: 8)
    mbSphere(&v, &i, -0.25, 0.42, -0.05, 0.05, slices: 4, rings: 3, uBase: 8)
    return mbBuffers(v, i, device)
}

// ── New asset 24: Forest Shrine (mesh_id 24) ─ small wooden shrine with offering
func makeShrine(device: MTLDevice) -> (vtx: MTLBuffer, idx: MTLBuffer, count: Int) {
    var v: [WorldVertex] = []
    var i: [UInt16] = []
    // 4 corner posts (square footprint)
    mbCylinder(&v, &i, -0.55, 0, -0.55,  -0.55, 1.50, -0.55, r0: 0.06, r1: 0.06, sides: 4, uBase: 10)
    mbCylinder(&v, &i,  0.55, 0, -0.55,   0.55, 1.50, -0.55, r0: 0.06, r1: 0.06, sides: 4, uBase: 10)
    mbCylinder(&v, &i, -0.55, 0,  0.55,  -0.55, 1.50,  0.55, r0: 0.06, r1: 0.06, sides: 4, uBase: 10)
    mbCylinder(&v, &i,  0.55, 0,  0.55,   0.55, 1.50,  0.55, r0: 0.06, r1: 0.06, sides: 4, uBase: 10)
    // Roof beams: peaked square pyramid converging at apex above center
    mbCylinder(&v, &i, -0.65, 1.50, -0.65,  0.0, 2.05, 0.0,  r0: 0.04, r1: 0.03, sides: 3, uBase: 10)
    mbCylinder(&v, &i,  0.65, 1.50, -0.65,  0.0, 2.05, 0.0,  r0: 0.04, r1: 0.03, sides: 3, uBase: 10)
    mbCylinder(&v, &i, -0.65, 1.50,  0.65,  0.0, 2.05, 0.0,  r0: 0.04, r1: 0.03, sides: 3, uBase: 10)
    mbCylinder(&v, &i,  0.65, 1.50,  0.65,  0.0, 2.05, 0.0,  r0: 0.04, r1: 0.03, sides: 3, uBase: 10)
    // Cross-bracing under the roof (visible side beams)
    mbCylinder(&v, &i, -0.55, 1.50, -0.55,   0.55, 1.50, -0.55, r0: 0.04, r1: 0.04, sides: 3, uBase: 10)
    mbCylinder(&v, &i, -0.55, 1.50,  0.55,   0.55, 1.50,  0.55, r0: 0.04, r1: 0.04, sides: 3, uBase: 10)
    // Stone offering plate (uBase=0 → stone treatment)
    mbCylinder(&v, &i, 0, 0.30, 0,  0, 0.42, 0, r0: 0.32, r1: 0.30, sides: 8, uBase: 0)
    // Glowing offering at the center (uBase=8 → emissive)
    mbSphere(&v, &i, 0, 0.55, 0, 0.10, slices: 5, rings: 3, uBase: 8)
    return mbBuffers(v, i, device)
}

// ── Enemy 25: Forest Wisp ─────────────────────────────────────────────────────
// 20+ design features: outer body + inner core + 4 trailing tendrils + 2 side
// curls (3-segment each) + 3 orbiting shards + 4-spike crown ring + bottom
// drifting tail + mid-belt ring + front whisker tendrils + top crown bulb +
// emissive treatment per part. uBase=0 → wisp shader branch handles all.
func makeForestWisp(device: MTLDevice) -> (vtx: MTLBuffer, idx: MTLBuffer, count: Int) {
    var v: [WorldVertex] = []
    var i: [UInt16] = []
    // 1: outer body sphere
    mbSphere(&v, &i, 0, 0.55, 0, 0.28, slices: 8, rings: 6, uBase: 0)
    // 2: inner core sphere (smaller, brighter via shader y-position lookup)
    mbSphere(&v, &i, 0, 0.55, 0, 0.13, slices: 6, rings: 4, uBase: 1)
    // 3: top crown bulb
    mbSphere(&v, &i, 0, 0.86, 0, 0.07, slices: 4, rings: 3, uBase: 1)
    // 4-7: 4 trailing tendrils (downward tapering cylinders, varied angles)
    let tendrilOff: [(Float, Float)] = [(0.10, 0.0), (-0.08, 0.05), (0.05, -0.10), (-0.06, -0.05)]
    for t in tendrilOff {
        mbCylinder(&v, &i, t.0 * 0.6, 0.45, t.1 * 0.6,  t.0, 0.05, t.1,
                   r0: 0.04, r1: 0.005, sides: 4, uBase: 0)
    }
    // 8-9: two S-curve side curls (3-segment each)
    mbCylinder(&v, &i,  0.28, 0.55,  0.0,   0.42, 0.65, -0.06, r0: 0.04, r1: 0.025, sides: 4, uBase: 0)
    mbCylinder(&v, &i,  0.42, 0.65, -0.06,  0.50, 0.50, -0.16, r0: 0.025, r1: 0.012, sides: 4, uBase: 0)
    mbCylinder(&v, &i,  0.50, 0.50, -0.16,  0.45, 0.32, -0.10, r0: 0.012, r1: 0.0, sides: 3, uBase: 0)
    mbCylinder(&v, &i, -0.28, 0.55,  0.0,  -0.42, 0.65,  0.06, r0: 0.04, r1: 0.025, sides: 4, uBase: 0)
    mbCylinder(&v, &i, -0.42, 0.65,  0.06, -0.50, 0.50,  0.16, r0: 0.025, r1: 0.012, sides: 4, uBase: 0)
    mbCylinder(&v, &i, -0.50, 0.50,  0.16, -0.45, 0.32,  0.10, r0: 0.012, r1: 0.0, sides: 3, uBase: 0)
    // 10-12: orbiting shards (small spheres at fixed positions around the body)
    mbSphere(&v, &i,  0.36, 0.78,  0.10, 0.045, slices: 4, rings: 3, uBase: 2)
    mbSphere(&v, &i, -0.30, 0.50, -0.20, 0.045, slices: 4, rings: 3, uBase: 2)
    mbSphere(&v, &i,  0.20, 0.40,  0.32, 0.045, slices: 4, rings: 3, uBase: 2)
    // 13-16: crown ring of 4 small upward spikes
    for k in 0..<4 {
        let a = Float.pi * 2.0 * Float(k) / 4.0
        let cx = cos(a) * 0.16
        let cz = sin(a) * 0.16
        mbCylinder(&v, &i, cx, 0.78, cz, cx * 1.4, 0.92, cz * 1.4,
                   r0: 0.025, r1: 0.0, sides: 3, uBase: 1)
    }
    // 17: drifting bottom tail (long thin cylinder fading to nothing)
    mbCylinder(&v, &i, 0, 0.30, 0,  0, -0.10, 0.0, r0: 0.05, r1: 0.0, sides: 4, uBase: 0)
    // 18: mid-belt ring (thin equator band around body)
    for k in 0..<8 {
        let a0 = Float.pi * 2.0 * Float(k) / 8.0
        let a1 = Float.pi * 2.0 * Float(k + 1) / 8.0
        mbCylinder(&v, &i, cos(a0) * 0.30, 0.55, sin(a0) * 0.30,
                          cos(a1) * 0.30, 0.55, sin(a1) * 0.30,
                          r0: 0.012, r1: 0.012, sides: 3, uBase: 1)
    }
    // 19-20: two forward whisker tendrils (front-facing curls)
    mbCylinder(&v, &i,  0.05, 0.60, -0.25,  0.10, 0.55, -0.45, r0: 0.020, r1: 0.005, sides: 3, uBase: 0)
    mbCylinder(&v, &i, -0.05, 0.60, -0.25, -0.10, 0.55, -0.45, r0: 0.020, r1: 0.005, sides: 3, uBase: 0)
    return mbBuffers(v, i, device)
}

// ── Enemy 26: Tree Ent ───────────────────────────────────────────────────────
// 20+ design features: 3-segment trunk + 2 root legs + 6 toe roots + 2 multi-
// segment arms + 6 finger claws + head + 2 glowing eyes + knot mouth + 2
// shoulder mossy growths + 5 crown branches + 5 foliage clusters + 4 hanging
// vines + 3 spine knots + beard moss. Bark via uBase=10 (existing branch),
// foliage uBase=20-21, eyes uBase=8.
func makeTreeEnt(device: MTLDevice) -> (vtx: MTLBuffer, idx: MTLBuffer, count: Int) {
    var v: [WorldVertex] = []
    var i: [UInt16] = []
    // 1-3: trunk lower / mid / upper (slight bend)
    mbCylinder(&v, &i, 0, 0,    0,    0.05, 1.20, 0.05, r0: 0.40, r1: 0.34, sides: 6, uBase: 10)
    mbCylinder(&v, &i, 0.05, 1.20, 0.05, -0.05, 2.10, 0.10, r0: 0.34, r1: 0.28, sides: 6, uBase: 10)
    mbCylinder(&v, &i, -0.05, 2.10, 0.10, 0.0,  2.85, 0.05, r0: 0.28, r1: 0.22, sides: 6, uBase: 10)
    // 4-5: root legs splayed outward
    mbCylinder(&v, &i,  0,    0,  0,   0.55, 0,  0.30, r0: 0.20, r1: 0.16, sides: 5, uBase: 10)
    mbCylinder(&v, &i,  0,    0,  0,  -0.55, 0, -0.30, r0: 0.20, r1: 0.16, sides: 5, uBase: 10)
    // 6-11: 3 toe roots per leg (small angled cones from each foot)
    for sx: Float in [-1, 1] {
        let footX = sx * 0.55
        let footZ = sx * 0.30
        for k in 0..<3 {
            let off = Float(k - 1) * 0.13
            mbCylinder(&v, &i, footX, 0, footZ + off,
                       footX + sx * 0.16, 0.0, footZ + off + sx * 0.10,
                       r0: 0.07, r1: 0.0, sides: 3, uBase: 10)
        }
    }
    // 12-13: upper arms
    mbCylinder(&v, &i, -0.32, 2.20,  0.05,  -0.65, 1.60,  0.20, r0: 0.13, r1: 0.10, sides: 5, uBase: 10)
    mbCylinder(&v, &i,  0.32, 2.20,  0.05,   0.65, 1.60,  0.20, r0: 0.13, r1: 0.10, sides: 5, uBase: 10)
    // 14-15: lower arms
    mbCylinder(&v, &i, -0.65, 1.60,  0.20,  -0.85, 1.05,  0.30, r0: 0.10, r1: 0.07, sides: 5, uBase: 10)
    mbCylinder(&v, &i,  0.65, 1.60,  0.20,   0.85, 1.05,  0.30, r0: 0.10, r1: 0.07, sides: 5, uBase: 10)
    // 16-21: 3 finger claws per hand, splayed
    for sx: Float in [-1, 1] {
        let hx = sx * 0.85
        let hy: Float = 1.05
        let hz: Float = 0.30
        for k in 0..<3 {
            let off = Float(k - 1) * 0.07
            mbCylinder(&v, &i, hx + off, hy, hz,
                       hx + off + sx * 0.10, hy - 0.18, hz + 0.10,
                       r0: 0.045, r1: 0.0, sides: 3, uBase: 10)
        }
    }
    // 22: head sphere on top of trunk
    mbSphere(&v, &i, 0, 3.05, 0.05, 0.32, slices: 8, rings: 6, uBase: 10)
    // 23-24: deep glowing eye sockets (uBase=8 → emissive amber in shader)
    mbSphere(&v, &i, -0.12, 3.10, -0.20, 0.045, slices: 4, rings: 3, uBase: 8)
    mbSphere(&v, &i,  0.12, 3.10, -0.20, 0.045, slices: 4, rings: 3, uBase: 8)
    // 25: knot mouth (small dark hole, uBase=10 keeps it bark-toned)
    mbCylinder(&v, &i, 0, 2.95, -0.22,  0, 2.95, -0.30, r0: 0.06, r1: 0.04, sides: 4, uBase: 10)
    // 26-27: shoulder mossy growths (uBase=20 = foliage shader branch)
    mbSphere(&v, &i, -0.25, 2.55, 0.10, 0.18, slices: 6, rings: 4, uBase: 20)
    mbSphere(&v, &i,  0.25, 2.55, 0.10, 0.18, slices: 6, rings: 4, uBase: 20)
    // 28-32: five branch crown rising from head
    let crownAngles: [Float] = [0, 1.26, 2.51, 3.77, 5.03] // 5 around 360°
    for ca in crownAngles {
        let cx = cos(ca) * 0.10
        let cz = sin(ca) * 0.10
        let tx = cos(ca) * 0.45
        let tz = sin(ca) * 0.45
        mbCylinder(&v, &i, cx, 3.30, cz, tx, 3.95, tz,
                   r0: 0.06, r1: 0.025, sides: 4, uBase: 10)
        // 33-37: foliage cluster at the tip of each crown branch
        mbSphere(&v, &i, tx, 3.95, tz, 0.22, slices: 6, rings: 4, uBase: 20)
        // Smaller secondary leaf cluster
        mbSphere(&v, &i, tx * 0.7, 3.85, tz * 0.7, 0.14, slices: 5, rings: 3, uBase: 21)
    }
    // 38-41: four hanging vines from arms (uBase=14 = bark shader gives mahogany dark vine)
    mbCylinder(&v, &i, -0.65, 1.55, 0.20,  -0.55, 0.85, 0.25, r0: 0.025, r1: 0.012, sides: 3, uBase: 14)
    mbCylinder(&v, &i, -0.78, 1.20, 0.25,  -0.78, 0.55, 0.30, r0: 0.022, r1: 0.010, sides: 3, uBase: 14)
    mbCylinder(&v, &i,  0.65, 1.55, 0.20,   0.55, 0.85, 0.25, r0: 0.025, r1: 0.012, sides: 3, uBase: 14)
    mbCylinder(&v, &i,  0.78, 1.20, 0.25,   0.78, 0.55, 0.30, r0: 0.022, r1: 0.010, sides: 3, uBase: 14)
    // 42-44: spine knots on the back
    mbSphere(&v, &i, 0, 2.40, 0.32, 0.07, slices: 4, rings: 3, uBase: 10)
    mbSphere(&v, &i, 0, 1.85, 0.36, 0.07, slices: 4, rings: 3, uBase: 10)
    mbSphere(&v, &i, 0, 1.30, 0.34, 0.06, slices: 4, rings: 3, uBase: 10)
    // 45: beard moss hanging under chin
    mbCylinder(&v, &i, 0, 2.90, -0.15,  0, 2.55, -0.18, r0: 0.06, r1: 0.03, sides: 4, uBase: 20)
    return mbBuffers(v, i, device)
}

// ── Enemy 27: Skeleton Knight ────────────────────────────────────────────────
// 20+ design features: skull + 2 eye sockets + jaw + 3 teeth + 3 vertebrae +
// 3 ribs + pelvis + 2 pauldrons + 2 upper arms + 2 lower arms + 2 hands +
// sword (shaft + crossguard + pommel) + shield (disc + boss) + 2 thigh bones +
// 2 shin bones + 2 feet. Bone uBase=0 (treated as bone-cream in shader),
// eye sockets uBase=8 (emissive red), metal weapons uBase=20 (steel branch).
func makeSkeletonKnight(device: MTLDevice) -> (vtx: MTLBuffer, idx: MTLBuffer, count: Int) {
    var v: [WorldVertex] = []
    var i: [UInt16] = []
    // 1: skull
    mbSphere(&v, &i, 0, 1.78, 0, 0.16, slices: 8, rings: 6, uBase: 0)
    // 2-3: eye sockets — small dark spheres recessed into the front
    mbSphere(&v, &i, -0.06, 1.80, -0.13, 0.030, slices: 4, rings: 3, uBase: 8)
    mbSphere(&v, &i,  0.06, 1.80, -0.13, 0.030, slices: 4, rings: 3, uBase: 8)
    // 4: jaw (small cylinder)
    mbCylinder(&v, &i, 0, 1.66, -0.05,  0, 1.62, -0.16, r0: 0.10, r1: 0.07, sides: 5, uBase: 0)
    // 5-7: 3 teeth on the jaw
    mbCylinder(&v, &i, -0.05, 1.66, -0.13, -0.05, 1.61, -0.13, r0: 0.013, r1: 0.0, sides: 3, uBase: 0)
    mbCylinder(&v, &i,  0.00, 1.66, -0.14,  0.00, 1.60, -0.14, r0: 0.013, r1: 0.0, sides: 3, uBase: 0)
    mbCylinder(&v, &i,  0.05, 1.66, -0.13,  0.05, 1.61, -0.13, r0: 0.013, r1: 0.0, sides: 3, uBase: 0)
    // 8-10: spine vertebrae
    mbSphere(&v, &i, 0, 1.55, 0, 0.075, slices: 5, rings: 3, uBase: 0)
    mbSphere(&v, &i, 0, 1.40, 0, 0.075, slices: 5, rings: 3, uBase: 0)
    mbSphere(&v, &i, 0, 1.25, 0, 0.080, slices: 5, rings: 3, uBase: 0)
    // 11-13: ribcage — 3 horizontal arched cylinders
    mbCylinder(&v, &i, -0.18, 1.42, 0,  0.18, 1.42, 0, r0: 0.025, r1: 0.025, sides: 3, uBase: 0)
    mbCylinder(&v, &i, -0.20, 1.32, 0,  0.20, 1.32, 0, r0: 0.025, r1: 0.025, sides: 3, uBase: 0)
    mbCylinder(&v, &i, -0.18, 1.22, 0,  0.18, 1.22, 0, r0: 0.025, r1: 0.025, sides: 3, uBase: 0)
    // 14: pelvic plate
    mbCylinder(&v, &i, 0, 1.10, 0,  0, 1.04, 0, r0: 0.16, r1: 0.13, sides: 6, uBase: 0)
    // 15-16: shoulder pauldrons (steel uBase=20)
    mbSphere(&v, &i, -0.18, 1.50, 0, 0.10, slices: 5, rings: 4, uBase: 20)
    mbSphere(&v, &i,  0.18, 1.50, 0, 0.10, slices: 5, rings: 4, uBase: 20)
    // 17-18: upper arms
    mbCylinder(&v, &i, -0.20, 1.45, 0,  -0.30, 1.10, 0.03, r0: 0.045, r1: 0.040, sides: 4, uBase: 0)
    mbCylinder(&v, &i,  0.20, 1.45, 0,   0.30, 1.10, 0.03, r0: 0.045, r1: 0.040, sides: 4, uBase: 0)
    // 19-20: lower arms (left holds shield, right holds sword)
    mbCylinder(&v, &i, -0.30, 1.10, 0.03,  -0.42, 0.78, 0.10, r0: 0.040, r1: 0.034, sides: 4, uBase: 0)
    mbCylinder(&v, &i,  0.30, 1.10, 0.03,   0.40, 0.85, 0.20, r0: 0.040, r1: 0.034, sides: 4, uBase: 0)
    // 21-22: hands (small spheres)
    mbSphere(&v, &i, -0.42, 0.78, 0.10, 0.045, slices: 4, rings: 3, uBase: 0)
    mbSphere(&v, &i,  0.40, 0.85, 0.20, 0.045, slices: 4, rings: 3, uBase: 0)
    // 23: sword shaft (long thin cylinder, vertical, mounted in right hand)
    mbCylinder(&v, &i, 0.40, 0.85, 0.20,  0.40, 1.85, 0.20, r0: 0.025, r1: 0.020, sides: 4, uBase: 20)
    // 24: sword crossguard (short horizontal cylinder)
    mbCylinder(&v, &i, 0.27, 0.95, 0.20,  0.53, 0.95, 0.20, r0: 0.020, r1: 0.020, sides: 4, uBase: 20)
    // 25: sword pommel (small sphere at base of grip)
    mbSphere(&v, &i, 0.40, 0.80, 0.20, 0.030, slices: 4, rings: 3, uBase: 20)
    // 26: shield disc (vertical circular disc on left arm — flat low cylinder)
    mbCylinder(&v, &i, -0.46, 0.92, 0.16,  -0.50, 0.92, 0.16, r0: 0.22, r1: 0.22, sides: 10, uBase: 20)
    // 27: shield boss (central spherical bump on the shield)
    mbSphere(&v, &i, -0.48, 0.92, 0.16, 0.050, slices: 5, rings: 3, uBase: 21)
    // 28-29: thigh bones
    mbCylinder(&v, &i, -0.08, 1.04, 0,  -0.10, 0.55, 0.02, r0: 0.055, r1: 0.045, sides: 4, uBase: 0)
    mbCylinder(&v, &i,  0.08, 1.04, 0,   0.10, 0.55, 0.02, r0: 0.055, r1: 0.045, sides: 4, uBase: 0)
    // 30-31: shin bones
    mbCylinder(&v, &i, -0.10, 0.55, 0.02,  -0.10, 0.05, 0.05, r0: 0.045, r1: 0.038, sides: 4, uBase: 0)
    mbCylinder(&v, &i,  0.10, 0.55, 0.02,   0.10, 0.05, 0.05, r0: 0.045, r1: 0.038, sides: 4, uBase: 0)
    // 32-33: feet (low flat slabs)
    mbCylinder(&v, &i, -0.10, 0, 0.05,  -0.10, 0.05, 0.05, r0: 0.080, r1: 0.080, sides: 5, uBase: 0)
    mbCylinder(&v, &i,  0.10, 0, 0.05,   0.10, 0.05, 0.05, r0: 0.080, r1: 0.080, sides: 5, uBase: 0)
    return mbBuffers(v, i, device)
}
