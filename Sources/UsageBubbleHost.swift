import AppKit
import Foundation

private let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
private let petId = ProcessInfo.processInfo.environment["CODEX_PET_ID"] ?? "your-pet-name"
private let codexHome = ProcessInfo.processInfo.environment["CODEX_HOME"] ?? "\(homeDir)/.codex"
private let overlayDir = ProcessInfo.processInfo.environment["USAGE_BUBBLE_OVERLAY_DIR"] ?? "\(codexHome)/pets/\(petId)/usage-overlay"
private let globalStatePath = "\(codexHome)/.codex-global-state.json"
private let usagePath = "\(overlayDir)/usage.json"
private let assetDir = "\(overlayDir)/assets"

private let budgetMinutes = 300.0
private let pollInterval: TimeInterval = 0.10
private let hoverPadding: CGFloat = 80
private let overlaySize = NSSize(width: 176, height: 118)
private let postDragHoldSeconds: TimeInterval = 0.8
private let logPath = "\(overlayDir)/overlay-host.log"
private let args = Set(CommandLine.arguments.dropFirst())
private let alwaysShow = args.contains("--always-show")
private let debugLogging = args.contains("--debug") || alwaysShow

private struct PetBounds {
    let window: CGRect
    let anchor: CGRect
}

private enum UsagePose: String {
    case state1 = "state1"
    case state2 = "state2"
    case state3 = "state3"
    case state4 = "state4"
    case state5 = "state5"

    static func from(percent: Int) -> UsagePose {
        if percent <= 0 { return .state5 }
        if percent < 25 { return .state4 }
        if percent < 50 { return .state3 }
        if percent < 75 { return .state2 }
        return .state1
    }
}

private final class UsageBubbleView: NSView {
    var animationFrame = 0 {
        didSet {
            needsDisplay = true
        }
    }

    var percent = 0 {
        didSet {
            if oldValue != percent {
                pose = UsagePose.from(percent: percent)
                needsDisplay = true
            }
        }
    }

    var weeklyPercent = 0 {
        didSet {
            if oldValue != weeklyPercent {
                needsDisplay = true
            }
        }
    }

