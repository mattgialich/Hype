// GameViewController.swift
// Thin Swift shell — owns MTKView, Metal device, and calls into Zig each frame.
// Zig is linked as a static library via Xcode (libmach5game.a).
// Bridging header: mach5game-Bridging-Header.h declares the C symbols.

import UIKit
import MetalKit
import simd

// ── Enemy name table — keep in sync with name_idx in enemy_config.zig ────────
// Index 0 = Gargoyle.  Append here when adding new enemy types.
private let kEnemyNames: [String] = ["Gargoyle", "Forest Wisp", "Tree Ent", "Skeleton Knight"]

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


// ── Map tab — list of zones the player can travel to from anywhere.
// Triggers onTravel(zoneId, name) which the menu owner wires to game_set_zone
// + dismiss. Mirrors PortalMapView's zone roster but presented as a tappable
// list so the player isn't forced to walk to the gate to switch realms.
private final class MapPanelView: UIView {
    var onTravel: ((Int, String) -> Void)?

    private struct Zone { let id: Int; let name: String; let blurb: String; let tint: UIColor }
    private let zones: [Zone] = [
        .init(id: 0, name: "Whispering Forest",
              blurb: "Mossy paths, ancient monoliths, and gargoyles.",
              tint: UIColor(red: 0.20, green: 0.55, blue: 0.30, alpha: 1)),
        .init(id: 1, name: "Sunburnt Wastes",
              blurb: "Cracked dunes ringed by bone obelisks.",
              tint: UIColor(red: 0.78, green: 0.55, blue: 0.20, alpha: 1)),
        .init(id: 2, name: "Drifting Isles",
              blurb: "Six islands chained by bridges over open sea.",
              tint: UIColor(red: 0.30, green: 0.55, blue: 0.85, alpha: 1)),
    ]
    private var rows: [UIButton] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        let hdr = UILabel()
        hdr.text = "Choose a Realm"
        hdr.font = .systemFont(ofSize: 18, weight: .heavy)
        hdr.textColor = .white
        hdr.textAlignment = .center
        hdr.tag = 8888
        addSubview(hdr)

