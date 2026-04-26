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
    addSphere(0, 0.46, 0, 0.20, slices: 8, rings: 6, uBase: 0)          // torso
    addCylinder(0, 0.63, -0.02,  0, 0.70, -0.03,  r0: 0.090, r1: 0.090, sides: 5, uBase: 0) // neck
    addSphere(0, 0.76, -0.04, 0.14, slices: 8, rings: 6, uBase: 0)      // head

    // Curved horns: two-segment, each bigger and arching back
    addCylinder(-0.07, 0.86, -0.04,  -0.13, 1.04, -0.10,  r0: 0.030, r1: 0.012, sides: 5, uBase: 0)
    addCylinder(-0.13, 1.04, -0.10,  -0.16, 1.16,  0.00,  r0: 0.012, r1: 0.004, sides: 4, uBase: 0)
    addCylinder( 0.07, 0.86, -0.04,   0.13, 1.04, -0.10,  r0: 0.030, r1: 0.012, sides: 5, uBase: 0)
    addCylinder( 0.13, 1.04, -0.10,   0.16, 1.16,  0.00,  r0: 0.012, r1: 0.004, sides: 4, uBase: 0)

    // Pointed bat-style ears
    addCylinder(-0.13, 0.78, -0.05, -0.18, 0.86, -0.06, r0: 0.024, r1: 0.004, sides: 3, uBase: 0)
    addCylinder( 0.13, 0.78, -0.05,  0.18, 0.86, -0.06, r0: 0.024, r1: 0.004, sides: 3, uBase: 0)

    // Brow ridge — single thin bar above the eyes
    addCylinder(-0.10, 0.83, -0.13,  0.10, 0.83, -0.13,  r0: 0.020, r1: 0.020, sides: 4, uBase: 0)

    // Glowing eye gems (uBase=8 — emissive crimson in shader)
    addSphere(-0.05, 0.78, -0.16, 0.022, slices: 4, rings: 3, uBase: 8)
    addSphere( 0.05, 0.78, -0.16, 0.022, slices: 4, rings: 3, uBase: 8)

    // Fangs — two small downward cones from mouth area
    addCylinder(-0.03, 0.74, -0.16, -0.03, 0.69, -0.16, r0: 0.013, r1: 0.000, sides: 3, uBase: 0)
    addCylinder( 0.03, 0.74, -0.16,  0.03, 0.69, -0.16, r0: 0.013, r1: 0.000, sides: 3, uBase: 0)

    // Arms (hanging forward-down, clawed)
    addCylinder(-0.20, 0.50, -0.05,  -0.28, 0.28, 0.06,  r0: 0.068, r1: 0.042, sides: 5, uBase: 0)
    addCylinder( 0.20, 0.50, -0.05,   0.28, 0.28, 0.06,  r0: 0.068, r1: 0.042, sides: 5, uBase: 0)
    // Claw tips at end of each arm — three small claws splayed outward
    for sx in [Float(-1), Float(1)] {
        let baseX: Float = sx * 0.28, baseY: Float = 0.28, baseZ: Float = 0.06
        for j in 0 ..< 3 {
            let off = Float(j - 1) * 0.022
            addCylinder(baseX + off, baseY, baseZ,
                        baseX + off + sx * 0.04, baseY - 0.06, baseZ + 0.06,
                        r0: 0.012, r1: 0.000, sides: 3, uBase: 0)
        }
    }

    // Legs (short, tucked under body)
    addCylinder(-0.10, 0.28, 0,  -0.11, 0.02, 0.06,  r0: 0.065, r1: 0.048, sides: 5, uBase: 0)
    addCylinder( 0.10, 0.28, 0,   0.11, 0.02, 0.06,  r0: 0.065, r1: 0.048, sides: 5, uBase: 0)

    // Tail
    addCylinder(0, 0.36, 0.10,  0, 0.14, 0.32,  r0: 0.046, r1: 0.016, sides: 4, uBase: 0)

    // Spine ridges — small spheres along the back, suggesting a stone backbone
    addSphere(0, 0.62, 0.10, 0.024, slices: 4, rings: 3, uBase: 0)
    addSphere(0, 0.55, 0.13, 0.022, slices: 4, rings: 3, uBase: 0)
    addSphere(0, 0.48, 0.16, 0.020, slices: 4, rings: 3, uBase: 0)
    addSphere(0, 0.41, 0.19, 0.018, slices: 4, rings: 3, uBase: 0)

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
