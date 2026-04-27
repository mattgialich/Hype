// GameViewController.swift
// Thin Swift shell — owns MTKView, Metal device, and calls into Zig each frame.
// Zig is linked as a static library via Xcode (libmach5game.a).
// Bridging header: mach5game-Bridging-Header.h declares the C symbols.

import UIKit
import MetalKit
import simd

// ── Enemy name table — keep in sync with name_idx in enemy_config.zig ────────
// Index 0 = Gargoyle.  Append here when adding new enemy types.
private let kEnemyNames: [String] = ["Gargoyle"]

// ── Floating enemy name labels overlay ───────────────────────────────────────
private class EnemyLabelOverlay: UIView {
    struct Entry {
        var worldX: Float; var worldY: Float; var worldZ: Float
        var level: UInt8;  var nameIdx: UInt8
    }
    var entries:     [Entry] = []
    var vpMatrix:    [Float] = Array(repeating: 0, count: 16)
    var playerLevel: UInt8  = 1

    required init?(coder: NSCoder) { fatalError() }
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor          = .clear
        isUserInteractionEnabled = false
    }

    // Project a world-space point to view-space using the VP matrix (column-major).
    private func project(_ wx: Float, _ wy: Float, _ wz: Float) -> CGPoint? {
        let v = vpMatrix
        let cx = v[0]*wx + v[4]*wy + v[8]*wz  + v[12]
        let cy = v[1]*wx + v[5]*wy + v[9]*wz  + v[13]
        let cw = v[3]*wx + v[7]*wy + v[11]*wz + v[15]
        guard cw > 0.001 else { return nil }
        let nx = cx / cw;  let ny = cy / cw
        guard nx > -1.3 && nx < 1.3 && ny > -1.3 && ny < 1.3 else { return nil }
        return CGPoint(x: CGFloat((nx + 1) * 0.5) * bounds.width,
                       y: CGFloat((1 - ny) * 0.5) * bounds.height)
    }

    override func draw(_ rect: CGRect) {
        let font   = UIFont.systemFont(ofSize: 11, weight: .bold)
        let shadow = NSShadow()
        shadow.shadowColor      = UIColor.black
        shadow.shadowBlurRadius = 3
        shadow.shadowOffset     = .zero
        for e in entries {
            guard let pt = project(e.worldX, e.worldY, e.worldZ) else { continue }
            let name  = e.nameIdx < kEnemyNames.count ? kEnemyNames[Int(e.nameIdx)] : "???"
            let color: UIColor
            if      e.level < playerLevel  { color = .white }
            else if e.level == playerLevel { color = UIColor(red: 1.0, green: 0.88, blue: 0.0, alpha: 1) }
            else                           { color = UIColor(red: 1.0, green: 0.18, blue: 0.08, alpha: 1) }
            let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: color, .font: font, .shadow: shadow]
            let str  = name as NSString
            let size = str.size(withAttributes: attrs)
            str.draw(at: CGPoint(x: pt.x - size.width / 2, y: pt.y - size.height / 2),
                     withAttributes: attrs)
        }
    }
}

// ── 10-segment XP bar ────────────────────────────────────────────────────────
private class XPBarView: UIView {
    private let segments: [UIView] = (0..<10).map { _ in UIView() }

    required init?(coder: NSCoder) { fatalError() }
    override init(frame: CGRect) {
        super.init(frame: frame)
        for seg in segments {
            seg.layer.borderWidth = 1
            seg.layer.borderColor = UIColor(white: 1, alpha: 0.25).cgColor
            seg.backgroundColor   = UIColor(white: 0, alpha: 0.40)
            addSubview(seg)
        }
        isUserInteractionEnabled = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let segW = bounds.width / CGFloat(segments.count)
        for (i, seg) in segments.enumerated() {
            seg.frame = CGRect(x: CGFloat(i) * segW, y: 0, width: segW, height: bounds.height)
        }
    }

    func update(frac: Float) {
        let filled = min(10, Int(frac * 10))
        for (i, seg) in segments.enumerated() {
            seg.backgroundColor = i < filled
                ? UIColor(red: 1.0, green: 0.82, blue: 0.0, alpha: 0.90)
                : UIColor(white: 0, alpha: 0.40)
        }
    }
}

// ── Split stat bar: red HP (left→centre) + blue mana (right→centre) ─────────
// HP fills from the left edge toward the centre; mana from the right edge.
private class StatBarView: UIView {

    private let hpFill   = CAGradientLayer()   // red, anchored left
    private let mpFill   = CAGradientLayer()   // blue, anchored right
    private let divider  = UIView()            // thin white line at midpoint
    private let hpLabel  = UILabel()
    private let mpLabel  = UILabel()

    private var hpFrac: CGFloat = 1.0
    private var mpFrac: CGFloat = 1.0

    required init?(coder: NSCoder) { fatalError() }
    override init(frame: CGRect) {
        super.init(frame: frame)

        layer.masksToBounds = true
        backgroundColor = UIColor(white: 0, alpha: 0.50)
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.20).cgColor

        // HP: bright red at the outer (left) edge, darker toward centre
        hpFill.colors     = [UIColor(red: 0.85, green: 0.10, blue: 0.06, alpha: 1).cgColor,
                               UIColor(red: 0.45, green: 0.04, blue: 0.03, alpha: 1).cgColor]
        hpFill.startPoint = CGPoint(x: 0, y: 0.5)
        hpFill.endPoint   = CGPoint(x: 1, y: 0.5)
        layer.addSublayer(hpFill)

        // Mana: darker at centre (left edge of fill), bright blue at the outer (right) edge
        mpFill.colors     = [UIColor(red: 0.04, green: 0.10, blue: 0.50, alpha: 1).cgColor,
                               UIColor(red: 0.18, green: 0.48, blue: 0.92, alpha: 1).cgColor]
        mpFill.startPoint = CGPoint(x: 0, y: 0.5)
        mpFill.endPoint   = CGPoint(x: 1, y: 0.5)
        layer.addSublayer(mpFill)