        for z in zones {
            let btn = UIButton(type: .custom)
            btn.tag = z.id
            btn.contentHorizontalAlignment = .left
            btn.contentEdgeInsets = UIEdgeInsets(top: 12, left: 18, bottom: 12, right: 18)
            btn.backgroundColor = UIColor(white: 0.08, alpha: 1)
            btn.layer.cornerRadius = 12
            btn.layer.borderWidth  = 2
            btn.layer.borderColor  = z.tint.withAlphaComponent(0.55).cgColor

            let title = NSMutableAttributedString(
                string: z.name + "\n",
                attributes: [.font: UIFont.systemFont(ofSize: 18, weight: .heavy),
                             .foregroundColor: UIColor.white])
            title.append(NSAttributedString(
                string: z.blurb,
                attributes: [.font: UIFont.systemFont(ofSize: 13, weight: .regular),
                             .foregroundColor: UIColor(white: 0.75, alpha: 1)]))
            btn.titleLabel?.numberOfLines = 0
            btn.setAttributedTitle(title, for: .normal)
            // addTarget+selector instead of UIAction — fewer Swift-version
            // surprises if the build's Swift mode is off, and trivially easy
            // to verify with a debugger.
            btn.addTarget(self, action: #selector(zoneRowTapped(_:)), for: .touchUpInside)
            addSubview(btn)
            rows.append(btn)
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func zoneRowTapped(_ sender: UIButton) {
        let zoneId = sender.tag
        guard zoneId >= 0 && zoneId < zones.count else { return }
        let z = zones[zoneId]
        NSLog("[zone] MapPanelView row tapped id=\(z.id) name=\(z.name)")
        // Flash the row green for 0.25s — unmistakable visual confirmation
        // that the tap reached the closure, independent of game_set_zone or
        // the MTKView clear colour.
        let oldBg = sender.backgroundColor
        sender.backgroundColor = UIColor(red: 0.18, green: 0.78, blue: 0.32, alpha: 1)
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
            sender.backgroundColor = oldBg
        } completion: { [weak self] _ in
            self?.onTravel?(z.id, z.name)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let pad: CGFloat = 18
        let hdrH: CGFloat = 26
        if let hdr = viewWithTag(8888) {
            hdr.frame = CGRect(x: 0, y: pad, width: bounds.width, height: hdrH)
        }
        let rowH: CGFloat = 78
        let gap:  CGFloat = 12
        let topY = pad + hdrH + 14
        for (i, btn) in rows.enumerated() {
            btn.frame = CGRect(x: pad,
                                y: topY + CGFloat(i) * (rowH + gap),
                                width: bounds.width - pad * 2,
                                height: rowH)
        }
    }
}

// ── Inventory grid (placeholder slots for now) ──────────────────────────────
private final class InventoryView: UIView {
    private let cols = 5
    private let rows = 6
    private var slots: [UIView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        for _ in 0 ..< cols * rows {
            let s = UIView()
            s.backgroundColor   = UIColor(white: 0.10, alpha: 0.85)
            s.layer.cornerRadius = 8
            s.layer.borderWidth  = 1
            s.layer.borderColor  = UIColor.white.withAlphaComponent(0.18).cgColor
            slots.append(s)
            addSubview(s)
        }
        // Placeholder hint label
        let hint = UILabel()
        hint.text = "Inventory slots (placeholder)"
        hint.font = .systemFont(ofSize: 13, weight: .regular)
        hint.textColor = UIColor(white: 0.55, alpha: 1)
        hint.textAlignment = .center
        hint.tag = 7777
        addSubview(hint)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let pad: CGFloat = 14
        let hintH: CGFloat = 22
        let gridW = bounds.width - pad * 2
        let gridH = bounds.height - pad * 2 - hintH
        let cellW = (gridW - CGFloat(cols - 1) * 8) / CGFloat(cols)
        let cellH = (gridH - CGFloat(rows - 1) * 8) / CGFloat(rows)
        let cell  = min(cellW, cellH)
        let actualW = CGFloat(cols) * cell + CGFloat(cols - 1) * 8
        let actualH = CGFloat(rows) * cell + CGFloat(rows - 1) * 8
        let originX = (bounds.width - actualW) / 2
        let originY = pad
        for (i, s) in slots.enumerated() {
            let r = i / cols, c = i % cols
            s.frame = CGRect(x: originX + CGFloat(c) * (cell + 8),
                             y: originY + CGFloat(r) * (cell + 8),
                             width: cell, height: cell)
        }
        if let hint = viewWithTag(7777) {
            hint.frame = CGRect(x: 0, y: originY + actualH + 6, width: bounds.width, height: hintH)
        }
    }
}

// ── Skill bonuses — 64-byte byte-exact mirror of Zig's SkillBonuses struct.
// Layout MUST match src/game/skill_bonuses.zig in field order.
private struct SkillBonuses {
    var damage_flat:      Float = 0
    var damage_pct:       Float = 0
    var spell_damage_pct: Float = 0
    var cast_speed_pct:   Float = 0
    var crit_chance_pct:  Float = 0
    var crit_damage_pct:  Float = 0
    var hp_flat:          Float = 0
    var hp_pct:           Float = 0
    var armour_pct:       Float = 0
    var dmg_reduce_pct:   Float = 0
    var move_speed_pct:   Float = 0
    var mana_flat:        Float = 0
    var mana_pct:         Float = 0
    var mana_regen_pct:   Float = 0
    var cooldown_pct:     Float = 0
    var xp_gain_pct:      Float = 0

    // Map a single allocated node's display text to stat increments.
    // Keystones are matched by their flavor name; all other nodes are
    // exact-string matched to keep parsing robust against future text changes.
    mutating func add(nodeText: String) {
        let key = nodeText.replacingOccurrences(of: "\n", with: " ")
        switch key {
        // Offence — flat
        case "+5 Damage":         damage_flat += 5
        case "+10 Damage":        damage_flat += 10
        // Offence — percent
        case "+15% Damage":       damage_pct += 0.15
        case "+20% Damage":       damage_pct += 0.20
        case "+25% Spell Damage": spell_damage_pct += 0.25
        case "+10% Cast Speed":   cast_speed_pct += 0.10
        case "+15% Crit Chance":  crit_chance_pct += 0.15
        case "+25% Crit Damage":  crit_damage_pct += 0.25
        // Defence
        case "+30 HP":            hp_flat += 30
        case "+50 HP":            hp_flat += 50
        case "+10% HP":           hp_pct += 0.10
        case "+15% Armour":       armour_pct += 0.15
        case "+8% Dmg Reduce":    dmg_reduce_pct += 0.08
        case "+15% Move Speed":   move_speed_pct += 0.15
        // Utility
        case "+20 Mana":          mana_flat += 20
        case "+10% Mana":         mana_pct += 0.10
        case "+15% Mana Regen":   mana_regen_pct += 0.15
        case "+10% Cooldowns":    cooldown_pct += 0.10
        case "+15% XP Gain":      xp_gain_pct += 0.15
        // Keystones — strong specialised stats
        case "Wizard's Insight":  spell_damage_pct += 0.30
        case "Forest Pact":       hp_flat += 100
        case "Ember Heart":       crit_chance_pct += 0.25
        case "Storm Caller":      cooldown_pct += 0.20
        case "Stone Resolve":     dmg_reduce_pct += 0.20
        case "Bloodless":         damage_pct += 0.25
        case "Soulbinder":        mana_flat += 100; mana_regen_pct += 0.25
        case "Wraith Form":       move_speed_pct += 0.25
        case "Soul Core":         break  // free center, no bonus
        default:                  break  // unknown text — ignore safely
        }
    }

    func push() {
        assert(MemoryLayout<SkillBonuses>.size == 64,
               "SkillBonuses Swift layout drifted from Zig's 64-byte struct")
        var copy = self
        withUnsafeBytes(of: &copy) { raw in
            game_set_skill_bonuses(raw.baseAddress!.assumingMemoryBound(to: UInt8.self))
        }
    }
}

// ── Skill tree — radial node layout with allocatable bonuses ────────────────
private final class SkillTreeView: UIView, UIScrollViewDelegate {

    struct Node {
        let id: Int
        let ring: Int            // 0 = center, 1..N = rings outward
        let position: CGPoint    // relative to tree center, in local coords
        let bonus: String
        let bonusColor: UIColor  // category tint (red=offence, green=defence, blue=mana, etc.)
        let isKeystone: Bool     // outer ring nodes — bigger circle, fancier text
        var connections: [Int]
        var allocated: Bool
    }

    private(set) var nodes: [Node] = []

    fileprivate func computeBonuses() -> SkillBonuses {
        var b = SkillBonuses()
        for n in nodes where n.allocated { b.add(nodeText: n.bonus) }
        return b
    }

    private var nodeViews: [UIButton] = []
    private let connectionLayer = CAShapeLayer()
    private let backgroundGradient = CAGradientLayer()
    private let crystalChip = UIView()
    private let crystalLabel = UILabel()

    // Tree is hosted inside a scroll view so the player can pan + pinch-zoom.
    // Outer ring of keystones is at radius 325 (+ node size ~64), so the
    // content view needs enough headroom to fit them.
    private let scrollView   = UIScrollView()
    private let treeContent  = UIView()
    private static let contentSize: CGFloat = 800   // 800x800 canvas
    private static let contentCenter: CGFloat = SkillTreeView.contentSize / 2
    private static let initialZoom: CGFloat = 0.65  // start zoomed out

    var playerLevel: Int = 1 { didSet { refreshCrystalDisplay() } }
    var onAllocated: (() -> Void)?

    private var crystalsAvailable: Int {
        // Center node is always free; every additional allocation costs 1 crystal.
        let spent = nodes.filter({ $0.allocated }).count - 1
        return max(0, playerLevel - max(0, spent))
    }

    private var spentCrystals: Int {
        return max(0, nodes.filter({ $0.allocated }).count - 1)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        backgroundGradient.colors = [
            UIColor(red: 0.06, green: 0.04, blue: 0.18, alpha: 1).cgColor,
            UIColor(red: 0.02, green: 0.02, blue: 0.08, alpha: 1).cgColor,
        ]
        backgroundGradient.startPoint = CGPoint(x: 0.5, y: 0)
        backgroundGradient.endPoint   = CGPoint(x: 0.5, y: 1)
        layer.addSublayer(backgroundGradient)

        // Scroll view hosts the zoomable/pannable tree.
        scrollView.delegate = self
        scrollView.minimumZoomScale = 0.4
        scrollView.maximumZoomScale = 1.5
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator   = false
        scrollView.contentSize = CGSize(width: Self.contentSize, height: Self.contentSize)
        scrollView.backgroundColor = .clear
        addSubview(scrollView)

        treeContent.frame = CGRect(x: 0, y: 0, width: Self.contentSize, height: Self.contentSize)
        treeContent.backgroundColor = .clear
        scrollView.addSubview(treeContent)

        // Connection layer is now a sublayer of the zoomable content so its
        // strokes scale and pan with the nodes.
        connectionLayer.fillColor = UIColor.clear.cgColor
        connectionLayer.lineWidth = 2
        connectionLayer.frame = treeContent.bounds
        treeContent.layer.addSublayer(connectionLayer)

        nodes = Self.generateTree()
        nodes[0].allocated = true   // center starts allocated for free

        // Build node buttons inside the zoomable content view.
        for (i, n) in nodes.enumerated() {
            let btn = UIButton(type: .custom)
            btn.tag = i
            btn.titleLabel?.numberOfLines = 0
            btn.titleLabel?.textAlignment = .center
            btn.titleLabel?.font = .systemFont(ofSize: n.isKeystone ? 11 : 9, weight: .heavy)
            btn.setTitle(n.bonus, for: .normal)
            btn.layer.borderWidth = 1.5
            btn.layer.shadowColor   = UIColor.black.cgColor
            btn.layer.shadowOpacity = 0.7
            btn.layer.shadowRadius  = 4
            btn.layer.shadowOffset  = .zero
            btn.addTarget(self, action: #selector(nodeTapped(_:)), for: .touchUpInside)
            nodeViews.append(btn)
            treeContent.addSubview(btn)
        }

        // Crystal chip (top-left of the tree panel) — shows available skill crystals
        crystalChip.backgroundColor = UIColor(white: 0.05, alpha: 0.92)
        crystalChip.layer.cornerRadius = 14
        crystalChip.layer.borderWidth  = 1.5
        crystalChip.layer.borderColor  = UIColor(red: 0.55, green: 0.85, blue: 1.0, alpha: 1).cgColor
        addSubview(crystalChip)

        crystalLabel.font = .systemFont(ofSize: 14, weight: .heavy)
        crystalLabel.textColor = UIColor(red: 0.65, green: 0.90, blue: 1.0, alpha: 1)
        crystalLabel.textAlignment = .center
        crystalLabel.layer.shadowColor   = UIColor.black.cgColor
        crystalLabel.layer.shadowOpacity = 0.8
        crystalLabel.layer.shadowRadius  = 3
        crystalLabel.layer.shadowOffset  = .zero
        addSubview(crystalLabel)

        refreshAllVisuals()
    }
    required init?(coder: NSCoder) { fatalError() }

    private static func generateTree() -> [Node] {
        // Deterministic seeded generation so the tree looks the same across launches.
        var rng: UInt32 = 0xA1B2C3D4
        func next() -> UInt32 {
            rng ^= rng << 13; rng ^= rng >> 17; rng ^= rng << 5
            return rng
        }
        func pick<T>(_ arr: [T]) -> T { arr[Int(next() % UInt32(arr.count))] }

        // Bonus pool — categorised so node colour matches the role
        struct B { let text: String; let color: UIColor }
        let red    = UIColor(red: 1.0,  green: 0.30, blue: 0.25, alpha: 1)
        let green  = UIColor(red: 0.40, green: 0.95, blue: 0.40, alpha: 1)
        let blue   = UIColor(red: 0.40, green: 0.65, blue: 1.0,  alpha: 1)
        let purple = UIColor(red: 0.85, green: 0.40, blue: 1.0,  alpha: 1)
        let gold   = UIColor(red: 1.0,  green: 0.82, blue: 0.30, alpha: 1)
        let offence: [B] = [
            .init(text: "+5\nDamage",         color: red),
            .init(text: "+10\nDamage",        color: red),
            .init(text: "+15%\nDamage",       color: red),
            .init(text: "+20%\nDamage",       color: red),
            .init(text: "+25%\nSpell\nDamage",color: purple),
            .init(text: "+10%\nCast Speed",   color: purple),
            .init(text: "+15%\nCrit Chance",  color: red),
            .init(text: "+25%\nCrit Damage",  color: red),
        ]
        let defence: [B] = [
            .init(text: "+30 HP",             color: green),
            .init(text: "+50 HP",             color: green),
            .init(text: "+10%\nHP",           color: green),
            .init(text: "+15%\nArmour",       color: green),
            .init(text: "+8%\nDmg Reduce",    color: green),
            .init(text: "+15%\nMove Speed",   color: green),
        ]
        let utility: [B] = [
            .init(text: "+20\nMana",          color: blue),
            .init(text: "+10%\nMana",         color: blue),
            .init(text: "+15%\nMana Regen",   color: blue),
            .init(text: "+10%\nCooldowns",    color: blue),
            .init(text: "+15%\nXP Gain",      color: gold),
        ]
        let keystones: [B] = [
            .init(text: "Wizard's\nInsight",  color: purple),
            .init(text: "Forest\nPact",       color: green),
            .init(text: "Ember\nHeart",       color: red),
            .init(text: "Storm\nCaller",      color: blue),
            .init(text: "Stone\nResolve",     color: gold),
            .init(text: "Bloodless",          color: red),
            .init(text: "Soulbinder",         color: purple),
            .init(text: "Wraith\nForm",       color: blue),
        ]

        var out: [Node] = []
        // Center node: starting point, always allocated.
        out.append(Node(id: 0, ring: 0, position: .zero,
                         bonus: "Soul\nCore",
                         bonusColor: gold,
                         isKeystone: false,
                         connections: [],
                         allocated: false))

        // Helper to lay out a ring with N nodes evenly spaced
        let rings: [(count: Int, radius: CGFloat, offset: CGFloat)] = [
            (count: 6,  radius: 100, offset: 0),
            (count: 10, radius: 175, offset: .pi / 10),
            (count: 14, radius: 250, offset: 0),
            (count: 8,  radius: 325, offset: .pi / 8),    // keystones
        ]
        var idCounter = 1
        var ringStartIds: [[Int]] = [[0]]
        for (rIdx, ring) in rings.enumerated() {
            var ids: [Int] = []
            for i in 0 ..< ring.count {
                let ang = ring.offset + (CGFloat.pi * 2.0 * CGFloat(i)) / CGFloat(ring.count)
                let pos = CGPoint(x: cos(ang) * ring.radius, y: sin(ang) * ring.radius)
                let isKey = (rIdx == rings.count - 1)
                let bonus: B
                if isKey { bonus = pick(keystones) }
                else if i % 3 == 0 { bonus = pick(offence) }
                else if i % 3 == 1 { bonus = pick(defence) }
                else { bonus = pick(utility) }
                out.append(Node(id: idCounter, ring: rIdx + 1,
                                 position: pos,
                                 bonus: bonus.text,
                                 bonusColor: bonus.color,
                                 isKeystone: isKey,
                                 connections: [],
                                 allocated: false))
                ids.append(idCounter)
                idCounter += 1
            }
            ringStartIds.append(ids)
        }

        // Build connections: each node connects to the closest node in the
        // ring inside it, plus its two angular neighbours in the same ring.
        for rIdx in 1 ..< ringStartIds.count {
            let outer = ringStartIds[rIdx]
            let inner = ringStartIds[rIdx - 1]
            for (i, oid) in outer.enumerated() {
                // Closest inner-ring connection (by angular distance)
                let opos = out[oid].position
                var bestId = inner[0]
                var bestD: CGFloat = .greatestFiniteMagnitude
                for iid in inner {
                    let dx = out[iid].position.x - opos.x
                    let dy = out[iid].position.y - opos.y
                    let d = dx * dx + dy * dy
                    if d < bestD { bestD = d; bestId = iid }
                }
                out[oid].connections.append(bestId)
                out[bestId].connections.append(oid)
                // Lateral connection to next neighbour in same ring (every other slot)
                if i % 2 == 0 {
                    let nextI = (i + 1) % outer.count
                    let nid = outer[nextI]
                    out[oid].connections.append(nid)
                    out[nid].connections.append(oid)
                }
            }
        }
        // Dedup connections
        for i in 0 ..< out.count {
            out[i].connections = Array(Set(out[i].connections))
        }
        return out
    }

    @objc private func nodeTapped(_ btn: UIButton) {
        let id = btn.tag
        if id < 0 || id >= nodes.count { return }
        if nodes[id].allocated { return }
        // Must be connected to an already-allocated node
        let canAllocate = nodes[id].connections.contains(where: { nodes[$0].allocated })
        guard canAllocate else { return }
        guard crystalsAvailable > 0 else { return }
        nodes[id].allocated = true
        // Pulse animation on the node
        UIView.animate(withDuration: 0.10, animations: {
            btn.transform = CGAffineTransform(scaleX: 1.18, y: 1.18)
        }, completion: { _ in
            UIView.animate(withDuration: 0.18) {
                btn.transform = .identity
            }
        })
        refreshAllVisuals()
        onAllocated?()
    }

    private func refreshAllVisuals() {
        // Connection lines: gold if both endpoints allocated, else faint gray
        let gold = UIColor(red: 1.0,  green: 0.78, blue: 0.18, alpha: 1).cgColor
        let dim  = UIColor(white: 1, alpha: 0.10).cgColor
        let activePath = UIBezierPath()
        let dimPath    = UIBezierPath()
        let cc = Self.contentCenter
        for n in nodes {
            for c in n.connections where c > n.id {
                let other = nodes[c]
                let p1 = CGPoint(x: cc + n.position.x,     y: cc + n.position.y)
                let p2 = CGPoint(x: cc + other.position.x, y: cc + other.position.y)
                if n.allocated && other.allocated {
                    activePath.move(to: p1); activePath.addLine(to: p2)
                } else {
                    dimPath.move(to: p1);    dimPath.addLine(to: p2)
                }
            }
        }
        // Connection layer lives inside treeContent; sized to its bounds.
        connectionLayer.frame = treeContent.bounds
        connectionLayer.path = nil
        // Replace with two CAShapeLayers — easier than re-drawing
        connectionLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        let dl = CAShapeLayer(); dl.path = dimPath.cgPath
        dl.strokeColor = dim; dl.lineWidth = 2; dl.fillColor = UIColor.clear.cgColor
        connectionLayer.addSublayer(dl)
        let al = CAShapeLayer(); al.path = activePath.cgPath
        al.strokeColor = gold; al.lineWidth = 2.5; al.fillColor = UIColor.clear.cgColor
        al.shadowColor   = gold
        al.shadowOpacity = 0.55
        al.shadowRadius  = 6
        al.shadowOffset  = .zero
        connectionLayer.addSublayer(al)

        // Node visuals
        for (i, n) in nodes.enumerated() {
            let btn = nodeViews[i]
            let canAllocate = !n.allocated && n.connections.contains(where: { nodes[$0].allocated }) && crystalsAvailable > 0
            if n.allocated {
                btn.backgroundColor = n.bonusColor.withAlphaComponent(0.92)
                btn.layer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor
                btn.setTitleColor(.white, for: .normal)
                btn.layer.shadowOpacity = 0.85
                btn.layer.shadowColor   = n.bonusColor.cgColor
                btn.layer.shadowRadius  = 8
            } else if canAllocate {
                btn.backgroundColor = UIColor(white: 0.20, alpha: 0.85)
                btn.layer.borderColor = UIColor.white.withAlphaComponent(0.65).cgColor
                btn.setTitleColor(UIColor(white: 0.95, alpha: 1), for: .normal)
                btn.layer.shadowOpacity = 0.4
                btn.layer.shadowColor   = UIColor.white.cgColor
                btn.layer.shadowRadius  = 5
            } else {
                btn.backgroundColor = UIColor(white: 0.10, alpha: 0.65)
                btn.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
                btn.setTitleColor(UIColor(white: 0.55, alpha: 1), for: .normal)
                btn.layer.shadowOpacity = 0.0
            }
        }
        refreshCrystalDisplay()
    }

    private func refreshCrystalDisplay() {
        crystalLabel.text = "💎  \(crystalsAvailable) Skill Crystal\(crystalsAvailable == 1 ? "" : "s")"
    }

    private var didCenterTree = false

    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundGradient.frame = bounds
        scrollView.frame = bounds
        // Position nodes in treeContent coords (centered around contentCenter).
        let cc = Self.contentCenter
        connectionLayer.frame = treeContent.bounds
        for (i, n) in nodes.enumerated() {
            let btn = nodeViews[i]
            let size: CGFloat = n.isKeystone ? 64 : (n.ring == 0 ? 56 : 50)
            btn.frame = CGRect(x: cc + n.position.x - size / 2,
                               y: cc + n.position.y - size / 2,
                               width: size, height: size)
            btn.layer.cornerRadius = size / 2
        }
        // Crystal chip top-left of self (does NOT zoom/pan with the tree).
        let chipW: CGFloat = 175, chipH: CGFloat = 30
        crystalChip.frame  = CGRect(x: 16, y: 16, width: chipW, height: chipH)
        crystalLabel.frame = crystalChip.frame
        // Re-issue connection paths against treeContent bounds.
        refreshAllVisuals()

        // First-time zoom-out + center the tree on the visible area.
        if !didCenterTree, bounds.width > 0, bounds.height > 0 {
            didCenterTree = true
            scrollView.zoomScale = Self.initialZoom
            recenterContent()
        }
    }

    private func recenterContent() {
        let scaledW = scrollView.contentSize.width * scrollView.zoomScale
        let scaledH = scrollView.contentSize.height * scrollView.zoomScale
        let offX = max(0, (scaledW - bounds.width)  / 2)
        let offY = max(0, (scaledH - bounds.height) / 2)
        scrollView.contentOffset = CGPoint(x: offX, y: offY)
    }

    // MARK: UIScrollViewDelegate
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { treeContent }
}

// ── Full-screen game menu — Inventory / Skills tabs ────────────────────────
private final class GameMenuOverlay: UIView {
    enum Tab { case inventory, skills, map }
    var onClose: (() -> Void)?

    private let panel       = UIView()
    private let titleLbl    = UILabel()
    private let invTab      = UIButton(type: .system)
    private let skillTab    = UIButton(type: .system)
    private let mapTab      = UIButton(type: .system)
    private let underline   = UIView()
    private let contentArea = UIView()
    private let inventory   = InventoryView()
    let skillTree           = SkillTreeView()
    let mapPanel            = MapPanelView()
    private let closeBtn    = UIButton(type: .system)

    private var current: Tab = .skills

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0, alpha: 0.96)
        isUserInteractionEnabled = true

        // Full-screen panel — no border or rounded corners since it covers
        // the whole view.
        panel.backgroundColor = UIColor(white: 0.04, alpha: 1.0)
        addSubview(panel)

        titleLbl.text = "Character"
        titleLbl.font = .systemFont(ofSize: 22, weight: .heavy)
        titleLbl.textColor = .white
        titleLbl.textAlignment = .center
        panel.addSubview(titleLbl)

        for (btn, title, tab) in [(invTab, "Inventory", Tab.inventory),
                                   (skillTab, "Skills",    Tab.skills),
                                   (mapTab,   "Map",       Tab.map)] {
            btn.setTitle(title, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
            btn.tintColor = .white
            btn.addAction(UIAction { [weak self] _ in self?.switchTab(tab) }, for: .touchUpInside)
            panel.addSubview(btn)
        }
        underline.backgroundColor = UIColor(red: 1.0, green: 0.82, blue: 0.30, alpha: 1)
        underline.layer.cornerRadius = 1.5
        panel.addSubview(underline)

        contentArea.layer.masksToBounds = true
        contentArea.backgroundColor = UIColor(white: 0.02, alpha: 1)
        panel.addSubview(contentArea)

        contentArea.addSubview(inventory)
        contentArea.addSubview(skillTree)
        contentArea.addSubview(mapPanel)

        closeBtn.setTitle("✕  Close", for: .normal)
        closeBtn.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        closeBtn.tintColor = UIColor(white: 0.8, alpha: 1)
        closeBtn.addAction(UIAction { [weak self] _ in self?.onClose?() }, for: .touchUpInside)
        panel.addSubview(closeBtn)

        switchTab(.skills)
    }
    required init?(coder: NSCoder) { fatalError() }

    func switchTab(_ tab: Tab) {
        current = tab
        inventory.isHidden = tab != .inventory
        skillTree.isHidden = tab != .skills
        mapPanel.isHidden  = tab != .map
        UIView.animate(withDuration: 0.18) { self.layoutTabs() }
    }

    private func layoutTabs() {
        // Move the underline beneath the active tab
        let target: UIButton
        switch current {
        case .inventory: target = invTab
        case .skills:    target = skillTab
        case .map:       target = mapTab
        }
        underline.frame = CGRect(x: target.frame.minX + 8,
                                  y: target.frame.maxY - 2,
                                  width: target.frame.width - 16,
                                  height: 3)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Panel = full screen.
        panel.frame = bounds
        let panelW = bounds.width
        let panelH = bounds.height

        // Honor top safe area on iPhones with notches/Dynamic Island.
        let safeTop = safeAreaInsets.top
        let safeBot = safeAreaInsets.bottom

        titleLbl.frame = CGRect(x: 0, y: safeTop + 12, width: panelW, height: 30)

        // Tab buttons centered side-by-side
        let tabW: CGFloat = 110
        let tabH: CGFloat = 40
        let tabGap: CGFloat = 14
        let tabsY = titleLbl.frame.maxY + 10
        let totalTabsW = tabW * 3 + tabGap * 2
        let tabsX = (panelW - totalTabsW) / 2
        invTab.frame   = CGRect(x: tabsX,                                y: tabsY, width: tabW, height: tabH)
        skillTab.frame = CGRect(x: tabsX + tabW + tabGap,                y: tabsY, width: tabW, height: tabH)
        mapTab.frame   = CGRect(x: tabsX + (tabW + tabGap) * 2,          y: tabsY, width: tabW, height: tabH)
        layoutTabs()

        // Close button — top-right, above the tab row so it's reachable.
        closeBtn.frame = CGRect(x: panelW - 80, y: safeTop + 8, width: 64, height: 36)

        // Content area takes the entire remaining canvas.
        let contentY = invTab.frame.maxY + 12
        contentArea.frame = CGRect(x: 0,
                                    y: contentY,
                                    width: panelW,
                                    height: panelH - contentY - safeBot - 8)

        inventory.frame = contentArea.bounds
        skillTree.frame = contentArea.bounds
        mapPanel.frame  = contentArea.bounds
    }
}

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
    var wispVBuf:          MTLBuffer!
    var wispIBuf:          MTLBuffer!
    var wispIndexCount:    Int = 0
    var entVBuf:           MTLBuffer!
    var entIBuf:           MTLBuffer!
    var entIndexCount:     Int = 0
    var knightVBuf:        MTLBuffer!
    var knightIBuf:        MTLBuffer!
    var knightIndexCount:  Int = 0
    var impactRingVBuf:    MTLBuffer!
    var impactRingIBuf:    MTLBuffer!
    var impactRingIndexCount: Int = 0

