import AppKit
import ServiceManagement

// MARK: - Image loading

/// Loads jesus.png from the app bundle (or next to the binary when run via `swift run`)
/// and trims the fully transparent area so the window hugs the figure.
func loadFigure() -> NSImage? {
    var candidates: [URL] = []
    if let url = Bundle.main.url(forResource: "jesus", withExtension: "png") { candidates.append(url) }
    let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    candidates.append(cwd.appendingPathComponent("Resources/jesus.png"))

    for url in candidates {
        if let image = NSImage(contentsOf: url) { return trimTransparent(image) }
    }
    return nil
}

func trimTransparent(_ image: NSImage) -> NSImage {
    guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return image }
    let w = cg.width, h = cg.height
    var pixels = [UInt8](repeating: 0, count: w * h * 4)
    guard let ctx = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8,
                              bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

    var minX = w, minY = h, maxX = -1, maxY = -1
    for y in 0..<h {
        for x in 0..<w where pixels[(y * w + x) * 4 + 3] > 8 {
            minX = min(minX, x); maxX = max(maxX, x)
            minY = min(minY, y); maxY = max(maxY, y)
        }
    }
    guard maxX >= minX, maxY >= minY else { return image }
    let rect = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    guard let cropped = ctx.makeImage()?.cropping(to: rect) else { return image }
    return NSImage(cgImage: cropped, size: NSSize(width: rect.width, height: rect.height))
}

func mirrored(_ image: NSImage) -> NSImage {
    let out = NSImage(size: image.size)
    out.lockFocus()
    let t = NSAffineTransform()
    t.translateX(by: image.size.width, yBy: 0)
    t.scaleX(by: -1, yBy: 1)
    t.concat()
    image.draw(in: NSRect(origin: .zero, size: image.size))
    out.unlockFocus()
    return out
}

// MARK: - Peeker

enum Edge: CaseIterable { case left, right }

final class Peeker {
    private let leftImage: NSImage
    private let rightImage: NSImage
    private var window: NSWindow?
    private(set) var isPeeking = false

    init(image: NSImage) {
        leftImage = image
        rightImage = mirrored(image)
    }

    /// An edge is usable only if nothing lies beyond it — otherwise the "hidden"
    /// part of the window would land on the neighbouring monitor instead of
    /// sliding off into empty space. On a two-monitor setup this means the left
    /// screen peeks from its left and the right screen from its right.
    private func exposedCandidates() -> [(NSScreen, Edge)] {
        var result: [(NSScreen, Edge)] = []
        for screen in NSScreen.screens {
            for edge in Edge.allCases {
                let probeX = edge == .left ? screen.frame.minX - 5 : screen.frame.maxX + 5
                let probe = CGRect(x: probeX, y: screen.frame.minY, width: 1, height: screen.frame.height)
                let blocked = NSScreen.screens.contains { $0 !== screen && $0.frame.intersects(probe) }
                if !blocked { result.append((screen, edge)) }
            }
        }
        return result
    }

    func peek() {
        guard !isPeeking else { return }
        let candidates = exposedCandidates()
        guard let (screen, edge) = candidates.randomElement() else { return }
        isPeeking = true

        let image = edge == .left ? leftImage : rightImage
        let visible = screen.visibleFrame

        // Height: 45–70% of the screen, keeping the image's aspect ratio.
        let height = visible.height * CGFloat.random(in: 0.45...0.70)
        let width = height * image.size.width / image.size.height
        let y = visible.minY + CGFloat.random(in: 0...(visible.height - height))

        // How much of him comes out: a shy peek or a full lean.
        let reveal = width * CGFloat.random(in: 0.55...1.0)

        let hiddenX: CGFloat, shownX: CGFloat
        switch edge {
        case .left:
            hiddenX = screen.frame.minX - width
            shownX = screen.frame.minX - width + reveal
        case .right:
            hiddenX = screen.frame.maxX
            shownX = screen.frame.maxX - reveal
        }

        let win = NSWindow(contentRect: NSRect(x: hiddenX, y: y, width: width, height: height),
                           styleMask: .borderless, backing: .buffered, defer: false)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.ignoresMouseEvents = true
        win.level = .screenSaver
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        win.isReleasedWhenClosed = false

        let view = NSImageView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        view.image = image
        view.imageScaling = .scaleProportionallyUpOrDown
        win.contentView = view
        win.orderFrontRegardless()
        window = win

        let hold = Double.random(in: 1.5...3.5)
        slide(win, toX: shownX, duration: 0.9) {
            DispatchQueue.main.asyncAfter(deadline: .now() + hold) {
                self.slide(win, toX: hiddenX, duration: 0.6) {
                    win.orderOut(nil)
                    self.window = nil
                    self.isPeeking = false
                }
            }
        }
    }

