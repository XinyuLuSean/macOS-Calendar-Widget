import SwiftUI
import ServiceManagement
import AppKit
import UniformTypeIdentifiers

// MARK: - Content View

struct ContentView: View {
    @ObservedObject var viewModel: WidgetViewModel
    @State private var isShowingDatePicker = false
    @State private var isShowingMotivationSettings = false
    @State private var editingTodoID: UUID?
    @State private var editingTodoText = ""
    @State private var draggedTodoID: UUID?
    @FocusState private var focusedTodoID: UUID?

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
        .coordinateSpace(name: "widget")
        .preferredColorScheme(.dark)
        .onPreferenceChange(TodoRowFramePreferenceKey.self) { frames in
            viewModel.todoRowFrames = Array(frames.values)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Label("My Calendar Widget", systemImage: "calendar")
                .font(.headline)
            Spacer()
            Menu {
                Toggle(isOn: Binding(
                    get: { viewModel.floatOnTop },
                    set: { viewModel.setFloatOnTop($0) }
                )) {
                    Label("Float Above Windows", systemImage: "pin")
                }
                Toggle(isOn: Binding(
                    get: { viewModel.launchAtLogin },
                    set: { viewModel.setLaunchAtLogin($0) }
                )) {
                    Label("Launch at Login", systemImage: "power")
                }
                Divider()
                Button {
                    viewModel.loadMotivationSettings()
                    isShowingMotivationSettings = true
                } label: {
                    Label("Words API Settings", systemImage: "sparkles")
                }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
        }
        .sheet(isPresented: $isShowingMotivationSettings) {
            motivationSettingsSheet
        }
    }

    private var motivationSettingsSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Words API")
                .font(.headline)

            SecureField("API key", text: $viewModel.motivationAPIKey)
                .textFieldStyle(.roundedBorder)

            TextField("Endpoint", text: $viewModel.motivationEndpoint)
                .textFieldStyle(.roundedBorder)

