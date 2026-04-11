import AppKit

class FloatingIndicator: NSWindow {
    private var indicatorView: IndicatorView!
    private var isDragging = false
    private var didDrag = false
    private var dragOffset = NSPoint.zero
    var onTap: (() -> Void)?

    init() {
        let size: CGFloat = 36
        let frame = NSRect(x: 100, y: 300, width: size, height: size)
        super.init(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)

        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.isMovableByWindowBackground = false
        self.ignoresMouseEvents = false

        indicatorView = IndicatorView(frame: NSRect(origin: .zero, size: frame.size))
        self.contentView = indicatorView

        if let x = UserDefaults.standard.object(forKey: "floatingIndicatorX") as? CGFloat,
           let y = UserDefaults.standard.object(forKey: "floatingIndicatorY") as? CGFloat {
            self.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    func setState(_ state: IndicatorState) {
        indicatorView.setState(state)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        isDragging = true
        didDrag = false
        let windowFrame = self.frame
        let mouseLocation = NSEvent.mouseLocation
        dragOffset = NSPoint(
            x: mouseLocation.x - windowFrame.origin.x,
            y: mouseLocation.y - windowFrame.origin.y
        )
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        didDrag = true
        let mouseLocation = NSEvent.mouseLocation
        let newOrigin = NSPoint(
            x: mouseLocation.x - dragOffset.x,
            y: mouseLocation.y - dragOffset.y
        )
        self.setFrameOrigin(newOrigin)
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        if didDrag {
            let origin = self.frame.origin
            UserDefaults.standard.set(origin.x, forKey: "floatingIndicatorX")
            UserDefaults.standard.set(origin.y, forKey: "floatingIndicatorY")
        } else {
            onTap?()
        }
    }
}

enum IndicatorState {
    case idle
    case recording
    case transcribing
}

class IndicatorView: NSView {
    private var state: IndicatorState = .idle
    private var animationTimer: Timer?
    private var animationPhase: Double = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.3
        layer?.shadowOffset = CGSize(width: 0, height: -1)
        layer?.shadowRadius = 8
    }

    required init?(coder: NSCoder) { fatalError() }

    func setState(_ newState: IndicatorState) {
        let wasAnimating = state == .recording || state == .transcribing
        state = newState

        if state == .recording || state == .transcribing {
            if !wasAnimating { startAnimation() }
        } else {
            stopAnimation()
        }
        needsDisplay = true
    }

    private func startAnimation() {
        animationPhase = 0
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.animationPhase += 1.0 / 60.0
            self.needsDisplay = true
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.cgContext.setShouldAntialias(true)

        let rect = bounds
        let diameter = min(rect.width, rect.height) - 4
        let circleRect = NSRect(
            x: (rect.width - diameter) / 2,
            y: (rect.height - diameter) / 2,
            width: diameter,
            height: diameter
        )
        let centerX = rect.midX
        let centerY = rect.midY

        switch state {
        case .idle:
            drawIdleState(circleRect: circleRect, centerX: centerX, centerY: centerY)
        case .recording:
            drawRecordingState(circleRect: circleRect, centerX: centerX, centerY: centerY)
        case .transcribing:
            drawTranscribingState(circleRect: circleRect, centerX: centerX, centerY: centerY)
        }
    }

    // MARK: - Idle: frosted dark circle with thin mic outline

    private func drawIdleState(circleRect: NSRect, centerX: CGFloat, centerY: CGFloat) {
        let bg = NSBezierPath(ovalIn: circleRect)
        NSColor(white: 0.12, alpha: 0.92).setFill()
        bg.fill()

        // Subtle border
        NSColor.white.withAlphaComponent(0.08).setStroke()
        bg.lineWidth = 0.5
        bg.stroke()

        // Minimal mic icon
        NSColor.white.withAlphaComponent(0.7).setStroke()

        // Mic capsule
        let capW: CGFloat = 6
        let capH: CGFloat = 10
        let capRect = NSRect(x: centerX - capW / 2, y: centerY - 1, width: capW, height: capH)
        let capsule = NSBezierPath(roundedRect: capRect, xRadius: capW / 2, yRadius: capW / 2)
        capsule.lineWidth = 1.2
        capsule.stroke()

        // Arc
        let arc = NSBezierPath()
        arc.appendArc(withCenter: NSPoint(x: centerX, y: centerY + 2), radius: 6, startAngle: 210, endAngle: 330)
        arc.lineWidth = 1.2
        arc.lineCapStyle = .round
        arc.stroke()

        // Stem + base
        let stem = NSBezierPath()
        stem.move(to: NSPoint(x: centerX, y: centerY - 4))
        stem.line(to: NSPoint(x: centerX, y: centerY - 7))
        stem.lineWidth = 1.2
        stem.lineCapStyle = .round
        stem.stroke()

        let base = NSBezierPath()
        base.move(to: NSPoint(x: centerX - 3.5, y: centerY - 7))
        base.line(to: NSPoint(x: centerX + 3.5, y: centerY - 7))
        base.lineWidth = 1.2
        base.lineCapStyle = .round
        base.stroke()
    }

    // MARK: - Recording: pulsing rings + sound wave bars

    private func drawRecordingState(circleRect: NSRect, centerX: CGFloat, centerY: CGFloat) {
        let t = animationPhase

        // Outer pulse rings (radiating outward)
        for i in 0..<3 {
            let ringPhase = (t * 1.2 + Double(i) * 0.33).truncatingRemainder(dividingBy: 1.0)
            let ringScale = CGFloat(1.0 + ringPhase * 0.4)
            let ringAlpha = CGFloat((1.0 - ringPhase) * 0.15)

            if ringAlpha > 0.01 {
                let ringSize = circleRect.width * ringScale
                let ringRect = NSRect(
                    x: centerX - ringSize / 2,
                    y: centerY - ringSize / 2,
                    width: ringSize,
                    height: ringSize
                )
                NSColor(red: 1.0, green: 0.3, blue: 0.3, alpha: ringAlpha).setFill()
                NSBezierPath(ovalIn: ringRect).fill()
            }
        }

        // Main circle
        let bg = NSBezierPath(ovalIn: circleRect)
        NSColor(red: 0.95, green: 0.25, blue: 0.25, alpha: 0.95).setFill()
        bg.fill()

        // Inner glow
        let glowPulse = CGFloat(0.08 + 0.04 * sin(t * 4.0))
        NSColor.white.withAlphaComponent(glowPulse).setFill()
        NSBezierPath(ovalIn: circleRect.insetBy(dx: 2, dy: 2)).fill()

        // Sound wave bars (5 bars, center-aligned, animated heights)
        let barCount = 5
        let barWidth: CGFloat = 2.4
        let barGap: CGFloat = 2.8
        let totalBarWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barGap
        let barStartX = centerX - totalBarWidth / 2
        let maxBarH: CGFloat = 16
        let minBarH: CGFloat = 3

        NSColor.white.setFill()

        for i in 0..<barCount {
            let phaseOffset = Double(i) * 0.18
            let wave1 = sin((t * 3.5) + phaseOffset * 5.0)
            let wave2 = sin((t * 5.8) + phaseOffset * 3.0) * 0.4
            let combined = (wave1 + wave2) / 1.4
            let normalized = CGFloat((combined + 1.0) / 2.0)
            let barH = minBarH + (maxBarH - minBarH) * normalized

            let x = barStartX + CGFloat(i) * (barWidth + barGap)
            let y = centerY - barH / 2
            let barRect = NSRect(x: x, y: y, width: barWidth, height: barH)
            NSBezierPath(roundedRect: barRect, xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
        }
    }

    // MARK: - Transcribing: smooth morphing dots

    private func drawTranscribingState(circleRect: NSRect, centerX: CGFloat, centerY: CGFloat) {
        let bg = NSBezierPath(ovalIn: circleRect)
        NSColor(white: 0.12, alpha: 0.92).setFill()
        bg.fill()

        NSColor.white.withAlphaComponent(0.08).setStroke()
        bg.lineWidth = 0.5
        bg.stroke()

        // Three dots with staggered smooth bounce
        let dotSize: CGFloat = 4.5
        let gap: CGFloat = 7
        let totalWidth = 3 * dotSize + 2 * gap
        let startX = centerX - totalWidth / 2 + dotSize / 2

        for i in 0..<3 {
            let phase = animationPhase * 2.5 - Double(i) * 0.3
            let bounce = CGFloat(max(0, sin(phase))) * 6
            let scale = 1.0 + CGFloat(max(0, sin(phase))) * 0.3
            let alpha = CGFloat(0.4 + 0.6 * max(0, sin(phase)))

            let x = startX + CGFloat(i) * (dotSize + gap)
            let y = centerY + bounce - 3
            let s = dotSize * scale

            NSColor.white.withAlphaComponent(alpha).setFill()
            NSBezierPath(ovalIn: NSRect(x: x - s / 2, y: y - s / 2, width: s, height: s)).fill()
        }
    }
}