    private func slide(_ win: NSWindow, toX x: CGFloat, duration: TimeInterval, completion: @escaping () -> Void) {
        var frame = win.frame
        frame.origin.x = x
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            win.animator().setFrame(frame, display: true)
        }, completionHandler: completion)
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var peeker: Peeker!
    private var timer: Timer?
    private var paused = false

    /// Interval range in minutes. A random delay in this range is picked before each visit.
    private let intervals: [(String, ClosedRange<Double>)] = [
        ("Every ~1 minute (testing)", 0.5...1.5),
        ("Every 2–5 minutes", 2...5),
        ("Every 5–10 minutes", 5...10),
        ("Every 15–30 minutes", 15...30),
    ]
    private var intervalIndex: Int {
        get { UserDefaults.standard.object(forKey: "intervalIndex") as? Int ?? 1 }
        set { UserDefaults.standard.set(newValue, forKey: "intervalIndex") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let image = loadFigure() else {
            let alert = NSAlert()
            alert.messageText = "jesus.png not found"
            alert.informativeText = "Put jesus.png in the app's Resources folder."
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        peeker = Peeker(image: image)

        // Stealth by default: no menu bar icon. Set DI_SHOW_ICON=1 to show it
        // (handy for testing — it gives you Pause, intervals, and Quit).
        if ProcessInfo.processInfo.environment["DI_SHOW_ICON"] == "1" {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            statusItem.button?.title = "✝︎"
            rebuildMenu()
        }
        scheduleNext()
    }

    private func scheduleNext() {
        timer?.invalidate()
        guard !paused else { return }
        let minutes = Double.random(in: intervals[intervalIndex].1)
        timer = Timer.scheduledTimer(withTimeInterval: minutes * 60, repeats: false) { [weak self] _ in
            self?.peeker.peek()
            self?.scheduleNext()
        }
    }

    private func rebuildMenu() {
        guard statusItem != nil else { return }
        let menu = NSMenu()
        menu.addItem(withTitle: "Peek Now", action: #selector(peekNow), keyEquivalent: "p").target = self
        let pauseItem = menu.addItem(withTitle: paused ? "Resume" : "Pause",
                                     action: #selector(togglePause), keyEquivalent: "")
        pauseItem.target = self
        menu.addItem(.separator())

        for (i, (title, _)) in intervals.enumerated() {
            let item = menu.addItem(withTitle: title, action: #selector(setInterval(_:)), keyEquivalent: "")
            item.target = self
            item.tag = i
            item.state = i == intervalIndex ? .on : .off
        }
        menu.addItem(.separator())

        let login = menu.addItem(withTitle: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
    }

    @objc private func peekNow() { peeker.peek() }

    @objc private func togglePause() {
        paused.toggle()
        scheduleNext()
        rebuildMenu()
    }

    @objc private func setInterval(_ sender: NSMenuItem) {
        intervalIndex = sender.tag
        scheduleNext()
        rebuildMenu()
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change login item"
            alert.informativeText = "\(error.localizedDescription)\n\nThis only works when running the bundled .app (scripts/build-app.sh)."
            alert.runModal()
        }
        rebuildMenu()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // no Dock icon, just a menu bar item
app.run()