            TextField("Model", text: $viewModel.motivationModel)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel") {
                    isShowingMotivationSettings = false
                }
                Button("Save") {
                    viewModel.saveMotivationSettings()
                    isShowingMotivationSettings = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 380)
        .preferredColorScheme(.dark)
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
                    DatePicker("", selection: Binding(
                        get: { viewModel.targetDate },
                        set: { viewModel.setTargetDate($0) }
                    ), displayedComponents: .date)
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

            wordsForToday

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

                            if editingTodoID == item.id {
                                TextField("Todo", text: $editingTodoText)
                                    .textFieldStyle(.plain)
                                    .focused($focusedTodoID, equals: item.id)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .onSubmit { commitEditingTodo() }
                            } else {
                                Button { beginEditing(item) } label: {
                                    Text(item.text)
                                        .strikethrough(item.isDone, color: .secondary)
                                        .foregroundStyle(item.isDone ? .secondary : .primary)
                                        .lineLimit(2)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .onDrag {
                                    cancelEditingTodo()
                                    draggedTodoID = item.id
                                    viewModel.isTodoDragActive = true
                                    return NSItemProvider(object: item.id.uuidString as NSString)
                                }
                            }

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
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: TodoRowFramePreferenceKey.self,
                                    value: [item.id: proxy.frame(in: .named("widget"))]
                                )
                            }
                        )
                        .onDrop(
                            of: [.text],
                            delegate: TodoDropDelegate(
                                targetID: item.id,
                                viewModel: viewModel,
                                draggedTodoID: $draggedTodoID
                            )
                        )
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
        .onChange(of: viewModel.selectedDate) { cancelEditingTodo() }
        .onChange(of: focusedTodoID) {
            if editingTodoID != nil && focusedTodoID == nil {
                commitEditingTodo()
            }
        }
        .onChange(of: draggedTodoID) {
            viewModel.isTodoDragActive = draggedTodoID != nil
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

    private var wordsForToday: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let line = viewModel.wordsForToday {
                Text(line)
                    .font(.callout.weight(.semibold))
                    .italic()
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Button {
                    Task { await viewModel.generateWordsForToday() }
                } label: {
                    HStack(spacing: 6) {
                        if viewModel.isGeneratingWordsForToday {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.65)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(viewModel.isGeneratingWordsForToday ? "Generating..." : "Words For Today")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isGeneratingWordsForToday)
            }

            if let error = viewModel.wordsForTodayError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func beginEditing(_ item: TodoItem) {
        if editingTodoID != item.id {
            commitEditingTodo()
        }
        editingTodoID = item.id
        editingTodoText = item.text
        DispatchQueue.main.async {
            focusedTodoID = item.id
        }
    }

    private func commitEditingTodo() {
        guard let id = editingTodoID else { return }
        viewModel.updateTodo(itemID: id, text: editingTodoText)
        editingTodoID = nil
        editingTodoText = ""
        focusedTodoID = nil
    }

    private func cancelEditingTodo() {
        editingTodoID = nil
        editingTodoText = ""
        focusedTodoID = nil
    }
}

private struct TodoRowFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct TodoDropDelegate: DropDelegate {
    let targetID: UUID
    let viewModel: WidgetViewModel
    @Binding var draggedTodoID: UUID?

    func dropEntered(info: DropInfo) {
        guard let draggedTodoID, draggedTodoID != targetID else { return }
        viewModel.moveTodo(itemID: draggedTodoID, to: targetID)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedTodoID = nil
        viewModel.isTodoDragActive = false
        return true
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

// MARK: - Words For Today API

private enum MotivationAPIConfig {
    static let apiKeyKey = "MotivationAPIKey"
    static let endpointKey = "MotivationEndpoint"
    static let modelKey = "MotivationModel"
    static let defaultEndpoint = "https://api.openai.com/v1/chat/completions"
    static let defaultModel = "gpt-4o-mini"

    static var apiKey: String {
        UserDefaults.standard.string(forKey: apiKeyKey) ?? ""
    }

    static var endpointString: String {
        UserDefaults.standard.string(forKey: endpointKey) ?? defaultEndpoint
    }

    static var model: String {
        UserDefaults.standard.string(forKey: modelKey) ?? defaultModel
    }
}

private enum MotivationAPIError: LocalizedError {
    case missingAPIKey
    case invalidEndpoint
    case invalidResponse
    case emptyMessage

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add your LLM API key in Words API Settings."
        case .invalidEndpoint:
            return "Words API endpoint is not a valid URL."
        case .invalidResponse:
            return "Words API returned an unreadable response."
        case .emptyMessage:
            return "Words API did not return a line."
        }
    }
}

private struct ChatCompletionResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }

        let message: Message
    }

    let choices: [Choice]
}

private struct MotivationService {
    func generateLine(for items: [TodoItem]) async throws -> String {
        let apiKey = MotivationAPIConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw MotivationAPIError.missingAPIKey
        }
        guard let endpoint = URL(string: MotivationAPIConfig.endpointString) else {
            throw MotivationAPIError.invalidEndpoint
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload(for: items))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let decoded = try? JSONDecoder().decode(ChatCompletionResponse.self, from: data) else {
            throw MotivationAPIError.invalidResponse
        }

