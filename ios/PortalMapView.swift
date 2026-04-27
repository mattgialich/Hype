// PortalMapView.swift
// Destination selection UI shown when the player walks up to the zone portal.
// Owned by GameViewController; emits onForest / onComingSoon callbacks.

import UIKit

final class PortalMapView: UIView {
    var onForest:  (() -> Void)?
    var onComingSoon: ((String) -> Void)?

    private let panel    = UIView()
    private let titleLbl = UILabel()
    private let statusLbl = UILabel()
    private let closeBtn = UIButton(type: .system)
    
    // Map elements
    private let mapBackground = UIView()
    private let mapGradient   = CAGradientLayer()
    private let vignetteLayer = CAShapeLayer()
    private let compassRose   = CAShapeLayer()
    private let decorLayer    = CAShapeLayer()
    private var compassLabels: [UILabel] = []
    private let forestPin: MapPin
    private let desertPin: MapPin
    private let islandPin: MapPin

    // Pin positions in normalized (0..1) map-area coords
    private let forestPinPos = CGPoint(x: 0.30, y: 0.62)
    private let desertPinPos = CGPoint(x: 0.72, y: 0.32)
    private let islandPinPos = CGPoint(x: 0.55, y: 0.85)

    fileprivate final class MapPin: UIControl {
        let nameText: String
        let isAvailable: Bool
        private let glowLayer = CAGradientLayer()
        private let pinLayer  = CAShapeLayer()
        private let nameLbl   = UILabel()

        // Hit area: 160 wide (room for the name) × 60 tall (pin + label).
        // The pin dot itself is 22 pt centered in the top half.
        static let hitW: CGFloat = 160
        static let hitH: CGFloat = 60
        static let pinSize: CGFloat = 22
        static let haloSize: CGFloat = 56

        init(name: String, available: Bool) {
            self.nameText    = name
            self.isAvailable = available
            super.init(frame: .zero)

            // Halo (radial gradient) — gold for available, faint gray for locked.
            // Layer order: halo first so it sits behind the pin dot.
            glowLayer.type = .radial
            glowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
            glowLayer.endPoint   = CGPoint(x: 1.0, y: 1.0)
            glowLayer.colors = available
                ? [
                    UIColor(red: 1.0, green: 0.82, blue: 0.30, alpha: 0.75).cgColor,
                    UIColor(red: 1.0, green: 0.82, blue: 0.30, alpha: 0.0).cgColor,
                  ]
                : [
                    UIColor(white: 0.35, alpha: 0.45).cgColor,
                    UIColor(white: 0.35, alpha: 0.0).cgColor,
                  ]
            layer.addSublayer(glowLayer)

            // Pin dot — gold-filled if available, dim otherwise.
            pinLayer.fillColor   = available
                ? UIColor(red: 1.0, green: 0.82, blue: 0.30, alpha: 1).cgColor
                : UIColor(white: 0.55, alpha: 1).cgColor
            pinLayer.strokeColor = UIColor(white: 0.10, alpha: 1).cgColor
            pinLayer.lineWidth   = 1.5
            layer.addSublayer(pinLayer)

            // Name label sits below the dot.
            nameLbl.text = name
            nameLbl.font = .systemFont(ofSize: 13, weight: .heavy)
            nameLbl.textColor = available
                ? UIColor(red: 1.0, green: 0.92, blue: 0.70, alpha: 1)
                : UIColor(white: 0.78, alpha: 1)
            nameLbl.textAlignment = .center
            nameLbl.layer.shadowColor   = UIColor.black.cgColor
            nameLbl.layer.shadowOpacity = 0.8
            nameLbl.layer.shadowRadius  = 3
            nameLbl.layer.shadowOffset  = .zero
            addSubview(nameLbl)

            addTarget(self, action: #selector(touchDown), for: .touchDown)
            addTarget(self, action: #selector(touchUp),   for: [.touchUpInside, .touchUpOutside, .touchCancel])
        }
        required init?(coder: NSCoder) { fatalError() }

        @objc private func touchDown() {
            UIView.animate(withDuration: 0.08) { self.transform = CGAffineTransform(scaleX: 1.18, y: 1.18) }
        }
        @objc private func touchUp() {
            UIView.animate(withDuration: 0.14) { self.transform = .identity }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            let cx = bounds.width / 2
            let pinTopY: CGFloat = 4
            let pinR = MapPin.pinSize / 2

            // Halo centered on the pin
            let halo = MapPin.haloSize
            glowLayer.frame = CGRect(
                x: cx - halo / 2,
                y: pinTopY + pinR - halo / 2,
                width: halo, height: halo)

            // Pin shape sits inside its own layer rect (bounds-local arc)
            pinLayer.frame = CGRect(x: cx - pinR, y: pinTopY, width: MapPin.pinSize, height: MapPin.pinSize)
            pinLayer.path  = UIBezierPath(
                arcCenter: CGPoint(x: pinR, y: pinR),
                radius: pinR - 1,
                startAngle: 0, endAngle: .pi * 2, clockwise: true).cgPath

            // Name label stretched across the hit area, below the pin
            nameLbl.frame = CGRect(x: 0, y: pinTopY + MapPin.pinSize + 4,
                                   width: bounds.width, height: 18)
        }
    }

    override init(frame: CGRect) {
        forestPin = MapPin(name: "Whispering Forest", available: true)
        desertPin = MapPin(name: "Sunburnt Wastes",   available: false)
        islandPin = MapPin(name: "Drifting Isles",    available: false)
        super.init(frame: frame)

        backgroundColor = UIColor(white: 0, alpha: 0.78)
        isUserInteractionEnabled = true

        // Panel setup
        panel.backgroundColor   = UIColor(white: 0.05, alpha: 0.90)
        panel.layer.cornerRadius = 22
        panel.layer.borderWidth  = 1
        panel.layer.borderColor  = UIColor.white.withAlphaComponent(0.20).cgColor
        addSubview(panel)

        // Title
        titleLbl.text = "Choose Your Destination"
        titleLbl.font = .systemFont(ofSize: 26, weight: .heavy)
        titleLbl.textColor = .white
        titleLbl.textAlignment = .center
        titleLbl.layer.shadowColor   = UIColor.black.cgColor
        titleLbl.layer.shadowOpacity = 0.7
        titleLbl.layer.shadowRadius  = 4
        titleLbl.layer.shadowOffset  = .zero
        panel.addSubview(titleLbl)

        // Status label
        statusLbl.font = .systemFont(ofSize: 16, weight: .medium)
        statusLbl.textColor = .white
        statusLbl.textAlignment = .center
        statusLbl.layer.shadowColor = UIColor.black.cgColor
        statusLbl.layer.shadowOpacity = 0.7
        statusLbl.layer.shadowRadius = 2
        statusLbl.layer.shadowOffset = .zero
        panel.addSubview(statusLbl)

        // Map background — clip the parchment gradient to the rounded rect.
        mapBackground.backgroundColor = .clear
        mapBackground.layer.cornerRadius  = 16
        mapBackground.layer.masksToBounds = true
        panel.addSubview(mapBackground)

        // Parchment gradient — warm cream top to faded ochre bottom.
        mapGradient.colors = [
            UIColor(red: 0.96, green: 0.91, blue: 0.78, alpha: 1).cgColor,
            UIColor(red: 0.86, green: 0.74, blue: 0.58, alpha: 1).cgColor,
        ]
        mapGradient.startPoint = CGPoint(x: 0.5, y: 0)
        mapGradient.endPoint   = CGPoint(x: 0.5, y: 1)
        mapBackground.layer.addSublayer(mapGradient)

        // Hand-drawn decorations (mountains/trees/waves) — single shape layer,
        // path is rebuilt from map bounds in layoutSubviews().
        decorLayer.fillColor   = UIColor.clear.cgColor
        decorLayer.strokeColor = UIColor(white: 0.20, alpha: 0.85).cgColor
        decorLayer.lineWidth   = 1.2
        decorLayer.lineCap     = .round
        decorLayer.lineJoin    = .round
        mapBackground.layer.addSublayer(decorLayer)

        // Compass rose path + N/E/S/W labels — also rebuilt in layout.
        compassRose.fillColor   = UIColor.clear.cgColor
        compassRose.strokeColor = UIColor(white: 0.22, alpha: 0.9).cgColor
        compassRose.lineWidth   = 1.2
        mapBackground.layer.addSublayer(compassRose)
        for _ in 0..<4 {
            let l = UILabel()
            l.font = .systemFont(ofSize: 11, weight: .heavy)
            l.textColor = UIColor(white: 0.20, alpha: 0.9)
            l.textAlignment = .center
            mapBackground.addSubview(l)
            compassLabels.append(l)
        }
        compassLabels[0].text = "N"; compassLabels[1].text = "E"
        compassLabels[2].text = "S"; compassLabels[3].text = "W"

        // Vignette stroke around the map's rounded edge.
        vignetteLayer.fillColor   = UIColor.clear.cgColor
        vignetteLayer.strokeColor = UIColor(red: 0.30, green: 0.18, blue: 0.06, alpha: 0.55).cgColor
        vignetteLayer.lineWidth   = 2
        mapBackground.layer.addSublayer(vignetteLayer)

        // Add pins on top of all decoration layers.
        for pin in [forestPin, desertPin, islandPin] {
            pin.bounds = CGRect(x: 0, y: 0, width: MapPin.hitW, height: MapPin.hitH)
            mapBackground.addSubview(pin)
            pin.addTarget(self, action: #selector(pinTapped(_:)), for: .touchUpInside)
        }
        
        // Close button
        closeBtn.setTitle("✕  Close", for: .normal)
        closeBtn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        closeBtn.tintColor = UIColor(white: 0.85, alpha: 1)
        closeBtn.addTarget(self, action: #selector(tapClose), for: .touchUpInside)
        panel.addSubview(closeBtn)
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func pinTapped(_ sender: MapPin) {
        statusLbl.text = sender.nameText + (sender.isAvailable ? " — Available" : " — Coming Soon")
        if sender === forestPin { onForest?() }
        else                    { onComingSoon?(sender.nameText) }
    }

    @objc private func tapClose() { onForest?() }   // dismiss = same as continue in current zone

    // Build the compass rose path + position N/E/S/W labels into the
    // top-right corner of the map at (cx, cy) with the given radius.
    private func updateCompassRose(center c: CGPoint, radius r: CGFloat) {
        let p = UIBezierPath()
        
        // Diamond-shaped long arms (N, E, S, W)
        let diamondSize: CGFloat = r * 0.4
        let diamondPoints: [(angle: CGFloat, size: CGFloat)] = [
            (0, diamondSize),           // N
            (.pi / 2, diamondSize),     // E
            (.pi, diamondSize),         // S
            (3 * .pi / 2, diamondSize), // W
        ]
        for (angle, size) in diamondPoints {
            let x1 = c.x + cos(angle) * size
            let y1 = c.y + sin(angle) * size
            let x2 = c.x + cos(angle + .pi / 2) * size * 0.6
            let y2 = c.y + sin(angle + .pi / 2) * size * 0.6
            let x3 = c.x + cos(angle + .pi) * size
            let y3 = c.y + sin(angle + .pi) * size
            let x4 = c.x + cos(angle - .pi / 2) * size * 0.6
            let y4 = c.y + sin(angle - .pi / 2) * size * 0.6
            
            p.move(to: CGPoint(x: x1, y: y1))
            p.addLine(to: CGPoint(x: x2, y: y2))
            p.addLine(to: CGPoint(x: x3, y: y3))
            p.addLine(to: CGPoint(x: x4, y: y4))
            p.addLine(to: CGPoint(x: x1, y: y1))
        }
        
        // Short straight arms (NE, SE, SW, NW)
        let shortArmLen: CGFloat = r * 0.3
        let shortArms: [(angle: CGFloat, len: CGFloat)] = [
            (.pi / 4, shortArmLen),
            (3 * .pi / 4, shortArmLen),
            (5 * .pi / 4, shortArmLen),
            (7 * .pi / 4, shortArmLen),
        ]
        for arm in shortArms {
            p.move(to: c)
            p.addLine(to: CGPoint(x: c.x + cos(arm.angle) * arm.len,
                                  y: c.y + sin(arm.angle) * arm.len))
        }
        
        // Inner circle
        p.addArc(withCenter: c, radius: r * 0.35, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        
        // Center dot
        p.addArc(withCenter: c, radius: 2, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        
        compassRose.path = p.cgPath

        // Labels just outside each cardinal arm tip.
        let labelOffset = r + 9
        let labelDirs: [CGFloat] = [-(.pi / 2), 0, .pi / 2, .pi]   // N, E, S, W
        for (i, ang) in labelDirs.enumerated() {
            let x = c.x + cos(ang) * labelOffset
            let y = c.y + sin(ang) * labelOffset
            compassLabels[i].frame = CGRect(x: x - 8, y: y - 8, width: 16, height: 16)
        }
    }

    // Build the hand-drawn decorations path inside the map area `r`.
    // All coords are computed from `r` so the layout scales with the panel.
    private func updateDecorations(in r: CGRect) {
        let p = UIBezierPath()

        // Mountain range across the upper-left quadrant
        let mtnY  = r.minY + r.height * 0.30
        let mtnX0 = r.minX + r.width * 0.08
        let mtnX1 = r.minX + r.width * 0.42
        let peaks: [(CGFloat, CGFloat)] = [
            (0.0, 0.0), (0.08, -0.07), (0.16, 0.0), (0.24, -0.10),
            (0.32, 0.0), (0.40, -0.06), (0.48, 0.0), (0.56, -0.05), (0.64, 0.0),
        ]
        // Add foothill peaks behind main range
        let foothillPeaks: [(CGFloat, CGFloat)] = [
            (0.1, -0.03), (0.2, -0.02), (0.3, -0.04), (0.4, -0.01),
        ]
        var first = true
        for (tx, ty) in peaks {
            let x = mtnX0 + (mtnX1 - mtnX0) * tx
            let y = mtnY + r.height * ty
            if first { p.move(to: CGPoint(x: x, y: y)); first = false }
            else     { p.addLine(to: CGPoint(x: x, y: y)) }
        }
        // Add foothill peaks
        for (tx, ty) in foothillPeaks {
            let x = mtnX0 + (mtnX1 - mtnX0) * tx
            let y = mtnY + r.height * ty + 8
            p.move(to: CGPoint(x: x, y: y))
            p.addLine(to: CGPoint(x: x, y: y - 12))
        }

        // Tree cluster (lower-left) - fir trees
        let treeY = r.minY + r.height * 0.72
        let treeCluster1 = [
            (0.14, 0.0), (0.16, -0.05), (0.18, 0.0), (0.20, -0.03),
            (0.22, 0.0), (0.24, -0.04), (0.26, 0.0), (0.28, -0.02)
        ]
        let treeCluster2 = [
            (0.30, 0.0), (0.32, -0.06), (0.34, 0.0), (0.36, -0.03),
            (0.38, 0.0), (0.40, -0.05), (0.42, 0.0), (0.44, -0.02)
        ]
        for (_, (tx, ty)) in treeCluster1.enumerated() {
            let cx = r.minX + r.width * tx
            let y = treeY + r.height * ty
            // Fir tree silhouette
            p.move(to: CGPoint(x: cx, y: y))
            p.addLine(to: CGPoint(x: cx - 4, y: y - 10))
            p.addLine(to: CGPoint(x: cx + 4, y: y - 10))
            p.addLine(to: CGPoint(x: cx, y: y))
            // Trunk
            p.move(to: CGPoint(x: cx, y: y))
            p.addLine(to: CGPoint(x: cx, y: y + 3))
        }
        for (_, (tx, ty)) in treeCluster2.enumerated() {
            let cx = r.minX + r.width * tx
            let y = treeY + r.height * ty
            // Fir tree silhouette
            p.move(to: CGPoint(x: cx, y: y))
            p.addLine(to: CGPoint(x: cx - 3, y: y - 8))
            p.addLine(to: CGPoint(x: cx + 3, y: y - 8))
            p.addLine(to: CGPoint(x: cx, y: y))
            // Trunk
            p.move(to: CGPoint(x: cx, y: y))
            p.addLine(to: CGPoint(x: cx, y: y + 2))
        }

        // Ocean waves (bottom band) - multiple rows
        let waveY = r.minY + r.height * 0.92
        let waveAmp: CGFloat = 4
        let segments = 8
        let segW = r.width / CGFloat(segments)
        
        // First wave row
        p.move(to: CGPoint(x: r.minX, y: waveY))
        for i in 0..<segments {
            let x0 = r.minX + CGFloat(i) * segW
            let x1 = x0 + segW
            let xm = (x0 + x1) / 2
            p.addQuadCurve(to: CGPoint(x: x1, y: waveY),
                           controlPoint: CGPoint(x: xm, y: waveY + (i % 2 == 0 ? -waveAmp : waveAmp)))
        }
        
        // Second wave row (higher, smaller amplitude)
        let waveY2 = waveY - 6
        let waveAmp2: CGFloat = 2
        p.move(to: CGPoint(x: r.minX, y: waveY2))
        for i in 0..<segments {
            let x0 = r.minX + CGFloat(i) * segW
            let x1 = x0 + segW
            let xm = (x0 + x1) / 2
            p.addQuadCurve(to: CGPoint(x: x1, y: waveY2),
                           controlPoint: CGPoint(x: xm, y: waveY2 + (i % 2 == 0 ? -waveAmp2 : waveAmp2)))
        }
        
        // Third wave row (highest, smallest amplitude)
        let waveY3 = waveY2 - 4
        let waveAmp3: CGFloat = 1
        p.move(to: CGPoint(x: r.minX, y: waveY3))
        for i in 0..<segments {
            let x0 = r.minX + CGFloat(i) * segW
            let x1 = x0 + segW
            let xm = (x0 + x1) / 2
            p.addQuadCurve(to: CGPoint(x: x1, y: waveY3),
                           controlPoint: CGPoint(x: xm, y: waveY3 + (i % 2 == 0 ? -waveAmp3 : waveAmp3)))
        }

        // Territory boundary line - dotted
        let boundY = r.minY + r.height * 0.55
        let boundX0 = r.minX + r.width * 0.15
        let boundX1 = r.minX + r.width * 0.85
        let dashLength: CGFloat = 3
        let gapLength: CGFloat = 4
        var currentX = boundX0
        while currentX < boundX1 {
            p.move(to: CGPoint(x: currentX, y: boundY))
            p.addLine(to: CGPoint(x: currentX + dashLength, y: boundY))
            currentX += dashLength + gapLength
        }

        decorLayer.path = p.cgPath
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let isPad = traitCollection.horizontalSizeClass == .regular
        let panelW = isPad ? min(bounds.width - 80, 920) : min(bounds.width - 32, 380)
        let panelH = isPad ? CGFloat(560) : CGFloat(620)
        panel.frame = CGRect(x: (bounds.width - panelW) / 2,
                             y: (bounds.height - panelH) / 2,
                             width: panelW, height: panelH)

        titleLbl.frame  = CGRect(x: 0, y: 24, width: panelW, height: 32)
        statusLbl.frame = CGRect(x: 0, y: 60, width: panelW, height: 18)

        let mapPadding: CGFloat = 18
        let mapTop:     CGFloat = 88
        let mapBottom:  CGFloat = 56     // room for close button
        mapBackground.frame = CGRect(
            x: mapPadding, y: mapTop,
            width: panelW - mapPadding * 2,
            height: panelH - mapTop - mapBottom)

        let mb = mapBackground.bounds
        mapGradient.frame = mb
        vignetteLayer.path = UIBezierPath(roundedRect: mb.insetBy(dx: 2, dy: 2),
                                          cornerRadius: 14).cgPath

        // Decorations + compass (rebuild paths from current map bounds)
        updateDecorations(in: mb)
        let compassCenter = CGPoint(x: mb.maxX - 40, y: mb.minY + 40)
        updateCompassRose(center: compassCenter, radius: 18)

        // Pins: position centered on each normalized point in the map area.
        // The pin dot sits in the top portion of the hit area, so we offset
        // the view so the *dot* lands on the desired (nx, ny) coord.
        let dotInset = MapPin.hitH / 2 - (4 + MapPin.pinSize / 2)
        func placePin(_ pin: MapPin, _ p: CGPoint) {
            let x = mb.minX + mb.width  * p.x
            let y = mb.minY + mb.height * p.y + dotInset
            pin.center = CGPoint(x: x, y: y)
        }
        placePin(forestPin, forestPinPos)
        placePin(desertPin, desertPinPos)
        placePin(islandPin, islandPinPos)

        closeBtn.frame = CGRect(x: 0, y: panelH - 44, width: panelW, height: 32)
    }
}
