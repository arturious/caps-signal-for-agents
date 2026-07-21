import Cocoa

private let stateNotificationName = Notification.Name("com.arturious.capsig.state")

/// Anthropic/Claude's brand orange (terracotta), #DA7756.
private let claudeOrange = NSColor(red: 0xDA / 255, green: 0x77 / 255, blue: 0x56 / 255, alpha: 1)

enum OverlayState: String {
    case idle, working, done, attention
}

/// Broadcasts a state change to any running `capsig overlay` process.
/// Cross-process, no shared file/socket needed.
func postOverlayState(_ state: OverlayState) {
    DistributedNotificationCenter.default().postNotificationName(
        stateNotificationName, object: nil,
        userInfo: ["state": state.rawValue], deliverImmediately: true
    )
}

/// A small borderless dot pinned to the top-right corner, kept visible even
/// over fullscreen apps via `.fullScreenAuxiliary` (the same mechanism
/// Spotlight/Notification Center use).
private final class Dot: NSWindow {
    private let diameter: CGFloat = 7
    private let circle = NSView()

    init() {
        let screen = NSScreen.main?.frame ?? .zero
        let origin = NSPoint(x: screen.maxX - diameter - 10, y: screen.maxY - diameter - 6)
        super.init(
            contentRect: NSRect(origin: origin, size: NSSize(width: diameter, height: diameter)),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        circle.wantsLayer = true
        circle.layer?.cornerRadius = diameter / 2
        circle.layer?.backgroundColor = claudeOrange.cgColor
        circle.frame = NSRect(origin: .zero, size: NSSize(width: diameter, height: diameter))

        let content = NSView(frame: NSRect(origin: .zero, size: NSSize(width: diameter, height: diameter)))
        content.addSubview(circle)
        contentView = content

        alphaValue = 0
        orderFrontRegardless()
    }
}

private final class OverlayController {
    private let dot = Dot()
    private var timer: Timer?
    private var pendingWork: [DispatchWorkItem] = []

    func apply(_ state: OverlayState) {
        timer?.invalidate()
        timer = nil
        pendingWork.forEach { $0.cancel() }
        pendingWork.removeAll()

        switch state {
        case .idle:
            dot.alphaValue = 0

        case .working:
            dot.alphaValue = 1
            var visible = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.375, repeats: true) { [weak self] _ in
                visible.toggle()
                self?.dot.alphaValue = visible ? 1 : 0
            }

        case .done:
            schedule([(0.12, true), (0.12, false), (0.12, true), (0.12, false), (0.5, true)])

        case .attention:
            schedule([
                (0.08, true), (0.08, false), (0.08, true), (0.08, false), (0.08, true),
                (0.08, false), (0.08, true), (0.08, false), (0.08, true), (0.08, false),
            ])
        }
    }

    /// Runs a sequence of (duration, visible) steps, then hides the dot.
    private func schedule(_ pattern: [(TimeInterval, Bool)]) {
        var delay: TimeInterval = 0
        for (duration, visible) in pattern {
            let step = DispatchWorkItem { [weak self] in self?.dot.alphaValue = visible ? 1 : 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: step)
            pendingWork.append(step)
            delay += duration
        }
        let hide = DispatchWorkItem { [weak self] in self?.dot.alphaValue = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: hide)
        pendingWork.append(hide)
    }
}

/// Runs the persistent overlay process. Blocks forever (AppKit run loop);
/// only killed via `capsig overlay-stop` or logout.
func runOverlayApp() {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory) // no Dock icon, no menu bar item

    let controller = OverlayController()
    DistributedNotificationCenter.default().addObserver(
        forName: stateNotificationName, object: nil, queue: .main
    ) { note in
        guard let raw = note.userInfo?["state"] as? String,
              let state = OverlayState(rawValue: raw)
        else { return }
        controller.apply(state)
    }

    app.run()
}
