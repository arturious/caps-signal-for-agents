import Cocoa

private let stateNotificationName = Notification.Name("com.arturious.agent-signal.state")

/// Anthropic/Claude's brand orange (terracotta), #DA7756.
private let claudeOrange = NSColor(red: 0xDA / 255, green: 0x77 / 255, blue: 0x56 / 255, alpha: 1)

/// Cosmetic stand-in for Claude Code's own spinner glyph animation — not a
/// byte-for-byte replica (that logic isn't exposed anywhere), just a
/// similarly styled rotating asterisk in the same color.
private let spinnerGlyphs = ["✶", "✳", "✻", "✽"]

enum OverlayState: String {
    case idle, working, done, attention
}

/// Broadcasts a state change to any running `agent-signal overlay` process.
/// Cross-process, no shared file/socket needed.
func postOverlayState(_ state: OverlayState) {
    DistributedNotificationCenter.default().postNotificationName(
        stateNotificationName, object: nil,
        userInfo: ["state": state.rawValue], deliverImmediately: true
    )
}

/// A small borderless label pinned to the top-right corner, kept visible
/// even over fullscreen apps via `.fullScreenAuxiliary` (the same mechanism
/// Spotlight/Notification Center use).
private final class SpinnerLabel: NSWindow {
    private let label = NSTextField(labelWithString: "")

    init() {
        let size = NSSize(width: 260, height: 20)
        let mainScreen = NSScreen.main
        let screen = mainScreen?.frame ?? .zero
        // Sit just to the right of the camera notch on notched MacBooks;
        // falls back to the far-right corner on screens without one.
        let x: CGFloat
        if let notchRightEdge = mainScreen?.auxiliaryTopRightArea?.minX {
            x = notchRightEdge + 8
        } else {
            x = screen.maxX - size.width - 10
        }
        let origin = NSPoint(x: x, y: screen.maxY - size.height - 4)
        super.init(
            contentRect: NSRect(origin: origin, size: size),
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

        label.font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        label.textColor = claudeOrange
        label.alignment = .left
        label.frame = NSRect(origin: .zero, size: size)
        label.autoresizingMask = [.width, .height]

        let content = NSView(frame: NSRect(origin: .zero, size: size))
        content.addSubview(label)
        contentView = content

        alphaValue = 0
        orderFrontRegardless()
    }

    func setText(_ text: String) {
        label.stringValue = text
    }
}

private final class OverlayController {
    private let view = SpinnerLabel()
    private var timer: Timer?
    private var pendingWork: [DispatchWorkItem] = []

    func apply(_ state: OverlayState) {
        timer?.invalidate()
        timer = nil
        pendingWork.forEach { $0.cancel() }
        pendingWork.removeAll()

        switch state {
        case .idle:
            view.alphaValue = 0

        case .working:
            view.alphaValue = 1
            var glyphIndex = 0
            var word = spinnerWords.randomElement() ?? "Working"
            var tick = 0
            view.setText("\(spinnerGlyphs[glyphIndex]) \(word)…")
            timer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
                glyphIndex = (glyphIndex + 1) % spinnerGlyphs.count
                tick += 1
                if tick % 15 == 0 { // change word every ~1.8s
                    word = spinnerWords.randomElement() ?? word
                }
                self?.view.setText("\(spinnerGlyphs[glyphIndex]) \(word)…")
            }
            // Safety net: if no further state update ever arrives (e.g. the
            // "Stop" hook doesn't fire), don't spin forever.
            let timeout = DispatchWorkItem { [weak self] in
                self?.timer?.invalidate()
                self?.timer = nil
                self?.view.alphaValue = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 300, execute: timeout)
            pendingWork.append(timeout)

        case .done:
            view.setText("✓ Done")
            schedule([(0.12, true), (0.12, false), (0.12, true), (0.12, false), (0.5, true)])

        case .attention:
            view.setText("✳ Needs attention")
            schedule([
                (0.08, true), (0.08, false), (0.08, true), (0.08, false), (0.08, true),
                (0.08, false), (0.08, true), (0.08, false), (0.08, true), (0.08, false),
            ])
        }
    }

    /// Runs a sequence of (duration, visible) steps, then hides the label.
    private func schedule(_ pattern: [(TimeInterval, Bool)]) {
        var delay: TimeInterval = 0
        for (duration, visible) in pattern {
            let step = DispatchWorkItem { [weak self] in self?.view.alphaValue = visible ? 1 : 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: step)
            pendingWork.append(step)
            delay += duration
        }
        let hide = DispatchWorkItem { [weak self] in self?.view.alphaValue = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: hide)
        pendingWork.append(hide)
    }
}

/// Runs the persistent overlay process. Blocks forever (AppKit run loop);
/// only killed via `agent-signal overlay-stop` or logout.
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
