import Cocoa

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

protocol SelectionDisplaying: AnyObject {
    var closeRect: CGRect? { get }
    func show(frame: CGRect, closeButton: Bool, selectable: Bool, title: String)
    func hide()
}

final class SelectionOverlay: SelectionDisplaying {
    private let panel: OverlayPanel
    private let decoration = SelectionDecoration()
    private(set) var closeRect: CGRect?

    init() {
        panel = OverlayPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.ignoresMouseEvents = true; panel.hidesOnDeactivate = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = decoration
        panel.isReleasedWhenClosed = false
    }

    func show(frame: CGRect, closeButton: Bool, selectable: Bool, title: String) {
        guard frame.width > 4, frame.height > 4 else { hide(); return }
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let cocoa = WindowNavigation.cocoaFrame(frame, primaryScreenHeight: primaryHeight)
        let margin: CGFloat = 14
        panel.setFrame(cocoa.insetBy(dx: -margin, dy: -margin), display: false)
        decoration.closeButton = closeButton; decoration.ring = selectable
        decoration.needsDisplay = true
        closeRect = closeButton ? CGRect(x: frame.minX - 10, y: frame.minY - 10, width: 28, height: 28) : nil
        panel.orderFrontRegardless()
    }

    func hide() { closeRect = nil; panel.orderOut(nil) }
}

final class SelectionDecoration: NSView {
    var closeButton = true
    var ring = true
    override func draw(_ dirtyRect: NSRect) {
        let content = bounds.insetBy(dx: 14, dy: 14)
        if ring {
            NSColor(calibratedRed: 0.58, green: 0.43, blue: 1, alpha: 0.95).setStroke()
            let path = NSBezierPath(roundedRect: content.insetBy(dx: -2, dy: -2), xRadius: 10, yRadius: 10)
            path.lineWidth = 3; path.stroke()
        }
        if closeButton {
            let circle = NSRect(x: 4, y: bounds.height - 32, width: 28, height: 28)
            NSColor(calibratedWhite: 0.12, alpha: 0.96).setFill()
            NSBezierPath(ovalIn: circle).fill()
            NSColor.white.withAlphaComponent(0.8).setStroke()
            let border = NSBezierPath(ovalIn: circle.insetBy(dx: 0.5, dy: 0.5)); border.lineWidth = 1; border.stroke()
            let cross = NSBezierPath()
            cross.move(to: CGPoint(x: circle.midX - 4, y: circle.midY - 4)); cross.line(to: CGPoint(x: circle.midX + 4, y: circle.midY + 4))
            cross.move(to: CGPoint(x: circle.midX - 4, y: circle.midY + 4)); cross.line(to: CGPoint(x: circle.midX + 4, y: circle.midY - 4))
            cross.lineWidth = 1.8; cross.lineCapStyle = .round; cross.stroke()
        }
    }
}