    private var pose: UsagePose = .state5
    private var images: [UsagePose: NSImage] = [:]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        loadImages()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadImages()
    }

    private func loadImages() {
        for pose in [UsagePose.state1, .state2, .state3, .state4, .state5] {
            let path = "\(assetDir)/\(pose.rawValue).png"
            images[pose] = NSImage(contentsOfFile: path)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        drawBubble()
        drawBattery()
        drawCharacter()
    }

    private func drawCharacter() {
        guard let image = images[pose] else { return }

        let bubble = bubbleRect()
        let content = NSRect(x: bubble.minX + 76, y: bubble.minY + 12, width: bubble.width - 90, height: bubble.height - 24)
        let maxWidth = content.width
        let maxHeight = content.height
        let scale = min(maxWidth / image.size.width, maxHeight / image.size.height)
        let drawSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        let bob = CGFloat((animationFrame / 5) % 2)

        let x = content.midX - drawSize.width / 2
        let y = content.midY - drawSize.height / 2 - 1 + bob
        image.draw(in: NSRect(origin: NSPoint(x: x, y: y), size: drawSize),
                   from: .zero,
                   operation: .sourceOver,
                   fraction: 1,
                   respectFlipped: true,
                   hints: [.interpolation: NSImageInterpolation.none])
    }

    private func drawBubble() {
        let bubble = bubbleRect()

        NSColor.white.setFill()
        drawPixelBubbleFill(in: bubble)
        fillTailRootGap(in: bubble)

        NSColor.black.setFill()
        drawPixelBubbleBorder(in: bubble)
    }

    private func drawBattery() {
        let bubble = bubbleRect()
        drawBatteryMeter(percent: percent, at: NSPoint(x: bubble.minX + 12, y: bubble.midY + 6))
        drawBatteryMeter(percent: weeklyPercent, at: NSPoint(x: bubble.minX + 12, y: bubble.midY - 16))
    }

    private func drawBatteryMeter(percent: Int, at origin: NSPoint) {
        let body = NSRect(x: origin.x, y: origin.y, width: 27, height: 14)
        let nub = NSRect(x: body.maxX, y: body.minY + 5, width: 4, height: 5)
        let inner = body.insetBy(dx: 4, dy: 4)
        let fillWidth = max(0, inner.width * CGFloat(percent) / 100.0)

        NSColor.black.setFill()
        pixelRect(body, radius: 0).fill()
        pixelRect(nub, radius: 0).fill()

        NSColor.white.setFill()
        pixelRect(body.insetBy(dx: 2, dy: 2), radius: 0).fill()

        let fillColor: NSColor
        if percent <= 20 {
            fillColor = NSColor(calibratedRed: 0.95, green: 0.20, blue: 0.26, alpha: 1)
        } else if percent < 50 {
            fillColor = NSColor(calibratedRed: 0.98, green: 0.70, blue: 0.25, alpha: 1)
        } else {
            fillColor = NSColor(calibratedRed: 0.30, green: 0.78, blue: 0.42, alpha: 1)
        }

        fillColor.setFill()
        pixelRect(NSRect(x: inner.minX, y: inner.minY, width: fillWidth, height: inner.height), radius: 0).fill()

        let label = "\(percent)%"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .heavy),
            .foregroundColor: NSColor.black
        ]
        label.draw(at: NSPoint(x: body.maxX + 9, y: body.minY - 1), withAttributes: attrs)
    }

    private func drawThoughtPixels() {
        let phase = (animationFrame / 4) % 3
        let bubble = bubbleRect()
        let dots = [
            NSRect(x: bubble.midX - 11, y: bubble.minY - 10, width: 6, height: 6),
            NSRect(x: bubble.midX + 1, y: bubble.minY - 17, width: 5, height: 5),
            NSRect(x: bubble.midX + 12, y: bubble.minY - 22, width: 4, height: 4)
        ]

        for (index, dot) in dots.enumerated() {
            let alpha: CGFloat = index == phase ? 0.85 : 0.32
            NSColor(calibratedWhite: 0, alpha: alpha).setFill()
            pixelRect(dot, radius: 0).fill()
        }
    }

    private func bubbleRect() -> NSRect {
        NSRect(x: 12, y: 23, width: bounds.width - 24, height: bounds.height - 31)
    }

    private func drawPixelBubbleFill(in rect: NSRect) {
        let s: CGFloat = 5
        let rows = Int(rect.height / s)
        let cols = Int(rect.width / s)
        let tailTipColumn = cols / 2
        let tailBaseRow = 1

        for row in 1..<(rows - 1) {
            var start = 1
            var end = cols - 2

            if row <= 2 {
                start += 3 - row
                end -= 3 - row
            }
            if row >= rows - 2 {
                start += row - (rows - 3)
                end -= row - (rows - 3)
            }
            if row <= 3 {
                start = max(start, 4 - row)
                end = min(end, cols - 1 - (4 - row))
            }

            if row == tailBaseRow {
                end = min(end, tailTipColumn - 3)
                fillPixelRow(rect, row: row, start: start, end: end, size: s)
                fillPixelRow(rect, row: row, start: tailTipColumn + 3, end: cols - 3, size: s)
                continue
            }

            fillPixelRow(rect, row: row, start: start, end: end, size: s)
        }

        fillPixelRow(rect, row: 0, start: tailTipColumn - 2, end: tailTipColumn + 2, size: s)
        fillPixelRow(rect, row: -1, start: tailTipColumn - 1, end: tailTipColumn + 1, size: s)
        fillPixel(rect, column: tailTipColumn, row: -2, size: s)
    }

    private func fillTailRootGap(in rect: NSRect) {
        let s: CGFloat = 5
        let cols = Int(rect.width / s)
        let tailTipColumn = cols / 2

        fillPixelRow(rect, row: 0, start: tailTipColumn - 5, end: tailTipColumn + 5, size: s)
        fillPixelRow(rect, row: 1, start: tailTipColumn - 5, end: tailTipColumn + 5, size: s)
    }

    private func drawPixelBubbleBorder(in rect: NSRect) {
        let s: CGFloat = 5
        let rows = Int(rect.height / s)
        let cols = Int(rect.width / s)
        let tailTipColumn = cols / 2
        let tailBaseLeft = tailTipColumn - 3
        let tailBaseRight = tailTipColumn + 3

        fillPixelRow(rect, row: rows - 1, start: 3, end: cols - 4, size: s)
        fillPixelRow(rect, row: 0, start: 3, end: tailBaseLeft, size: s)
        fillPixelRow(rect, row: 0, start: tailBaseRight, end: cols - 4, size: s)

        fillPixel(rect, column: 0, row: rows - 4, size: s)
        fillPixel(rect, column: 1, row: rows - 3, size: s)
        fillPixel(rect, column: 2, row: rows - 2, size: s)
        fillPixel(rect, column: cols - 1, row: rows - 4, size: s)
        fillPixel(rect, column: cols - 2, row: rows - 3, size: s)
        fillPixel(rect, column: cols - 3, row: rows - 2, size: s)

        fillPixel(rect, column: 0, row: 3, size: s)
        fillPixel(rect, column: 1, row: 2, size: s)
        fillPixel(rect, column: 2, row: 1, size: s)
        fillPixel(rect, column: cols - 1, row: 3, size: s)
        fillPixel(rect, column: cols - 2, row: 2, size: s)
        fillPixel(rect, column: cols - 3, row: 1, size: s)

        for row in 3...(rows - 4) {
            fillPixel(rect, column: 0, row: row, size: s)
            fillPixel(rect, column: cols - 1, row: row, size: s)
        }

        fillPixel(rect, column: tailTipColumn - 3, row: 0, size: s)
        fillPixel(rect, column: tailTipColumn - 2, row: -1, size: s)
        fillPixel(rect, column: tailTipColumn - 1, row: -2, size: s)
        fillPixel(rect, column: tailTipColumn, row: -3, size: s)
        fillPixel(rect, column: tailTipColumn + 1, row: -2, size: s)
        fillPixel(rect, column: tailTipColumn + 2, row: -1, size: s)
        fillPixel(rect, column: tailTipColumn + 3, row: 0, size: s)
    }

    private func fillPixelRow(_ rect: NSRect, row: Int, start: Int, end: Int, size: CGFloat) {
        guard start <= end else { return }
        for column in start...end {
            fillPixel(rect, column: column, row: row, size: size)
        }
    }

    private func fillPixel(_ rect: NSRect, column: Int, row: Int, size: CGFloat) {
        pixelRect(NSRect(x: rect.minX + CGFloat(column) * size,
                         y: rect.minY + CGFloat(row) * size,
                         width: size,
                         height: size),
                  radius: 0).fill()
    }

    private func pixelRect(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
        NSBezierPath(roundedRect: rect.integral, xRadius: radius, yRadius: radius)
    }
}

