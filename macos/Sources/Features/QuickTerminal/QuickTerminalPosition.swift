import Cocoa

enum QuickTerminalPosition : String {
    case top
    case bottom
    case left
    case right
    case center

    /// Set the loaded state for a window. This should only be called when the window is first loaded,
    /// usually in `windowDidLoad` or in a similar callback. This is the initial state.
    func setLoaded(_ window: NSWindow, size: QuickTerminalSize) {
        guard let screen = window.screen ?? NSScreen.main else { return }
        window.setFrame(.init(
            origin: window.frame.origin,
            size: size.calculate(position: self, screenDimensions: screen.visibleFrame.size)
        ), display: false)
    }

    /// Set the initial state for a window NOT yet into position (either before animating in or
    /// after animating out).
    func setInitial(
        in window: NSWindow,
        on screen: NSScreen,
        terminalSize: QuickTerminalSize,
        closedFrame: NSRect? = nil
    ) {
        // Invisible
        window.alphaValue = 0

        // Position depends
        window.setFrame(.init(
            origin: initialOrigin(for: window, on: screen),
            size: closedFrame?.size ?? configuredFrameSize(
                on: screen,
                terminalSize: terminalSize)
        ), display: false)
    }

    /// Set the final state for a window in this position.
    func setFinal(
        in window: NSWindow,
        on screen: NSScreen,
        terminalSize: QuickTerminalSize,
        closedFrame: NSRect? = nil
    ) {
        // We always end visible
        window.alphaValue = 1

        // Position depends
        window.setFrame(.init(
            origin: finalOrigin(for: window, on: screen),
            size: closedFrame?.size ?? configuredFrameSize(
                on: screen,
                terminalSize: terminalSize)
        ), display: true)
    }

    /// Get the configured frame size for initial positioning and animations.
    func configuredFrameSize(on screen: NSScreen, terminalSize: QuickTerminalSize) -> NSSize {
        let dimensions = terminalSize.calculate(position: self, screenDimensions: screen.visibleFrame.size)
        return NSSize(width: dimensions.width, height: dimensions.height)
    }

    /// The initial point origin for this position.
    func initialOrigin(for window: NSWindow, on screen: NSScreen) -> CGPoint {
        switch (self) {
        case .top:
            return .init(
                x: round(screen.visibleFrame.origin.x + (screen.visibleFrame.width - window.frame.width) / 2),
                y: screen.visibleFrame.maxY)

        case .bottom:
            return .init(
                x: round(screen.visibleFrame.origin.x + (screen.visibleFrame.width - window.frame.width) / 2),
                y: -window.frame.height)

        case .left:
            return .init(
                x: screen.visibleFrame.minX-window.frame.width,
                y: round(screen.visibleFrame.origin.y + (screen.visibleFrame.height - window.frame.height) / 2))

        case .right:
            return .init(
                x: screen.visibleFrame.maxX,
                y: round(screen.visibleFrame.origin.y + (screen.visibleFrame.height - window.frame.height) / 2))

        case .center:
            return .init(x: round(screen.visibleFrame.origin.x + (screen.visibleFrame.width - window.frame.width) / 2), y:  screen.visibleFrame.height - window.frame.width)
        }
    }

    /// The final point origin for this position.
    func finalOrigin(for window: NSWindow, on screen: NSScreen) -> CGPoint {
        switch (self) {
        case .top:
            return .init(
                x: round(screen.visibleFrame.origin.x + (screen.visibleFrame.width - window.frame.width) / 2),
                y: screen.visibleFrame.maxY - window.frame.height)

        case .bottom:
            return .init(
                x: round(screen.visibleFrame.origin.x + (screen.visibleFrame.width - window.frame.width) / 2),
                y: screen.visibleFrame.minY)

        case .left:
            return .init(
                x: screen.visibleFrame.minX,
                y: round(screen.visibleFrame.origin.y + (screen.visibleFrame.height - window.frame.height) / 2))

        case .right:
            return .init(
                x: screen.visibleFrame.maxX - window.frame.width,
                y: round(screen.visibleFrame.origin.y + (screen.visibleFrame.height - window.frame.height) / 2))

        case .center:
            return .init(x: round(screen.visibleFrame.origin.x + (screen.visibleFrame.width - window.frame.width) / 2), y: round(screen.visibleFrame.origin.y + (screen.visibleFrame.height - window.frame.height) / 2))
        }
    }

    func conflictsWithDock(on screen: NSScreen) -> Bool {
        // Screen must have a dock for it to conflict
        guard screen.hasDock else { return false }

        // Get the dock orientation for this screen
        guard let orientation = Dock.orientation else { return false }

        // Depending on the orientation of the dock, we conflict if our quick terminal
        // would potentially "hit" the dock. In the future we should probably consider
        // the frame of the quick terminal.
        return switch (orientation) {
        case .top: self == .top || self == .left || self == .right
        case .bottom: self == .bottom || self == .left || self == .right
        case .left: self == .top || self == .bottom
        case .right: self == .top || self == .bottom
        }
    }