    // Skill hotbar — 4 buttons in fixed order:
    // 0=fireball, 1=lightning_strike, 2=ice_nova, 3=dash. Index matches the
    // Skill enum in src/game/player.zig and the skill_idx arg of game_touch_skill.
    private var skillButtons: [UIButton] = []
    private struct SkillSlot {
        let idx: Int
        let glyph: String
        let label: String
        let tint: UIColor   // border / glow tint per element
    }
    private let skillSlots: [SkillSlot] = [
        .init(idx: 0, glyph: "🔥", label: "Fireball",  tint: UIColor(red: 1.00, green: 0.45, blue: 0.20, alpha: 1)),
        .init(idx: 1, glyph: "⚡", label: "Lightning", tint: UIColor(red: 0.35, green: 0.80, blue: 1.00, alpha: 1)),
        .init(idx: 2, glyph: "❄",  label: "Ice Nova", tint: UIColor(red: 0.55, green: 0.85, blue: 1.00, alpha: 1)),
        .init(idx: 3, glyph: "💨", label: "Dash",     tint: UIColor(red: 0.85, green: 0.85, blue: 0.55, alpha: 1)),
    ]

    // HUD stat bar + XP bar + enemy labels + level display
    private var statBar:      StatBarView!
    private var xpBar:        XPBarView!
    private var labelOverlay: EnemyLabelOverlay!
    private var levelLabel:   UILabel!
    private var labelStagingBuf: [UInt8]