private final class OverlayController {
    private let window: NSPanel
    private let overlayView: UsageBubbleView
    private var timer: Timer?
    private var lastPercent: Int?
    private var lastWeeklyPercent: Int?
    private var currentAnchor: CGRect?
    private var dragOffsetFromMouse: CGPoint?
    private var holdPositionUntil: Date?
    private var monitors: [Any] = []

    init() {
        overlayView = UsageBubbleView(frame: NSRect(origin: .zero, size: overlaySize))
        window = NSPanel(contentRect: NSRect(origin: .zero, size: overlaySize),
                         styleMask: [.borderless, .nonactivatingPanel],
                         backing: .buffered,
                         defer: false)

        window.contentView = overlayView
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.orderOut(nil)
        log("host initialized alwaysShow=\(alwaysShow)")
    }

    func start() {
        installDragMonitors()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        tick()
    }

    private func tick() {
        guard let bounds = readPetBounds() else {
            hide()
            return
        }

        let percent = readUsagePercent()
        if percent != lastPercent {
            overlayView.percent = percent
            lastPercent = percent
        }
        let weeklyPercent = readWeeklyUsagePercent()
        if weeklyPercent != lastWeeklyPercent {
            overlayView.weeklyPercent = weeklyPercent
            lastWeeklyPercent = weeklyPercent
        }
        overlayView.animationFrame += 1

        currentAnchor = bounds.anchor

        if dragOffsetFromMouse != nil {
            followMouse(NSEvent.mouseLocation)
            return
        }

        if let holdPositionUntil, Date() < holdPositionUntil {
            return
        }

        self.holdPositionUntil = nil

        let mouse = NSEvent.mouseLocation
        let hoverRect = bounds.anchor.insetBy(dx: -hoverPadding, dy: -hoverPadding)
        if alwaysShow || hoverRect.contains(mouse) {
            position(over: bounds.anchor)
            show()
        } else {
            hide()
        }
    }

    private func show() {
        if !window.isVisible {
            window.orderFrontRegardless()
            log("show percent=\(overlayView.percent)")
        }
    }

    private func hide() {
        if window.isVisible {
            window.orderOut(nil)
            log("hide")
        }
    }

    private func position(over anchor: CGRect) {
        let x = anchor.midX - overlaySize.width / 2
        let y = max(12, anchor.maxY + 10)
        window.setFrame(NSRect(x: x, y: y, width: overlaySize.width, height: overlaySize.height), display: true)
    }