        divider.backgroundColor = UIColor.white.withAlphaComponent(0.35)
        addSubview(divider)

        for lbl in [hpLabel, mpLabel] {
            lbl.textColor     = .white
            lbl.font          = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
            lbl.textAlignment = .center
            lbl.layer.shadowColor   = UIColor.black.cgColor
            lbl.layer.shadowRadius  = 2
            lbl.layer.shadowOpacity = 1.0
            lbl.layer.shadowOffset  = .zero
            addSubview(lbl)
        }

        isUserInteractionEnabled = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
        let half = bounds.width / 2
        divider.frame  = CGRect(x: half - 1, y: 0, width: 2, height: bounds.height)
        hpLabel.frame  = CGRect(x: 0,    y: 0, width: half, height: bounds.height)
        mpLabel.frame  = CGRect(x: half, y: 0, width: half, height: bounds.height)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        applyFills()
        CATransaction.commit()
    }

    private func applyFills() {
        let half = bounds.width / 2
        // HP: grows from x=0 rightward
        hpFill.frame = CGRect(x: 0, y: 0, width: half * hpFrac, height: bounds.height)
        // Mana: grows from x=width leftward (anchored to right edge)
        let mw = half * mpFrac
        mpFill.frame = CGRect(x: bounds.width - mw, y: 0, width: mw, height: bounds.height)
    }

    func update(hp: Float, hpMax: Float, mp: Float, mpMax: Float) {
        let newHp = hpMax > 0 ? CGFloat(hp / hpMax) : 0
        let newMp = mpMax > 0 ? CGFloat(mp / mpMax) : 0
        let chHp  = abs(newHp - hpFrac) > 0.002
        let chMp  = abs(newMp - mpFrac) > 0.002
        if chHp || chMp {
            hpFrac = max(0, min(1, newHp))
            mpFrac = max(0, min(1, newMp))
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.10)
            applyFills()
            CATransaction.commit()
        }
        hpLabel.text = "\(Int(hp)) HP"
        mpLabel.text = "\(Int(mp)) MP"
    }
}

// Particle + draw buffer sizes — must match Zig constants
let kMaxDrawCalls   = 4096
let kMaxEmitters    = 256
let kDrawCallStride = 88    // sizeof(DrawCall) in Zig
let kEmitterStride  = 104   // sizeof(GpuEmitter) in Zig
let kUniformStride  = 160   // sizeof(FrameUniforms) in Zig

@MainActor
class GameViewController: UIViewController, MTKViewDelegate {

    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var mtkView: MTKView!

    // Pipelines
    var worldPipeline:     MTLRenderPipelineState!
    var particlePipeline:  MTLRenderPipelineState!
    var compositePipeline: MTLRenderPipelineState!
    var forwardPipeline:   MTLRenderPipelineState!
    var bloomPipeline:     MTLRenderPipelineState!
    var simulateKernel:    MTLComputePipelineState!
    var depthStencilState: MTLDepthStencilState!
    var linearClampSampler: MTLSamplerState!

    // Persistent GPU buffers
    var uniformBuf:   MTLBuffer!
    var drawCallBuf:  MTLBuffer!
    var emitterBuf:   MTLBuffer!
    var particleBuf:  MTLBuffer!  // 64k particles × stride

    // Ground and capsule geometry
    var groundVBuf:       MTLBuffer!
    var groundIBuf:       MTLBuffer!
    var groundIndexCount: Int = 0
    var capsuleVBuf:      MTLBuffer!
    var capsuleIBuf:      MTLBuffer!
    var capsuleIndexCount: Int = 0
    var groundDrawCallBuf: MTLBuffer!  // 88-byte identity DrawCall for the ground
    var treeVBuf:          MTLBuffer!
    var treeIBuf:          MTLBuffer!
    var treeIndexCount:    Int = 0
    var forestTreeVBuf:    MTLBuffer!
    var forestTreeIBuf:    MTLBuffer!
    var forestTreeIndexCount: Int = 0
    var rockVBuf:          MTLBuffer!
    var rockIBuf:          MTLBuffer!
    var rockIndexCount:    Int = 0
    var flowerVBuf:        MTLBuffer!
    var flowerIBuf:        MTLBuffer!
    var flowerIndexCount:  Int = 0
    var heroVBuf:          MTLBuffer!
    var heroIBuf:          MTLBuffer!
    var heroIndexCount:    Int = 0
    var lightningVBuf:     MTLBuffer!
    var lightningIBuf:     MTLBuffer!
    var lightningIndexCount: Int = 0
    var gargoyleVBuf:      MTLBuffer!
    var gargoyleIBuf:      MTLBuffer!
    var gargoyleIndexCount: Int = 0
    var towerVBuf:         MTLBuffer!
    var towerIBuf:         MTLBuffer!
    var towerIndexCount:   Int = 0
    var torchVBuf:         MTLBuffer!
    var torchIBuf:         MTLBuffer!
    var torchIndexCount:   Int = 0
    var portalVBuf:        MTLBuffer!
    var portalIBuf:        MTLBuffer!
    var portalIndexCount:  Int = 0
    var monolithVBuf:      MTLBuffer!
    var monolithIBuf:      MTLBuffer!
    var monolithIndexCount: Int = 0
    var stoneCircleVBuf:   MTLBuffer!
    var stoneCircleIBuf:   MTLBuffer!
    var stoneCircleIndexCount: Int = 0
    var fallenLogVBuf:     MTLBuffer!
    var fallenLogIBuf:     MTLBuffer!
    var fallenLogIndexCount: Int = 0
    var treeStumpVBuf:     MTLBuffer!
    var treeStumpIBuf:     MTLBuffer!
    var treeStumpIndexCount: Int = 0
    var crystalVBuf:       MTLBuffer!
    var crystalIBuf:       MTLBuffer!
    var crystalIndexCount: Int = 0
    var bonfireVBuf:       MTLBuffer!
    var bonfireIBuf:       MTLBuffer!
    var bonfireIndexCount: Int = 0
    var deadTreeVBuf:      MTLBuffer!
    var deadTreeIBuf:      MTLBuffer!
    var deadTreeIndexCount: Int = 0
    var giantMushroomVBuf: MTLBuffer!
    var giantMushroomIBuf: MTLBuffer!
    var giantMushroomIndexCount: Int = 0
    var bannerVBuf:        MTLBuffer!
    var bannerIBuf:        MTLBuffer!
    var bannerIndexCount:  Int = 0
    var berryBushVBuf:     MTLBuffer!
    var berryBushIBuf:     MTLBuffer!
    var berryBushIndexCount: Int = 0
    var shrineVBuf:        MTLBuffer!
    var shrineIBuf:        MTLBuffer!
    var shrineIndexCount:  Int = 0