    // Zone-portal destination map UI (shown when player walks into the gate)
    private var portalMapView: PortalMapView!
    private var portalUIVisible: Bool = false
    private var portalCooldown:  Float = 0     // seconds — block re-show after dismiss

    // Top-right menu button + full-screen Inventory/Skills overlay
    private var menuButton:    UIButton!
    private var menuOverlay:   GameMenuOverlay!
    private var menuUIVisible: Bool = false

    // Persistent debug HUD pinned top-left. Updates every frame with
    // current_zone + player pos so it's instantly obvious whether the build
    // has the new zone-switch code (a build without game_get_zone won't
    // change the value when a zone is tapped). Remove once travel is verified.
    private var debugHUD: UILabel!

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

        // Push initial (zero) bonuses so Zig has a clean state from frame 1.
        SkillBonuses().push()
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

        // Skill hotbar: 4 buttons stacked in a 2×2 grid in the bottom-right
        // corner, same vertical band as the joystick. Slot index → grid pos:
        //   0 (fireball)  bottom-left,  1 (lightning) bottom-right,
        //   2 (ice nova)  top-left,     3 (dash)      top-right.
        let btn: CGFloat = 60
        let gap: CGFloat = 8
        let gridRight = view.bounds.width - 10
        let gridBot   = view.bounds.height - safe - 26
        let positions: [(x: CGFloat, y: CGFloat)] = [
            (gridRight - btn * 2 - gap, gridBot - btn),                    // 0 fireball
            (gridRight - btn,           gridBot - btn),                    // 1 lightning
            (gridRight - btn * 2 - gap, gridBot - btn * 2 - gap),          // 2 ice nova
            (gridRight - btn,           gridBot - btn * 2 - gap),          // 3 dash
        ]
        for (i, b) in skillButtons.enumerated() where i < positions.count {
            let p = positions[i]
            b.frame = CGRect(x: p.x, y: p.y, width: btn, height: btn)
            b.layer.cornerRadius = btn / 2
        }

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