    /// Calculate the centered origin for a window, keeping it properly positioned after manual resizing
    func centeredOrigin(for window: NSWindow, on screen: NSScreen) -> CGPoint {
        switch self {
        case .top:
            return CGPoint(
                x: round(screen.visibleFrame.origin.x + (screen.visibleFrame.width - window.frame.width) / 2),
                y: window.frame.origin.y // Keep the same Y position
            )
            
        case .bottom:
            return CGPoint(
                x: round(screen.visibleFrame.origin.x + (screen.visibleFrame.width - window.frame.width) / 2),
                y: window.frame.origin.y // Keep the same Y position
            )
            
        case .center:
            return CGPoint(
                x: round(screen.visibleFrame.origin.x + (screen.visibleFrame.width - window.frame.width) / 2),
                y: round(screen.visibleFrame.origin.y + (screen.visibleFrame.height - window.frame.height) / 2)
            )
            
        case .left, .right:
            // For left/right positions, only adjust horizontal centering if needed
            return window.frame.origin
        }
    }
    
    /// Calculate the vertically centered origin for side-positioned windows
    func verticallyCenteredOrigin(for window: NSWindow, on screen: NSScreen) -> CGPoint {
        switch self {
        case .left:
            return CGPoint(
                x: window.frame.origin.x, // Keep the same X position
                y: round(screen.visibleFrame.origin.y + (screen.visibleFrame.height - window.frame.height) / 2)
            )
            
        case .right:
            return CGPoint(
                x: window.frame.origin.x, // Keep the same X position
                y: round(screen.visibleFrame.origin.y + (screen.visibleFrame.height - window.frame.height) / 2)
            )
            
        case .top, .bottom, .center:
            // These positions don't need vertical recentering during resize
            return window.frame.origin
        }
    }
}

extension QuickTerminalPosition {
    private var savedDeltaXKey: String { "QuickTerminalDeltaX_\(rawValue)" }
    private var savedDeltaYKey: String { "QuickTerminalDeltaY_\(rawValue)" }
    private var savedWidthKey: String { "QuickTerminalSavedWidth_\(rawValue)" }
    private var savedHeightKey: String { "QuickTerminalSavedHeight_\(rawValue)" }
    
    func saveCurrentFrame(_ window: NSWindow) {
        guard let screen = window.screen else { return }
        let defaultOrigin = finalOrigin(for: window, on: screen)
        let deltaX = window.frame.origin.x - defaultOrigin.x
        let deltaY = window.frame.origin.y - defaultOrigin.y
        UserDefaults.standard.set(deltaX, forKey: savedDeltaXKey)
        UserDefaults.standard.set(deltaY, forKey: savedDeltaYKey)
        UserDefaults.standard.set(window.frame.size.width, forKey: savedWidthKey)
        UserDefaults.standard.set(window.frame.size.height, forKey: savedHeightKey)
    }
    
    private func loadSaved(on screen: NSScreen) -> (deltaX: CGFloat, deltaY: CGFloat, size: NSSize)? {
        guard let dx = UserDefaults.standard.object(forKey: savedDeltaXKey) as? CGFloat,
              let dy = UserDefaults.standard.object(forKey: savedDeltaYKey) as? CGFloat,
              let w = UserDefaults.standard.object(forKey: savedWidthKey) as? CGFloat,
              let h = UserDefaults.standard.object(forKey: savedHeightKey) as? CGFloat else { return nil }
        return (dx, dy, NSSize(width: w, height: h))
    }
    
    func hasCustomDelta() -> Bool {
        guard let dx = UserDefaults.standard.object(forKey: savedDeltaXKey) as? CGFloat,
              let dy = UserDefaults.standard.object(forKey: savedDeltaYKey) as? CGFloat else { return false }
        return dx != 0 || dy != 0
    }
    
    func setInitialPatched(in window: NSWindow, on screen: NSScreen, terminalSize: QuickTerminalSize) {
        window.alphaValue = 0
        let saved = loadSaved(on: screen)
        let useSize = saved?.size ?? configuredFrameSize(on: screen, terminalSize: terminalSize)
        window.setFrame(NSRect(origin: window.frame.origin, size: useSize), display: false) // Temp size for calc
        let origin = initialOrigin(for: window, on: screen)
        window.setFrame(NSRect(origin: origin, size: useSize), display: false)
    }
    
    func setFinalPatched(in window: NSWindow, on screen: NSScreen, terminalSize: QuickTerminalSize) {
        window.alphaValue = 1
        let saved = loadSaved(on: screen)
        let useSize = saved?.size ?? configuredFrameSize(on: screen, terminalSize: terminalSize)
        window.setFrame(NSRect(origin: window.frame.origin, size: useSize), display: false) // Temp size
        let defaultOrigin = finalOrigin(for: window, on: screen)
        let origin = saved != nil ? CGPoint(x: defaultOrigin.x + saved!.deltaX, y: defaultOrigin.y + saved!.deltaY) : defaultOrigin
        window.setFrame(NSRect(origin: origin, size: useSize), display: true)
    }
}
