import SwiftUI
import ServiceManagement
import AppKit

// MARK: - Content View

struct ContentView: View {
    @ObservedObject var viewModel: WidgetViewModel
    @State private var isShowingDatePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            countdownCard
            todoSection
            resizeGripRow
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 6, trailing: 16))
        // Width is fixed by the window; height is unconstrained so fittingSize is accurate.
        .frame(minWidth: 300, maxWidth: 600)
        .background(Color.clear)
        .preferredColorScheme(.dark)
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Label("My Calendar Widget", systemImage: "calendar")
                .font(.headline)
            Spacer()
            Menu {
                Toggle(isOn: $viewModel.floatOnTop) {
                    Label("Float Above Windows", systemImage: "pin")
                }
                Toggle(isOn: Binding(
                    get: { viewModel.launchAtLogin },
                    set: { viewModel.setLaunchAtLogin($0) }
                )) {
                    Label("Launch at Login", systemImage: "power")
                }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
        }
    }

    // MARK: Countdown Card

    private var countdownCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Countdown")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("\(viewModel.daysLeft) day\(viewModel.daysLeft == 1 ? "" : "s") left")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .contentTransition(.numericText())

            Button { isShowingDatePicker = true } label: {
                Label(
                    viewModel.targetDate.formatted(date: .abbreviated, time: .omitted),
                    systemImage: "calendar.badge.clock"
                )
                .font(.callout)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .popover(isPresented: $isShowingDatePicker, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Target Date").font(.headline)
                    DatePicker("", selection: $viewModel.targetDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                }
                .padding(14)
                .frame(width: 280)
            }
        }
        .padding(12)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Todo Section

    private var todoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // ── Date navigation ──────────────────────────────────────────────
            HStack(spacing: 6) {
                Button { viewModel.previousDay() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)

                Text(viewModel.selectedDateLabel)
                    .font(.subheadline.weight(.semibold))
                    .frame(minWidth: 110, alignment: .center)

                Button { viewModel.nextDay() } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)

                Spacer()

                if !viewModel.isToday {
                    Button("Today") { viewModel.goToToday() }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.blue)
                }

                Text("\(viewModel.remainingCount) open")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // ── Todo rows (no scroll — window auto-heights instead) ──────────
            if viewModel.currentItems.isEmpty {
                Text("No todos for this day")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.currentItems) { item in
                        HStack(spacing: 10) {
                            Button { viewModel.toggle(itemID: item.id) } label: {
                                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.isDone ? .green : .secondary)
                                    .font(.system(size: 16))
                            }
                            .buttonStyle(.plain)

                            Text(item.text)
                                .strikethrough(item.isDone, color: .secondary)
                                .foregroundStyle(item.isDone ? .secondary : .primary)
                                .lineLimit(2)

                            Spacer(minLength: 0)

                            Button(role: .destructive) {
                                viewModel.delete(itemID: item.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }

            // ── Add-todo field ───────────────────────────────────────────────
            HStack(spacing: 8) {
                TextField("Add a todo", text: $viewModel.newTodoText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .onSubmit { viewModel.addTodo() }

                Button { viewModel.addTodo() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 30, height: 30)
                        .background(.white.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.newTodoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let err = viewModel.launchAtLoginError {
                Text(err)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
    }

    // MARK: Resize Grip

    private var resizeGripRow: some View {
        HStack {
            Spacer()
            ResizeGrip()
                .frame(width: 22, height: 22)
        }
    }
}

// MARK: - Resize Grip

/// An NSView in the bottom-right corner that lets the user resize the window by dragging.
struct ResizeGrip: NSViewRepresentable {
    func makeNSView(context: Context) -> ResizeGripView { ResizeGripView() }
    func updateNSView(_ nsView: ResizeGripView, context: Context) {}
}

final class ResizeGripView: NSView {
    private var startMouse: NSPoint = .zero
    private var startFrame: NSRect  = .zero

    override var isOpaque: Bool { false }

    // Draw the classic three-dot diagonal grip pattern.
    override func draw(_ rect: NSRect) {
        NSColor.white.withAlphaComponent(0.28).setFill()
        let dot: CGFloat = 2
        let gap: CGFloat = 4
        for row in 0..<3 {
            for col in 0..<3 {
                guard row + col >= 2 else { continue }
                let x = bounds.maxX - dot - CGFloat(col) * (dot + gap)
                let y = bounds.minY + CGFloat(row) * (dot + gap)
                NSBezierPath(ovalIn: NSRect(x: x, y: y, width: dot, height: dot)).fill()
            }
        }
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    override func mouseDown(with event: NSEvent) {
        startMouse = NSEvent.mouseLocation
        startFrame = window?.frame ?? .zero
    }

    override func mouseDragged(with event: NSEvent) {
        guard let win = window else { return }
        let cur = NSEvent.mouseLocation
        let dw =  cur.x - startMouse.x          // drag right  → wider
        let dh =  startMouse.y - cur.y           // drag down   → shorter (screen Y is up)

        var f = startFrame
        f.size.width  = max(300, min(700, startFrame.width  + dw))
        f.size.height = max(250, min(800, startFrame.height - dh))
        f.origin.y    = startFrame.maxY - f.size.height   // keep top-left fixed
        win.setFrame(f, display: true)
    }
}

// MARK: - Data Model

struct TodoItem: Identifiable, Codable, Equatable {
    let id:     UUID
    var text:   String
    var isDone: Bool
}

// MARK: - View Model

final class WidgetViewModel: ObservableObject {
    @Published var allTodos:  [String: [TodoItem]] = [:]
    @Published var selectedDate: Date = Date()
    @Published var targetDate:   Date = Date().addingTimeInterval(86400)
    @Published var newTodoText   = ""
    @Published var launchAtLogin = false
    @Published var floatOnTop    = false
    @Published var launchAtLoginError: String?

    private var isLoading = true

    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    // MARK: Init — loads from UserDefaults

    init() {
        isLoading = true

        if let ts = UserDefaults.standard.object(forKey: "targetDateTimestamp") as? Double, ts > 0 {
            targetDate = Date(timeIntervalSince1970: ts)
        }
        if let data = UserDefaults.standard.data(forKey: "allTodosData"),
           let decoded = try? JSONDecoder().decode([String: [TodoItem]].self, from: data) {
            allTodos = decoded
        } else {
            // Migrate from previous flat todos stored under "todoItemsData"
            if let old = UserDefaults.standard.data(forKey: "todoItemsData"),
               let items = try? JSONDecoder().decode([TodoItem].self, from: old),
               !items.isEmpty {
                allTodos[Self.keyFormatter.string(from: Date())] = items
            }
        }
        launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        floatOnTop    = UserDefaults.standard.bool(forKey: "floatOnTop")

        isLoading = false
    }

    // MARK: Persistence (called by AppDelegate via Combine)

    func persistAll() {
        guard !isLoading else { return }
        if let data = try? JSONEncoder().encode(allTodos) {
            UserDefaults.standard.set(data, forKey: "allTodosData")
        }
        UserDefaults.standard.set(targetDate.timeIntervalSince1970, forKey: "targetDateTimestamp")
        UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
        UserDefaults.standard.set(floatOnTop,    forKey: "floatOnTop")
    }

    // MARK: Date helpers

    var selectedDateKey: String { Self.keyFormatter.string(from: selectedDate) }

    var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }

    var selectedDateLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(selectedDate)     { return "Today" }
        if cal.isDateInYesterday(selectedDate)  { return "Yesterday" }
        if cal.isDateInTomorrow(selectedDate)   { return "Tomorrow" }
        return selectedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    func previousDay() { shift(by: -1) }
    func nextDay()     { shift(by:  1) }
    func goToToday()   { selectedDate = Date() }

    private func shift(by days: Int) {
        selectedDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) ?? selectedDate
    }

    // MARK: Computed from selected date

    var currentItems: [TodoItem] { allTodos[selectedDateKey] ?? [] }

    private func setCurrentItems(_ items: [TodoItem]) {
        if items.isEmpty { allTodos.removeValue(forKey: selectedDateKey) }
        else             { allTodos[selectedDateKey] = items }
    }

    var daysLeft: Int {
        let cal = Calendar.current
        let s = cal.startOfDay(for: Date())
        let e = cal.startOfDay(for: targetDate)
        return max(cal.dateComponents([.day], from: s, to: e).day ?? 0, 0)
    }

    var remainingCount: Int { currentItems.filter { !$0.isDone }.count }

    // MARK: Mutations

    func addTodo() {
        let t = newTodoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        var items = currentItems
        items.append(TodoItem(id: UUID(), text: t, isDone: false))
        setCurrentItems(items)
        newTodoText = ""
    }

    func toggle(itemID: UUID) {
        var items = currentItems
        guard let i = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[i].isDone.toggle()
        setCurrentItems(items)
    }

    func delete(itemID: UUID) {
        var items = currentItems
        items.removeAll { $0.id == itemID }
        setCurrentItems(items)
    }

    // MARK: Settings

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else       { try SMAppService.mainApp.unregister() }
            launchAtLogin = enabled
            launchAtLoginError = nil
            persistAll()
        } catch {
            launchAtLogin = false
            launchAtLoginError = "Launch at Login failed: \(error.localizedDescription)"
        }
    }

    func applyWindowLevel() {
        (NSApp.delegate as? AppDelegate)?.mainWindow?.level = floatOnTop ? .floating : .normal
        UserDefaults.standard.set(floatOnTop, forKey: "floatOnTop")
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View { ContentView(viewModel: WidgetViewModel()) }
}