        // Level label — centred, just above the XP bar
        levelLabel.frame = CGRect(x: (view.bounds.width - 90) / 2,
                                   y: xpY - 22,
                                   width: 90, height: 20)

        // Menu button — top-right corner
        let topSafe = view.safeAreaInsets.top
        let mb: CGFloat = 52
        menuButton.frame = CGRect(x: view.bounds.width - 14 - mb,
                                   y: topSafe + 14,
                                   width: mb, height: mb)
        menuButton.layer.cornerRadius = mb / 2

        // Menu overlay — fullscreen
        menuOverlay.frame = view.bounds

        // Portal map view (also fullscreen)
        portalMapView.frame = view.bounds

        // Debug HUD — top-left under the safe area
        debugHUD.frame = CGRect(x: 12, y: topSafe + 12, width: 240, height: 60)
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

        // Portal proximity → surface destination map UI when the player
        // walks into the gate. Cooldown prevents immediate re-show after
        // dismiss while the player is still standing inside the radius.
        if portalCooldown > 0 { portalCooldown -= dt }
        if !portalUIVisible && portalCooldown <= 0 && game_player_at_portal() == 1 {
            presentPortalUI()
        }

        // 1. Tick game (frozen while a full-screen UI is shown)
        if !portalUIVisible && !menuUIVisible {
            game_update(dt)
        }