        let content = decoded.choices.first?.message.content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        guard let content, !content.isEmpty else { throw MotivationAPIError.emptyMessage }
        return content
    }

    private func payload(for items: [TodoItem]) -> [String: Any] {
        let todoSummary: String
        if items.isEmpty {
            todoSummary = "No todos have been written yet."
        } else {
            todoSummary = items.enumerated()
                .map { index, item in
                    let status = item.isDone ? "done" : "open"
                    return "\(index + 1). [\(status)] \(item.text)"
                }
                .joined(separator: "\n")
        }

        return [
            "model": MotivationAPIConfig.model,
            "messages": [
                [
                    "role": "system",
                    "content": "You are a warm, intense career coach for someone job hunting. Return exactly one brief motivational line, 8 to 18 words, no markdown, no quotation marks."
                ],
                [
                    "role": "user",
                    "content": "Analyze today's todos and give me one line that helps me lock in and never give up.\n\nTodos:\n\(todoSummary)"
                ]
            ],
            "temperature": 0.9,
            "max_tokens": 40
        ]
    }
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
    @Published var wordsForToday: String?
    @Published var wordsForTodayError: String?
    @Published var isGeneratingWordsForToday = false
    @Published var motivationAPIKey = ""
    @Published var motivationEndpoint = MotivationAPIConfig.defaultEndpoint
    @Published var motivationModel = MotivationAPIConfig.defaultModel
    var isTodoDragActive = false
    var todoRowFrames: [CGRect] = []

    private var isLoading = true
    private let motivationService = MotivationService()

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
        loadMotivationSettings()

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
        UserDefaults.standard.synchronize()
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
    func goToToday()   {
        selectedDate = Date()
        resetWordsForToday()
    }

    private func shift(by days: Int) {
        selectedDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) ?? selectedDate
        resetWordsForToday()
    }

    // MARK: Computed from selected date

    var currentItems: [TodoItem] { allTodos[selectedDateKey] ?? [] }

    private func setCurrentItems(_ items: [TodoItem]) {
        if items.isEmpty { allTodos.removeValue(forKey: selectedDateKey) }
        else             { allTodos[selectedDateKey] = items }
        resetWordsForToday()
        persistAll()
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

    func updateTodo(itemID: UUID, text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        var items = currentItems
        guard let i = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[i].text = t
        setCurrentItems(items)
    }

    func moveTodo(itemID: UUID, to targetID: UUID) {
        var items = currentItems
        guard
            let from = items.firstIndex(where: { $0.id == itemID }),
            let to = items.firstIndex(where: { $0.id == targetID }),
            from != to
        else { return }

        let item = items.remove(at: from)
        items.insert(item, at: to)
        setCurrentItems(items)
    }

    @MainActor
    func generateWordsForToday() async {
        guard !isGeneratingWordsForToday else { return }
        isGeneratingWordsForToday = true
        wordsForTodayError = nil

        do {
            wordsForToday = try await motivationService.generateLine(for: currentItems)
        } catch {
            wordsForTodayError = error.localizedDescription
        }

        isGeneratingWordsForToday = false
    }

    private func resetWordsForToday() {
        wordsForToday = nil
        wordsForTodayError = nil
    }

    func loadMotivationSettings() {
        motivationAPIKey = MotivationAPIConfig.apiKey
        motivationEndpoint = MotivationAPIConfig.endpointString
        motivationModel = MotivationAPIConfig.model
    }

    func saveMotivationSettings() {
        let key = motivationAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let endpoint = motivationEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let model = motivationModel.trimmingCharacters(in: .whitespacesAndNewlines)

        if key.isEmpty {
            UserDefaults.standard.removeObject(forKey: MotivationAPIConfig.apiKeyKey)
        } else {
            UserDefaults.standard.set(key, forKey: MotivationAPIConfig.apiKeyKey)
        }
        UserDefaults.standard.set(endpoint.isEmpty ? MotivationAPIConfig.defaultEndpoint : endpoint, forKey: MotivationAPIConfig.endpointKey)
        UserDefaults.standard.set(model.isEmpty ? MotivationAPIConfig.defaultModel : model, forKey: MotivationAPIConfig.modelKey)
        UserDefaults.standard.synchronize()
        loadMotivationSettings()
        resetWordsForToday()
    }

    func setTargetDate(_ date: Date) {
        targetDate = Calendar.current.startOfDay(for: date)
        persistAll()
    }

    // MARK: Settings

    func setFloatOnTop(_ enabled: Bool) {
        floatOnTop = enabled
        persistAll()
        (NSApp.delegate as? AppDelegate)?.applyWindowLevel(floats: enabled)
    }

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
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View { ContentView(viewModel: WidgetViewModel()) }
}