    // Skill button
    var skillButton: UIButton!

    // HUD stat bar + XP bar + enemy labels + level display
    private var statBar:      StatBarView!
    private var xpBar:        XPBarView!
    private var labelOverlay: EnemyLabelOverlay!
    private var levelLabel:   UILabel!
    private var labelStagingBuf: [UInt8]

    // GBuffer textures (recreated on resize)
    var albedoTex:   MTLTexture?
    var normalTex:   MTLTexture?
    var emissiveTex: MTLTexture?
    var hdrTex:      MTLTexture?
    var bloomTex:    MTLTexture?
    var depthTex:    MTLTexture?

    // CPU-side staging buffers for Zig output
    var drawStagingBuf: [UInt8]
    var emitterCount:   UInt32 = 0

    // Joystick
    let joystickRadius: CGFloat = 70
    let knobRadius:     CGFloat = 32
    var joystickBase:   UIView!
    var joystickKnob:   UIView!
    var joystickCenter: CGPoint = .zero
    var joystickTouch:  UITouch?

    override init(nibName: String?, bundle: Bundle?) {
        drawStagingBuf  = [UInt8](repeating: 0, count: kMaxDrawCalls * kDrawCallStride)
        labelStagingBuf = [UInt8](repeating: 0, count: 256 * 16)
        super.init(nibName: nibName, bundle: bundle)
    }

    required init?(coder: NSCoder) {
        drawStagingBuf  = [UInt8](repeating: 0, count: kMaxDrawCalls * kDrawCallStride)
        labelStagingBuf = [UInt8](repeating: 0, count: 256 * 16)
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        device       = MTLCreateSystemDefaultDevice()!
        commandQueue = device.makeCommandQueue()!
        mtkView      = MTKView(frame: view.bounds, device: device)
        mtkView.delegate         = self
        mtkView.preferredFramesPerSecond = 60
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.depthStencilPixelFormat  = .depth32Float
        mtkView.clearColor       = MTLClearColor(red: 0.03, green: 0.03, blue: 0.05, alpha: 1)
        view.insertSubview(mtkView, at: 0)

        buildPipelines()
        buildBuffers()
        buildGBuffer(size: mtkView.drawableSize)
        setupJoystick()
        setupSkillButton()
        setupStatBar()

        // Init Zig game state
        game_init()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        mtkView.frame = view.bounds
        let safe = view.safeAreaInsets.bottom
        let r    = joystickRadius

        // Joystick: absolute left corner, higher up
        let joyX: CGFloat = 10
        let joyY = view.bounds.height - safe - 26 - r * 2
        joystickBase.frame = CGRect(x: joyX, y: joyY, width: r * 2, height: r * 2)
        joystickCenter     = CGPoint(x: joyX + r, y: joyY + r)
        resetKnob()

        // Skill button: absolute right corner, same vertical band as joystick
        let btn: CGFloat = 64
        skillButton.frame = CGRect(x: view.bounds.width - 10 - btn,
                                   y: view.bounds.height - safe - 26 - btn,
                                   width: btn, height: btn)
        skillButton.layer.cornerRadius = btn / 2

        // Stat + XP bars — centred, 65% of screen width, pinned to bottom
        let barW  = view.bounds.width * 0.65
        let barX  = (view.bounds.width - barW) / 2
        let barH: CGFloat  = 14
        let xpH:  CGFloat  = 10
        let statY = view.bounds.height - safe - barH - 6
        let xpY   = statY - xpH - 4
        statBar.frame = CGRect(x: barX, y: statY, width: barW, height: barH)
        xpBar.frame   = CGRect(x: barX, y: xpY,   width: barW, height: xpH)

        // Enemy label overlay — full screen so world-projected positions land correctly
        labelOverlay.frame = view.bounds

        // Level label — top-left corner
        let topSafe = view.safeAreaInsets.top
        levelLabel.frame = CGRect(x: 16, y: topSafe + 8, width: 80, height: 24)
    }