        // Update stat + XP bars + level label
        var hp: Float = 0, hpMax: Float = 0, mp: Float = 0, mpMax: Float = 0, xpFrac: Float = 0
        game_get_player_stats(&hp, &hpMax, &mp, &mpMax, &xpFrac)
        statBar.update(hp: hp, hpMax: hpMax, mp: mp, mpMax: mpMax)
        xpBar.update(frac: xpFrac)
        let playerLevel = UInt8(min(255, game_get_player_level()))
        levelLabel.text = "Lv. \(playerLevel)"

        // Debug HUD — live zone + player pos. If you tap a new zone in the
        // Map tab and the values here don't change, the build is stale.
        var dbgX: Float = 0, dbgY: Float = 0, dbgZ: Float = 0
        game_get_player_pos(&dbgX, &dbgY, &dbgZ)
        let dbgZone = game_get_zone()
        let zoneName: String
        switch dbgZone {
        case 1:  zoneName = "DESERT"
        case 2:  zoneName = "ISLES"
        default: zoneName = "FOREST"
        }
        debugHUD.text = String(format: "[zone] %@ id=%u\nplayer=(%.0f, %.0f, %.0f)",
                               zoneName, dbgZone, dbgX, dbgY, dbgZ)

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
                            case 25: return (wispVBuf,        wispIBuf,        wispIndexCount)
                            case 26: return (entVBuf,         entIBuf,         entIndexCount)
                            case 27: return (knightVBuf,      knightIBuf,      knightIndexCount)
                            case 28: return (impactRingVBuf,  impactRingIBuf,  impactRingIndexCount)
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