    private func installDragMonitors() {
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            self?.beginDragFollow(event)
        } as Any)
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] event in
            self?.continueDragFollow(event)
        } as Any)
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            self?.endDragFollow()
        } as Any)
    }

    private func beginDragFollow(_ event: NSEvent) {
        guard let anchor = readPetBounds()?.anchor ?? currentAnchor else { return }
        currentAnchor = anchor

        let mouse = NSEvent.mouseLocation
        let hitRect = anchor.insetBy(dx: -hoverPadding, dy: -hoverPadding)
        guard alwaysShow || hitRect.contains(mouse) else { return }

        position(over: anchor)
        show()

        dragOffsetFromMouse = CGPoint(x: window.frame.midX - mouse.x, y: window.frame.midY - mouse.y)
        log("begin drag follow mouse=\(mouse) offset=\(String(describing: dragOffsetFromMouse))")
    }

    private func continueDragFollow(_ event: NSEvent) {
        followMouse(NSEvent.mouseLocation)
    }

    private func followMouse(_ mouse: CGPoint) {
        guard let offset = dragOffsetFromMouse else { return }

        let centerX = mouse.x + offset.x
        let centerY = mouse.y + offset.y
        let frame = NSRect(x: centerX - overlaySize.width / 2,
                           y: max(12, centerY - overlaySize.height / 2),
                           width: overlaySize.width,
                           height: overlaySize.height)
        window.setFrame(frame, display: true)
        show()
    }

    private func endDragFollow() {
        guard dragOffsetFromMouse != nil else { return }

        dragOffsetFromMouse = nil
        holdPositionUntil = Date().addingTimeInterval(postDragHoldSeconds)
        log("end drag follow")
    }
}

private func readPetBounds() -> PetBounds? {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: globalStatePath)) else {
        log("failed to read pet bounds: cannot read \(globalStatePath)")
        return nil
    }
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        log("failed to read pet bounds: invalid json")
        return nil
    }
    guard let raw = object["electron-avatar-overlay-bounds"] as? [String: Any] else {
        log("failed to read pet bounds: missing electron-avatar-overlay-bounds")
        return nil
    }
    guard let x = number(raw["x"]),
          let yFromTop = number(raw["y"]),
          let width = number(raw["width"]),
          let height = number(raw["height"]) else {
        log("failed to read pet bounds: bad window fields raw=\(raw)")
        return nil
    }
    guard let anchorRaw = raw["anchor"] as? [String: Any] else {
        log("failed to read pet bounds: missing anchor")
        return nil
    }
    guard let anchorX = number(anchorRaw["x"]),
          let anchorYFromTop = number(anchorRaw["y"]),
          let anchorWidth = number(anchorRaw["width"]),
          let anchorHeight = number(anchorRaw["height"]) else {
        log("failed to read pet bounds: bad anchor fields anchor=\(anchorRaw)")
        return nil
    }
    guard let screenHeight = NSScreen.main?.frame.height else {
        log("failed to read pet bounds: no main screen")
        return nil
    }

    let windowRect = CGRect(x: x, y: screenHeight - yFromTop - height, width: width, height: height)
    let anchorRect = CGRect(x: anchorX,
                            y: screenHeight - anchorYFromTop - anchorHeight,
                            width: anchorWidth,
                            height: anchorHeight)
    let bounds = PetBounds(window: windowRect, anchor: anchorRect)
    if debugLogging {
        log("bounds anchor=\(anchorRect) window=\(windowRect) mouse=\(NSEvent.mouseLocation)")
    }
    return bounds
}

private func number(_ value: Any?) -> CGFloat? {
    if let value = value as? CGFloat { return value }
    if let value = value as? Double { return CGFloat(value) }
    if let value = value as? Int { return CGFloat(value) }
    if let value = value as? NSNumber { return CGFloat(truncating: value) }
    return nil
}

private func readUsagePercent() -> Int {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: usagePath)),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return 0
    }

    if let percent = object["percent"] as? Double {
        return clampPercent(percent)
    }

    if let remainingMinutes = object["minutesRemaining"] as? Double {
        return clampPercent((remainingMinutes / budgetMinutes) * 100.0)
    }

    if let minutes = object["minutesUsed"] as? Double {
        return clampPercent(100.0 - (minutes / budgetMinutes) * 100.0)
    }

    return 0
}

private func readWeeklyUsagePercent() -> Int {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: usagePath)),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return 0
    }

    if let weeklyPercent = object["weeklyPercent"] as? Double {
        return clampPercent(weeklyPercent)
    }

    if let secondaryUsedPercent = object["secondaryUsedPercent"] as? Double {
        return clampPercent(100.0 - secondaryUsedPercent)
    }

    return 0
}

private func clampPercent(_ value: Double) -> Int {
    min(100, max(0, Int(value.rounded())))
}

private func log(_ message: String) {
    guard debugLogging else { return }
    let line = "\(Date()) \(message)\n"
    guard let data = line.data(using: .utf8) else { return }
    if FileManager.default.fileExists(atPath: logPath),
       let handle = try? FileHandle(forWritingTo: URL(fileURLWithPath: logPath)) {
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        _ = try? handle.write(contentsOf: data)
    } else {
        try? data.write(to: URL(fileURLWithPath: logPath))
    }
}

private let app = NSApplication.shared
private let controller = OverlayController()
app.setActivationPolicy(.accessory)
app.finishLaunching()
controller.start()
app.run()