    // ── MTKViewDelegate ──────────────────────────────────────────────────────

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        buildGBuffer(size: size)
    }

    func draw(in view: MTKView) {
        guard let drawable  = view.currentDrawable,
              let desc      = view.currentRenderPassDescriptor,
              let cmdBuf    = commandQueue.makeCommandBuffer()
        else { return }

        let dt: Float = 1.0 / Float(view.preferredFramesPerSecond)
        let w  = Float(view.drawableSize.width)
        let h  = Float(view.drawableSize.height)

        // 1. Tick game
        game_update(dt)

        // Update stat + XP bars + level label
        var hp: Float = 0, hpMax: Float = 0, mp: Float = 0, mpMax: Float = 0, xpFrac: Float = 0
        game_get_player_stats(&hp, &hpMax, &mp, &mpMax, &xpFrac)
        statBar.update(hp: hp, hpMax: hpMax, mp: mp, mpMax: mpMax)
        xpBar.update(frac: xpFrac)
        let playerLevel = UInt8(min(255, game_get_player_level()))
        levelLabel.text = "Lv. \(playerLevel)"

        // 2. Get uniforms from Zig
        uniformBuf.contents().bindMemory(to: UInt8.self, capacity: kUniformStride)
        game_get_frame_uniforms(w / h, w, h,
            uniformBuf.contents().assumingMemoryBound(to: UInt8.self))

        // 2b. Read VP matrix from uniform buffer (first 16 floats) and refresh enemy labels
        var vp = [Float](repeating: 0, count: 16)
        let ubRaw = uniformBuf.contents()
        for i in 0..<16 { vp[i] = ubRaw.load(fromByteOffset: i * 4, as: Float.self) }

        var labelCount: UInt32 = 0
        labelStagingBuf.withUnsafeMutableBytes { ptr in
            game_get_enemy_labels(ptr.baseAddress!.assumingMemoryBound(to: UInt8.self), &labelCount)
        }
        var parsedEntries: [EnemyLabelOverlay.Entry] = []
        let kLS = 16
        for i in 0..<Int(labelCount) {
            let b = i * kLS
            let wx = labelStagingBuf.withUnsafeBytes { $0.load(fromByteOffset: b,      as: Float.self) }
            let wy = labelStagingBuf.withUnsafeBytes { $0.load(fromByteOffset: b + 4,  as: Float.self) }
            let wz = labelStagingBuf.withUnsafeBytes { $0.load(fromByteOffset: b + 8,  as: Float.self) }
            parsedEntries.append(.init(worldX: wx, worldY: wy, worldZ: wz,
                                       level: labelStagingBuf[b + 12],
                                       nameIdx: labelStagingBuf[b + 13]))
        }
        labelOverlay.entries     = parsedEntries
        labelOverlay.vpMatrix    = vp
        labelOverlay.playerLevel = playerLevel
        labelOverlay.setNeedsDisplay()

        // 3. Get draw calls from Zig — run inside withUnsafeMutableBytes so the
        //    pointer is live for the entire duration of the C call.
        let drawCount = drawStagingBuf.withUnsafeMutableBytes { ptr -> UInt32 in
            game_fill_draws(
                ptr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                UInt32(ptr.count))
        }

        // 4. Get emitter data from Zig and upload
        var emitterCount: UInt32 = 0
        let emPtr = game_get_emitters(&emitterCount)!
        emitterBuf.contents()
            .copyMemory(from: emPtr, byteCount: Int(emitterCount) * kEmitterStride)
        self.emitterCount = emitterCount

        // 4b. Clear emissiveTex to black — it's .private and not written by
        //     the forward path, so GPU memory is undefined. (bloomTex is fully
        //     written by the bloom downsample pass below, so no clear needed.)
        for clearTex in [emissiveTex].compactMap({ $0 }) {
            let d = MTLRenderPassDescriptor()
            d.colorAttachments[0].texture     = clearTex
            d.colorAttachments[0].loadAction  = .clear
            d.colorAttachments[0].clearColor  = MTLClearColor(red:0, green:0, blue:0, alpha:0)
            d.colorAttachments[0].storeAction = .store
            cmdBuf.makeRenderCommandEncoder(descriptor: d)?.endEncoding()
        }

        // 5. Compute: simulate particles
        if let computeEnc = cmdBuf.makeComputeCommandEncoder() {
            computeEnc.setComputePipelineState(simulateKernel)
            computeEnc.setBuffer(particleBuf, offset: 0, index: 0)
            computeEnc.setBuffer(emitterBuf,  offset: 0, index: 1)

            // Use var copies so we can take inout pointers — avoids withUnsafeBytes actor-isolation issues
            var ec  = emitterCount
            var dtt = dt
            computeEnc.setBytes(&ec,  length: MemoryLayout<UInt32>.size, index: 2)
            computeEnc.setBytes(&dtt, length: MemoryLayout<Float>.size,   index: 3)

            // dispatchThreadgroups is universally supported; dispatchThreads requires nonUniformThreadgroups
            let tpw      = max(simulateKernel.threadExecutionWidth, 1)
            let tpg      = MTLSize(width: tpw, height: 1, depth: 1)
            let numGroups = MTLSize(width: (65536 + tpw - 1) / tpw, height: 1, depth: 1)
            computeEnc.dispatchThreadgroups(numGroups, threadsPerThreadgroup: tpg)
            computeEnc.endEncoding()
        }

        // 6. Geometry pass (forward) → hdrTex + depthTex
        if let hdr = hdrTex, let depth = depthTex {
            let geoDesc = MTLRenderPassDescriptor()
            geoDesc.colorAttachments[0].texture     = hdr
            geoDesc.colorAttachments[0].loadAction  = .clear
            geoDesc.colorAttachments[0].clearColor  = MTLClearColor(red:0.02, green:0.08, blue:0.03, alpha:1)
            geoDesc.colorAttachments[0].storeAction = .store
            geoDesc.depthAttachment.texture          = depth
            geoDesc.depthAttachment.loadAction       = .clear
            geoDesc.depthAttachment.clearDepth       = 1.0
            geoDesc.depthAttachment.storeAction      = .dontCare

            if let enc = cmdBuf.makeRenderCommandEncoder(descriptor: geoDesc) {
                enc.setRenderPipelineState(forwardPipeline)
                enc.setDepthStencilState(depthStencilState)
                enc.setVertexBuffer(uniformBuf, offset: 0, index: 0)
                enc.setFragmentBuffer(uniformBuf, offset: 0, index: 0)

                // Ground plane (identity model, no draw call from Zig)
                enc.setVertexBuffer(groundDrawCallBuf, offset: 0, index: 1)
                enc.setVertexBuffer(groundVBuf, offset: 0, index: 2)
                enc.drawIndexedPrimitives(type: .triangle,
                                          indexCount: groundIndexCount,
                                          indexType: .uint16,
                                          indexBuffer: groundIBuf,
                                          indexBufferOffset: 0)

                // Entities — read mesh_id per draw call to select the right mesh
                drawStagingBuf.withUnsafeBytes { ptr in
                    for i in 0 ..< Int(drawCount) {
                        let byteOff = i * kDrawCallStride
                        // mesh_id is UInt16 at byte offset 84 within each DrawCall
                        let meshId = ptr.load(fromByteOffset: byteOff + 84, as: UInt16.self)
                        let (vBuf, iBuf, idxCount): (MTLBuffer, MTLBuffer, Int) = {
                            switch meshId {
                            case 1:  return (heroVBuf,        heroIBuf,        heroIndexCount)
                            case 2:  return (treeVBuf,        treeIBuf,        treeIndexCount)
                            case 3:  return (gargoyleVBuf,    gargoyleIBuf,    gargoyleIndexCount)
                            case 7:  return (lightningVBuf,   lightningIBuf,   lightningIndexCount)
                            case 4:  return (forestTreeVBuf,  forestTreeIBuf,  forestTreeIndexCount)
                            case 5:  return (rockVBuf,        rockIBuf,        rockIndexCount)
                            case 6:  return (flowerVBuf,      flowerIBuf,      flowerIndexCount)
                            case 8:  return (towerVBuf,       towerIBuf,       towerIndexCount)
                            case 9:  return (torchVBuf,       torchIBuf,       torchIndexCount)
                            case 13: return (portalVBuf,      portalIBuf,      portalIndexCount)
                            case 14: return (monolithVBuf,    monolithIBuf,    monolithIndexCount)
                            case 15: return (stoneCircleVBuf, stoneCircleIBuf, stoneCircleIndexCount)
                            case 16: return (fallenLogVBuf,   fallenLogIBuf,   fallenLogIndexCount)
                            case 17: return (treeStumpVBuf,   treeStumpIBuf,   treeStumpIndexCount)
                            case 18: return (crystalVBuf,     crystalIBuf,     crystalIndexCount)
                            case 19: return (bonfireVBuf,     bonfireIBuf,     bonfireIndexCount)
                            case 20: return (deadTreeVBuf,    deadTreeIBuf,    deadTreeIndexCount)
                            case 21: return (giantMushroomVBuf, giantMushroomIBuf, giantMushroomIndexCount)
                            case 22: return (bannerVBuf,      bannerIBuf,      bannerIndexCount)
                            case 23: return (berryBushVBuf,   berryBushIBuf,   berryBushIndexCount)
                            case 24: return (shrineVBuf,      shrineIBuf,      shrineIndexCount)
                            default: return (capsuleVBuf,     capsuleIBuf,     capsuleIndexCount)
                            }
                        }()
                        enc.setVertexBuffer(vBuf, offset: 0, index: 2)
                        enc.setVertexBytes(ptr.baseAddress!.advanced(by: byteOff),
                                           length: kDrawCallStride,
                                           index: 1)
                        enc.drawIndexedPrimitives(type: .triangle,
                                                  indexCount: idxCount,
                                                  indexType: .uint16,
                                                  indexBuffer: iBuf,
                                                  indexBufferOffset: 0)
                    }
                }
                enc.endEncoding()
            }
        }

        // 7. Particle pass → hdrTex (additive blend, loads existing scene)
        if let hdr = hdrTex {
            let partDesc = MTLRenderPassDescriptor()
            partDesc.colorAttachments[0].texture     = hdr
            partDesc.colorAttachments[0].loadAction  = .load
            partDesc.colorAttachments[0].storeAction = .store
            // No depth attachment — particle pipeline has no depth format

            if let enc = cmdBuf.makeRenderCommandEncoder(descriptor: partDesc) {
                enc.setRenderPipelineState(particlePipeline)
                enc.setVertexBuffer(particleBuf, offset: 0, index: 0)
                enc.setVertexBuffer(uniformBuf,  offset: 0, index: 1)
                enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 65536 * 6)
                enc.endEncoding()
            }
        }

        // 8. Bloom downsample pass: hdrTex → bloomTex
        if let hdr = hdrTex, let bloom = bloomTex {
            let bloomDesc = MTLRenderPassDescriptor()
            bloomDesc.colorAttachments[0].texture     = bloom
            bloomDesc.colorAttachments[0].loadAction  = .dontCare    // pass overwrites every pixel
            bloomDesc.colorAttachments[0].storeAction = .store
            if let enc = cmdBuf.makeRenderCommandEncoder(descriptor: bloomDesc) {
                enc.setRenderPipelineState(bloomPipeline)
                enc.setFragmentTexture(hdr, index: 0)
                enc.setFragmentSamplerState(linearClampSampler, index: 0)
                enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                enc.endEncoding()
            }
        }

        // 9. Composite pass → drawable (no depth — post-process fullscreen triangle)
        // Build a fresh descriptor targeting only the drawable color texture.
        // We can't reuse `desc` here because it carries a depth attachment that
        // would conflict with the composite pipeline (which declares no depth format).
        let compositeDesc = MTLRenderPassDescriptor()
        compositeDesc.colorAttachments[0].texture     = drawable.texture
        compositeDesc.colorAttachments[0].loadAction  = .dontCare   // composite overwrites every pixel
        compositeDesc.colorAttachments[0].storeAction = .store

        if let renderEnc = cmdBuf.makeRenderCommandEncoder(descriptor: compositeDesc) {
            renderEnc.setRenderPipelineState(compositePipeline)
            if let hdr = hdrTex      { renderEnc.setFragmentTexture(hdr,        index: 0) }
            if let b   = bloomTex    { renderEnc.setFragmentTexture(b,           index: 1) }
            if let e   = emissiveTex { renderEnc.setFragmentTexture(e,           index: 2) }
            // Fullscreen triangle — 3 vertices, no vertex buffer needed
            renderEnc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            renderEnc.endEncoding()
        }

        cmdBuf.present(drawable)
        cmdBuf.commit()
    }

    // ── Joystick setup ───────────────────────────────────────────────────────

    private func setupJoystick() {
        let r  = joystickRadius
        let kr = knobRadius

        // Outer ring
        joystickBase = UIView(frame: CGRect(x: 0, y: 0, width: r * 2, height: r * 2))
        joystickBase.backgroundColor          = UIColor.white.withAlphaComponent(0.12)
        joystickBase.layer.cornerRadius       = r
        joystickBase.layer.borderWidth        = 2
        joystickBase.layer.borderColor        = UIColor.white.withAlphaComponent(0.35).cgColor
        joystickBase.isUserInteractionEnabled = false
        view.addSubview(joystickBase)

        // Inner knob
        joystickKnob = UIView(frame: CGRect(x: r - kr, y: r - kr, width: kr * 2, height: kr * 2))
        joystickKnob.backgroundColor    = UIColor.white.withAlphaComponent(0.55)
        joystickKnob.layer.cornerRadius = kr
        joystickBase.addSubview(joystickKnob)
    }

    private func resetKnob() {
        let r  = joystickRadius
        let kr = knobRadius
        joystickKnob.frame = CGRect(x: r - kr, y: r - kr, width: kr * 2, height: kr * 2)
    }

    private func updateJoystick(touch: UITouch) {
        let pt  = touch.location(in: view)
        var dx  = pt.x - joystickCenter.x
        var dy  = pt.y - joystickCenter.y
        let mag = (dx * dx + dy * dy).squareRoot()
        if mag > joystickRadius {
            dx = dx / mag * joystickRadius
            dy = dy / mag * joystickRadius
        }
        let r  = joystickRadius
        let kr = knobRadius
        joystickKnob.frame = CGRect(x: r + dx - kr, y: r + dy - kr,
                                    width: kr * 2,  height: kr * 2)
        // dx/r and dy/r are direction components in [-1, 1].
        // UIKit Y+ = down screen = world +Z (toward camera) — matches expectation.
        game_touch_move(Float(dx / r), Float(dy / r), true)
    }

    // ── Touch input ──────────────────────────────────────────────────────────

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches where joystickTouch == nil {
            let pt = touch.location(in: view)
            // Accept any touch in the left half of the screen as the joystick
            if pt.x < view.bounds.width * 0.5 {
                joystickTouch = touch
                updateJoystick(touch: touch)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches where touch === joystickTouch {
            updateJoystick(touch: touch)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches where touch === joystickTouch {
            joystickTouch = nil
            resetKnob()
            game_touch_move(0, 0, false)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    // ── Skill button ─────────────────────────────────────────────────────────

    private func setupSkillButton() {
        skillButton = UIButton(type: .custom)

        // Dark arcane background
        skillButton.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.16, alpha: 0.92)

        // Electric cyan border
        skillButton.layer.borderWidth = 2.5
        skillButton.layer.borderColor = UIColor(red: 0.35, green: 0.80, blue: 1.00, alpha: 0.90).cgColor

        // Outer electric glow
        skillButton.layer.shadowColor   = UIColor(red: 0.30, green: 0.70, blue: 1.00, alpha: 1).cgColor
        skillButton.layer.shadowRadius  = 10
        skillButton.layer.shadowOpacity = 0.75
        skillButton.layer.shadowOffset  = .zero

        skillButton.setTitle("⚡", for: .normal)
        skillButton.titleLabel?.font = UIFont.systemFont(ofSize: 32, weight: .medium)

        skillButton.addTarget(self, action: #selector(lightningSkillTapped), for: .touchUpInside)
        view.addSubview(skillButton)
    }

    private func setupStatBar() {
        statBar = StatBarView()
        view.addSubview(statBar)
        xpBar = XPBarView()
        view.addSubview(xpBar)

        labelOverlay = EnemyLabelOverlay()
        view.addSubview(labelOverlay)

        levelLabel = UILabel()
        levelLabel.text      = "Lv. 1"
        levelLabel.textColor = .white
        levelLabel.font      = UIFont.systemFont(ofSize: 15, weight: .bold)
        levelLabel.layer.shadowColor   = UIColor.black.cgColor
        levelLabel.layer.shadowRadius  = 3
        levelLabel.layer.shadowOpacity = 1.0
        levelLabel.layer.shadowOffset  = .zero
        view.addSubview(levelLabel)
    }

    @objc private func lightningSkillTapped() {
        game_touch_skill(1, 0.0, 0.0)

        // Flash bright then settle back — feels like a discharge
        UIView.animate(withDuration: 0.06) {
            self.skillButton.transform       = CGAffineTransform(scaleX: 0.88, y: 0.88)
            self.skillButton.backgroundColor = UIColor(red: 0.55, green: 0.88, blue: 1.00, alpha: 1.00)
            self.skillButton.layer.shadowOpacity = 1.0
            self.skillButton.layer.shadowRadius  = 22
        } completion: { _ in
            UIView.animate(withDuration: 0.30, delay: 0, options: .curveEaseOut) {
                self.skillButton.transform       = .identity
                self.skillButton.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.16, alpha: 0.92)
                self.skillButton.layer.shadowOpacity = 0.75
                self.skillButton.layer.shadowRadius  = 10
            }
        }
    }

    // ── Setup helpers ────────────────────────────────────────────────────────

    private func buildBuffers() {
        let opts: MTLResourceOptions = [.storageModeShared]
        uniformBuf  = device.makeBuffer(length: kUniformStride,                    options: opts)
        drawCallBuf = device.makeBuffer(length: kMaxDrawCalls * kDrawCallStride,   options: opts)
        emitterBuf  = device.makeBuffer(length: kMaxEmitters  * kEmitterStride,    options: opts)
        // 64k particles × 64 bytes each (matches GpuParticle in particles.zig)
        particleBuf = device.makeBuffer(length: 65536 * 64,                        options: opts)
        buildMeshes()
    }

    private func buildMeshes() {
        let (gv, gi, gc) = makeGround(device: device)
        groundVBuf       = gv
        groundIBuf       = gi
        groundIndexCount = gc

        let (cv, ci, cc) = makeCapsule(device: device)
        capsuleVBuf       = cv
        capsuleIBuf       = ci
        capsuleIndexCount = cc

        let (tv, ti2, tc) = makeTree(device: device)
        treeVBuf       = tv
        treeIBuf       = ti2
        treeIndexCount = tc

        let (fv, fi2, fc) = makeForestTree(device: device)
        forestTreeVBuf       = fv
        forestTreeIBuf       = fi2
        forestTreeIndexCount = fc

        let (rv, ri, rc) = makeRock(device: device)
        rockVBuf       = rv
        rockIBuf       = ri
        rockIndexCount = rc

        let (flv, fli, flc) = makeFlower(device: device)
        flowerVBuf       = flv
        flowerIBuf       = fli
        flowerIndexCount = flc

        let (hv, hi, hc) = makeHero(device: device)
        heroVBuf       = hv
        heroIBuf       = hi
        heroIndexCount = hc

        let (lv, li, lc) = makeLightning(device: device)
        lightningVBuf       = lv
        lightningIBuf       = li
        lightningIndexCount = lc

        let (gargv, gargi, gargc) = makeGargoyle(device: device)
        gargoyleVBuf       = gargv
        gargoyleIBuf       = gargi
        gargoyleIndexCount = gargc

        let (twv, twi, twc) = makeTower(device: device)
        towerVBuf       = twv
        towerIBuf       = twi
        towerIndexCount = twc

        let (tcv, tci, tcc) = makeTorch(device: device)
        torchVBuf       = tcv
        torchIBuf       = tci
        torchIndexCount = tcc

        let (pv, pi, pc) = makePortal(device: device)
        portalVBuf       = pv
        portalIBuf       = pi
        portalIndexCount = pc

        let (mv, mi, mc) = makeMonolith(device: device)
        monolithVBuf       = mv
        monolithIBuf       = mi
        monolithIndexCount = mc

        // ── 10 new asset meshes ─────────────────────────────────────────
        let (scv, sci, scc) = makeStoneCircle(device: device)
        stoneCircleVBuf = scv;  stoneCircleIBuf = sci;  stoneCircleIndexCount = scc
        let (logv, logi, logc) = makeFallenLog(device: device)
        fallenLogVBuf = logv;   fallenLogIBuf = logi;   fallenLogIndexCount = logc
        let (tsv, tsi, tsc) = makeTreeStump(device: device)
        treeStumpVBuf = tsv;    treeStumpIBuf = tsi;    treeStumpIndexCount = tsc
        let (crv, cri, crc) = makeCrystalCluster(device: device)
        crystalVBuf = crv;      crystalIBuf = cri;      crystalIndexCount = crc
        let (bfv, bfi, bfc) = makeBonfire(device: device)
        bonfireVBuf = bfv;      bonfireIBuf = bfi;      bonfireIndexCount = bfc
        let (dtv, dti, dtc) = makeDeadTree(device: device)
        deadTreeVBuf = dtv;     deadTreeIBuf = dti;     deadTreeIndexCount = dtc
        let (gmv, gmi, gmc) = makeGiantMushroom(device: device)
        giantMushroomVBuf = gmv; giantMushroomIBuf = gmi; giantMushroomIndexCount = gmc
        let (bnv, bni, bnc) = makeBannerPole(device: device)
        bannerVBuf = bnv;       bannerIBuf = bni;       bannerIndexCount = bnc
        let (bbv, bbi, bbc) = makeBerryBush(device: device)
        berryBushVBuf = bbv;    berryBushIBuf = bbi;    berryBushIndexCount = bbc
        let (shv, shi, shc) = makeShrine(device: device)
        shrineVBuf = shv;       shrineIBuf = shi;       shrineIndexCount = shc

        // 88-byte DrawCall for the ground: identity model + earthy dark color
        // Layout: float4x4 model (64B) | float4 color (16B) | uint fx_flags (4B) | ushort mesh_id (2B) | uchar2 pad (2B)
        var dc = [Float32](repeating: 0, count: kDrawCallStride / MemoryLayout<Float32>.size)
        // Identity matrix (column-major, diagonal = 1)
        dc[0]  = 1;  dc[5]  = 1;  dc[10] = 1;  dc[15] = 1
        // Ground color: dark forest moss
        dc[16] = 0.05;  dc[17] = 0.20;  dc[18] = 0.06;  dc[19] = 1.0
        // fx_flags, mesh_id, pad — already zero ✓
        groundDrawCallBuf = device.makeBuffer(bytes: dc,
                                              length: kDrawCallStride,
                                              options: .storageModeShared)!
    }

    private func buildGBuffer(size: CGSize) {
        // Clamp to at least 1×1 so textures are always valid (real size set on drawableSizeWillChange)
        let w = max(Int(size.width),  1)
        let h = max(Int(size.height), 1)
        func makeTex(_ fmt: MTLPixelFormat, _ usage: MTLTextureUsage) -> MTLTexture {
            let d = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: fmt,
                width:  w,
                height: h,
                mipmapped: false)
            d.usage       = usage
            d.storageMode = .private
            return device.makeTexture(descriptor: d)!
        }
        let rw: MTLTextureUsage = [.renderTarget, .shaderRead]
        albedoTex   = makeTex(.rgba16Float, rw)
        normalTex   = makeTex(.rgba16Float, rw)
        emissiveTex = makeTex(.rgba16Float, rw)
        hdrTex      = makeTex(.rgba16Float, rw)
        bloomTex    = makeTex(.rgba16Float, rw)
        depthTex    = makeTex(.depth32Float, [.renderTarget])
    }

    private func buildPipelines() {
        guard let lib = device.makeDefaultLibrary() else {
            fatalError("Metal library not found — add .metal files to Xcode target")
        }

        do {
            // ── Vertex descriptor for world geometry ──────────────────────────
            // Matches VertIn in world.metal: pos(float3) normal(float3) uv(float2)
            // Interleaved layout: 32 bytes per vertex
            let vd = MTLVertexDescriptor()
            vd.attributes[0].format      = .float3  // pos
            vd.attributes[0].offset      = 0
            vd.attributes[0].bufferIndex = 2        // slot 2: vertex data (0=uniforms, 1=drawCall)
            vd.attributes[1].format      = .float3  // normal
            vd.attributes[1].offset      = 12
            vd.attributes[1].bufferIndex = 2
            vd.attributes[2].format      = .float2  // uv
            vd.attributes[2].offset      = 24
            vd.attributes[2].bufferIndex = 2
            vd.layouts[2].stride         = 32

            // ── World pipeline (GBuffer MRT) ──────────────────────────────────
            let wd = MTLRenderPipelineDescriptor()
            wd.label                           = "World"
            wd.vertexFunction                  = lib.makeFunction(name: "vert_world")
            wd.fragmentFunction                = lib.makeFunction(name: "frag_world")
            wd.vertexDescriptor                = vd
            wd.colorAttachments[0].pixelFormat = .rgba16Float // albedo + roughness
            wd.colorAttachments[1].pixelFormat = .rgba16Float // normal + metallic
            wd.colorAttachments[2].pixelFormat = .rgba16Float // emissive
            wd.depthAttachmentPixelFormat      = .depth32Float
            worldPipeline = try device.makeRenderPipelineState(descriptor: wd)

            // ── Forward pipeline (geometry → hdrTex, single rgba16Float) ──────
            let fd = MTLRenderPipelineDescriptor()
            fd.label                           = "Forward"
            fd.vertexFunction                  = lib.makeFunction(name: "vert_world")
            fd.fragmentFunction                = lib.makeFunction(name: "frag_world_forward")
            fd.vertexDescriptor                = vd
            fd.colorAttachments[0].pixelFormat = .rgba16Float
            fd.depthAttachmentPixelFormat      = .depth32Float
            forwardPipeline = try device.makeRenderPipelineState(descriptor: fd)

            // ── Particle pipeline (additive billboard into HDR) ───────────────
            let pd = MTLRenderPipelineDescriptor()
            pd.label                = "Particles"
            pd.vertexFunction       = lib.makeFunction(name: "vert_particle")
            pd.fragmentFunction     = lib.makeFunction(name: "frag_particle")
            let pa                  = pd.colorAttachments[0]!
            pa.pixelFormat                    = .rgba16Float
            pa.isBlendingEnabled              = true
            pa.rgbBlendOperation              = .add
            pa.alphaBlendOperation            = .add
            pa.sourceRGBBlendFactor           = .one
            pa.sourceAlphaBlendFactor         = .one
            pa.destinationRGBBlendFactor      = .one
            pa.destinationAlphaBlendFactor    = .one
            particlePipeline = try device.makeRenderPipelineState(descriptor: pd)

            // ── Composite pipeline (fullscreen post-process → swapchain) ──────
            let cd = MTLRenderPipelineDescriptor()
            cd.label                           = "Composite"
            cd.vertexFunction                  = lib.makeFunction(name: "vert_fullscreen")
            cd.fragmentFunction                = lib.makeFunction(name: "frag_composite")
            cd.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
            compositePipeline = try device.makeRenderPipelineState(descriptor: cd)

            // ── Bloom downsample pipeline (fullscreen pass: hdrTex → bloomTex) ──
            let bd = MTLRenderPipelineDescriptor()
            bd.label                           = "BloomDownsample"
            bd.vertexFunction                  = lib.makeFunction(name: "vert_fullscreen")
            bd.fragmentFunction                = lib.makeFunction(name: "frag_bloom_downsample")
            bd.colorAttachments[0].pixelFormat = .rgba16Float    // matches bloomTex format
            bloomPipeline = try device.makeRenderPipelineState(descriptor: bd)

            // ── Linear-clamp sampler (used by frag_bloom_downsample) ──────────
            let sd = MTLSamplerDescriptor()
            sd.minFilter    = .linear
            sd.magFilter    = .linear
            sd.sAddressMode = .clampToEdge
            sd.tAddressMode = .clampToEdge
            linearClampSampler = device.makeSamplerState(descriptor: sd)!

            // ── Compute: GPU particle simulation ──────────────────────────────
            guard let simFn = lib.makeFunction(name: "simulate_particles") else {
                fatalError("Metal: 'simulate_particles' kernel not found in library")
            }
            simulateKernel = try device.makeComputePipelineState(function: simFn)

            // ── Depth stencil state (geometry pass: depth test + write) ────────
            let dsd = MTLDepthStencilDescriptor()
            dsd.depthCompareFunction = .less
            dsd.isDepthWriteEnabled  = true
            depthStencilState = device.makeDepthStencilState(descriptor: dsd)!

        } catch {
            fatalError("Metal pipeline build failed: \(error.localizedDescription)")
        }
    }
}