    // ── Skill hotbar ─────────────────────────────────────────────────────────

    private func setupSkillButton() {
        skillButtons.removeAll()
        for slot in skillSlots {
            let b = UIButton(type: .custom)
            b.tag = slot.idx
            b.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.16, alpha: 0.92)
            b.layer.borderWidth = 2.5
            b.layer.borderColor = slot.tint.withAlphaComponent(0.90).cgColor
            b.layer.shadowColor   = slot.tint.cgColor
            b.layer.shadowRadius  = 10
            b.layer.shadowOpacity = 0.75
            b.layer.shadowOffset  = .zero
            b.setTitle(slot.glyph, for: .normal)
            b.titleLabel?.font = UIFont.systemFont(ofSize: 28, weight: .medium)
            b.addTarget(self, action: #selector(skillSlotTapped(_:)), for: .touchUpInside)
            view.addSubview(b)
            skillButtons.append(b)
        }
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

        // ── Zone-portal destination map (hidden until the player walks into the gate)
        portalMapView = PortalMapView(frame: view.bounds)
        portalMapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        portalMapView.isHidden = true
        portalMapView.onZoneSelected = { [weak self] zoneId, name in
            self?.travelToZone(zoneId: zoneId, name: name, dismiss: { self?.dismissPortalUI() })
        }
        portalMapView.onCancel = { [weak self] in self?.dismissPortalUI() }
        view.addSubview(portalMapView)

        // ── Persistent debug HUD (top-left) — updates every frame in draw()
        debugHUD = UILabel()
        debugHUD.font      = .monospacedSystemFont(ofSize: 11, weight: .bold)
        debugHUD.textColor = UIColor(red: 0.95, green: 0.95, blue: 0.40, alpha: 1)
        debugHUD.numberOfLines = 0
        debugHUD.layer.shadowColor   = UIColor.black.cgColor
        debugHUD.layer.shadowOpacity = 1.0
        debugHUD.layer.shadowRadius  = 2
        debugHUD.layer.shadowOffset  = .zero
        debugHUD.text = "[zone] booting…"
        view.addSubview(debugHUD)

        // ── Top-right menu button + full-screen Inventory/Skills overlay
        menuButton = UIButton(type: .custom)
        menuButton.setTitle("☰", for: .normal)
        menuButton.titleLabel?.font = .systemFont(ofSize: 24, weight: .heavy)
        menuButton.setTitleColor(.white, for: .normal)
        menuButton.backgroundColor = UIColor(white: 0.08, alpha: 0.85)
        menuButton.layer.borderWidth = 2
        menuButton.layer.borderColor = UIColor.white.withAlphaComponent(0.40).cgColor
        menuButton.layer.shadowColor   = UIColor.black.cgColor
        menuButton.layer.shadowOpacity = 0.6
        menuButton.layer.shadowRadius  = 6
        menuButton.layer.shadowOffset  = .zero
        menuButton.addTarget(self, action: #selector(menuButtonTapped), for: .touchUpInside)
        view.addSubview(menuButton)

        menuOverlay = GameMenuOverlay(frame: view.bounds)
        menuOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        menuOverlay.isHidden = true
        menuOverlay.onClose = { [weak self] in self?.dismissMenu() }
        menuOverlay.skillTree.onAllocated = { [weak self] in
            self?.menuOverlay.skillTree.computeBonuses().push()
        }
        menuOverlay.mapPanel.onTravel = { [weak self] zoneId, name in
            self?.travelToZone(zoneId: zoneId, name: name, dismiss: { self?.dismissMenu() })
        }
        view.addSubview(menuOverlay)
    }

    @objc private func menuButtonTapped() {
        if menuUIVisible { dismissMenu() } else { presentMenu() }
    }

    private func presentMenu() {
        guard !menuUIVisible else { return }
        menuUIVisible = true
        menuOverlay.skillTree.playerLevel = Int(min(255, game_get_player_level()))
        menuOverlay.alpha = 0
        menuOverlay.isHidden = false
        UIView.animate(withDuration: 0.20) { self.menuOverlay.alpha = 1 }
    }

    private func dismissMenu() {
        guard menuUIVisible else { return }
        menuUIVisible = false
        UIView.animate(withDuration: 0.18, animations: { self.menuOverlay.alpha = 0 }) { _ in
            self.menuOverlay.isHidden = true
        }
    }

    // ── Portal map UI helpers ────────────────────────────────────────────────
    private func presentPortalUI() {
        guard !portalUIVisible else { return }
        portalUIVisible = true
        portalMapView.alpha = 0
        portalMapView.isHidden = false
        UIView.animate(withDuration: 0.25) { self.portalMapView.alpha = 1 }
    }

    private func dismissPortalUI() {
        guard portalUIVisible else { return }
        portalUIVisible = false
        portalCooldown  = 1.5   // seconds — prevent immediate re-trigger if still inside radius
        UIView.animate(withDuration: 0.20, animations: { self.portalMapView.alpha = 0 }) { _ in
            self.portalMapView.isHidden = true
        }
    }

    // Switch active zone in Zig + flash a brief travel banner.
    // After game_set_zone the player teleports to the zone's start spot; we
    // read it back via game_get_player_pos so the banner shows the live coords
    // (smoking-gun diagnostic that the Zig side actually rebuilt the world).
    // We also recolour the MTKView clear so the screen tint changes per zone
    // even before the camera has lerped to the new player position.
    private func travelToZone(zoneId: Int, name: String, dismiss: @escaping () -> Void) {
        NSLog("[zone] travelToZone tapped zoneId=\(zoneId) name=\(name)")
        game_set_zone(UInt32(zoneId))

        // Read back actual player pos + reported zone so we can prove on screen
        // whether the new Zig code is in the build.
        var px: Float = 0, py: Float = 0, pz: Float = 0
        game_get_player_pos(&px, &py, &pz)
        let liveZone = game_get_zone()
        NSLog("[zone] after game_set_zone liveZone=\(liveZone) player=(\(px),\(py),\(pz))")
        applyZoneClearColor(zoneId: Int(liveZone))

        showTravelBanner(
            "Travelling to \(name)\n" +
            String(format: "zone=%u  player=(%.0f, %.0f, %.0f)", liveZone, px, py, pz)
        )
        dismiss()
    }

    // Recolour the MTKView clear so the screen visibly changes between zones
    // even if no entities re-render (forest dark blue, desert warm brown,
    // isles deep teal). Called from travelToZone — the change is independent
    // of the Zig binary, so a colour swap proves Swift wired the tap up.
    private func applyZoneClearColor(zoneId: Int) {
        let c: MTLClearColor
        switch zoneId {
        case 1: c = MTLClearColor(red: 0.18, green: 0.10, blue: 0.04, alpha: 1) // desert
        case 2: c = MTLClearColor(red: 0.02, green: 0.08, blue: 0.14, alpha: 1) // isles
        default: c = MTLClearColor(red: 0.03, green: 0.03, blue: 0.05, alpha: 1) // forest
        }
        mtkView.clearColor = c
        NSLog("[zone] applyZoneClearColor zoneId=\(zoneId)")
    }

    private func showTravelBanner(_ text: String) {
        let banner = UILabel()
        banner.text = text
        banner.font = .systemFont(ofSize: 16, weight: .heavy)
        banner.textColor = .white
        banner.textAlignment = .center
        banner.numberOfLines = 0           // allow the diagnostic line to wrap
        banner.backgroundColor = UIColor(red: 0.10, green: 0.10, blue: 0.16, alpha: 0.92)
        banner.layer.cornerRadius = 10
        banner.layer.masksToBounds = true
        banner.alpha = 0
        let w: CGFloat = 320, h: CGFloat = 70
        banner.frame = CGRect(x: (view.bounds.width - w) / 2,
                               y: view.safeAreaInsets.top + 80,
                               width: w, height: h)
        view.addSubview(banner)
        UIView.animate(withDuration: 0.25, animations: { banner.alpha = 1 }) { _ in
            UIView.animate(withDuration: 0.45, delay: 1.2, options: [],
                           animations: { banner.alpha = 0 },
                           completion: { _ in banner.removeFromSuperview() })
        }
    }

    @objc private func skillSlotTapped(_ sender: UIButton) {
        let idx = sender.tag
        guard idx >= 0 && idx < skillSlots.count else { return }
        // Pass (0, 0) — Zig autoaims fireball at the nearest enemy when target
        // is the origin; lightning self-targets internally; dash uses player
        // facing; ice_nova radiates from the player. None of the four hotbar
        // skills require a tapped world-space target today.
        game_touch_skill(UInt8(idx), 0.0, 0.0)

        // Press feedback — flash bright in the slot's tint, then settle back.
        let tint = skillSlots[idx].tint
        UIView.animate(withDuration: 0.06) {
            sender.transform = CGAffineTransform(scaleX: 0.88, y: 0.88)
            sender.backgroundColor = tint.withAlphaComponent(0.85)
            sender.layer.shadowOpacity = 1.0
            sender.layer.shadowRadius  = 22
        } completion: { _ in
            UIView.animate(withDuration: 0.30, delay: 0, options: .curveEaseOut) {
                sender.transform = .identity
                sender.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.16, alpha: 0.92)
                sender.layer.shadowOpacity = 0.75
                sender.layer.shadowRadius  = 10
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

        // ── 3 new enemy meshes ───────────────────────────────────────────
        let (wpv, wpi, wpc) = makeForestWisp(device: device)
        wispVBuf = wpv;         wispIBuf = wpi;         wispIndexCount = wpc
        let (env_, eni, enc_) = makeTreeEnt(device: device)
        entVBuf = env_;         entIBuf = eni;          entIndexCount = enc_
        let (knv, kni, knc) = makeSkeletonKnight(device: device)
        knightVBuf = knv;       knightIBuf = kni;       knightIndexCount = knc
        let (irv, iri, irc) = makeImpactRing(device: device)
        impactRingVBuf = irv;   impactRingIBuf = iri;   impactRingIndexCount = irc

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
