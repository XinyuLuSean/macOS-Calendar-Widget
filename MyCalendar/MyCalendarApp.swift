import SwiftUI
import AppKit
import Combine

@main
struct MyCalendarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { SettingsView() }
    }
}

private struct SettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("My Calendar Widget").font(.title3)
            Text("Use the gear icon in the widget window to configure Launch at Login and window float behavior.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(width: 420)
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Shared view-model — AppDelegate owns it so it can observe changes.
    let viewModel = WidgetViewModel()

    private(set) var mainWindow: WidgetWindow?
    private var hostingView: NSHostingView<ContentView>?
    private var cancellables = Set<AnyCancellable>()

    // Drag-to-move state
    private var dragStartMouse:  NSPoint = .zero
    private var dragStartOrigin: NSPoint = .zero
    private var skipDrag = false

    private let defaultWidth:    CGFloat = 360
    private let minWindowHeight: CGFloat = 260

    func applicationDidFinishLaunching(_ notification: Notification) {
        let rect = NSRect(x: 0, y: 0, width: defaultWidth, height: 380)

        // Blur lives at the AppKit level — never competes with SwiftUI hit-testing.
        let effectView = RoundedVisualEffectView(frame: rect)
        effectView.material     = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state        = .active

        let hv = NSHostingView(rootView: ContentView(viewModel: viewModel))
        hv.frame              = effectView.bounds
        hv.autoresizingMask   = [.width, .height]
        effectView.addSubview(hv)
        hostingView = hv

        let window = WidgetWindow(
            contentRect: rect,
            styleMask:   [.borderless, .fullSizeContentView],
            backing:     .buffered,
            defer:       false
        )
        window.contentView   = effectView
        window.isOpaque      = false
        window.backgroundColor = .clear
        window.hasShadow     = true
        window.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        window.level = viewModel.floatOnTop ? .floating : .normal
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        mainWindow = window

        // Auto-fit after first SwiftUI layout pass.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.fitWindowToContent(animated: false)
        }

        // Re-fit whenever the todo list or selected date changes.
        viewModel.$allTodos
            .combineLatest(viewModel.$selectedDate)
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.fitWindowToContent(animated: true) }
            .store(in: &cancellables)

        setupDragMonitor()
    }

    // MARK: Auto-height

    func fitWindowToContent(animated: Bool = true) {
        guard let win = mainWindow, let hv = hostingView else { return }
        // Read fittingSize on the next run-loop tick so SwiftUI has finished layout.
        DispatchQueue.main.async {
            let targetH = max(hv.fittingSize.height, self.minWindowHeight)
            guard abs(win.frame.height - targetH) > 1 else { return }

            var f = win.frame
            f.origin.y += f.height - targetH    // keep top-left corner fixed
            f.size.height = targetH

            if animated {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.18
                    win.animator().setFrame(f, display: true)
                }
            } else {
                win.setFrame(f, display: true)
            }
        }
    }

    // MARK: Drag-to-move

    private func setupDragMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) {
            [weak self] event in
            self?.handleDrag(event)
            return event     // always forward — never block SwiftUI interactions
        }
    }

    private func handleDrag(_ event: NSEvent) {
        guard let win = mainWindow, event.window === win else {
            if event.type == .leftMouseUp { skipDrag = false }
            return
        }
        switch event.type {
        case .leftMouseDown:
            let hit = win.contentView?.hitTest(event.locationInWindow)
            skipDrag       = hit is NSTextField || hit is NSTextView
            dragStartMouse  = NSEvent.mouseLocation
            dragStartOrigin = win.frame.origin

        case .leftMouseDragged:
            guard !skipDrag else { return }
            // Leave the bottom-right 28×28 pt for the resize grip.
            let loc = event.locationInWindow
            if loc.x > win.frame.width - 28 && loc.y < 28 { return }
            let cur = NSEvent.mouseLocation
            win.setFrameOrigin(NSPoint(
                x: dragStartOrigin.x + cur.x - dragStartMouse.x,
                y: dragStartOrigin.y + cur.y - dragStartMouse.y
            ))

        case .leftMouseUp:
            skipDrag = false

        default: break
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

// MARK: - Rounded Visual Effect View

/// NSVisualEffectView that clips itself (and the blur material) to a rounded rectangle.
/// The mask is rebuilt on every layout pass so window resizes are handled automatically.
final class RoundedVisualEffectView: NSVisualEffectView {
    private let cornerRadius: CGFloat = 16

    override func layout() {
        super.layout()
        guard bounds.size.width > 0, bounds.size.height > 0 else { return }
        // maskImage is the officially-supported way to shape an NSVisualEffectView.
        maskImage = Self.roundedMask(size: bounds.size, radius: cornerRadius)
    }

    private static func roundedMask(size: CGSize, radius: CGFloat) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            NSColor.clear.setFill(); rect.fill()
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
    }
}

// MARK: - Widget Window

/// Borderless window that accepts key/main status so TextFields receive keyboard events.
final class WidgetWindow: NSWindow {
    override var canBecomeKey:  Bool { true }
    override var canBecomeMain: Bool { true }
}
