import SwiftUI
import ChatViewportKit

// MARK: - Data Model

struct LabMessage: Identifiable {
    let id: UUID
    var text: String
    var extraHeight: CGFloat?

    init(text: String, extraHeight: CGFloat? = nil) {
        self.id = UUID()
        self.text = text
        self.extraHeight = extraHeight
    }
}

// MARK: - Transcript Lab

struct TranscriptLabView: View {
    @StateObject private var controller = ChatViewportController<UUID>()
    @State private var messages: [LabMessage] = [LabMessage(text: "Message 1")]
    @State private var nextIndex = 2
    @State private var prependCounter = 0
    @State private var showDebugHUD = true
    @State private var testLog: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showDebugHUD {
                    debugHUD
                }

                ChatViewport(messages, controller: controller) { message in
                    messageRow(message)
                }

                controlBar
            }
            .navigationTitle("Transcript Lab")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(showDebugHUD ? "Hide HUD" : "Show HUD") {
                        showDebugHUD.toggle()
                    }
                    .font(.caption)
                }
            }
        }
    }

    // MARK: - Message Row

    private func messageRow(_ message: LabMessage) -> some View {
        HStack {
            Text(message.text)
                .padding(12)
            Spacer()
        }
        .frame(minHeight: message.extraHeight)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    // MARK: - Debug HUD

    private var debugHUD: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Messages: \(messages.count)")
            Text("Mode: \(modeDescription)")
            Text("Pinned: \(controller.isPinnedToBottom ? "YES" : "NO")")
            Text("First ID: \(messages.first?.id.uuidString.prefix(8) ?? "—")")
            Text("Last ID: \(messages.last?.id.uuidString.prefix(8) ?? "—")")
            if !testLog.isEmpty {
                Text(testLog).foregroundColor(.green)
            }
        }
        .font(.system(.caption2, design: .monospaced))
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray5).opacity(0.8))
    }

    private var modeDescription: String {
        switch controller.mode {
        case .initialBottomAnchored: return "initialBottomAnchored"
        case .pinnedToBottom: return "pinnedToBottom"
        case .freeBrowsing: return "freeBrowsing"
        case .programmaticScroll: return "programmaticScroll"
        case .correctingAfterDataChange: return "correcting"
        }
    }

    // MARK: - Controls

    private var controlBar: some View {
        VStack(spacing: 4) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Group {
                        Button("+1") { appendMessages(1) }
                        Button("+3") { appendMessages(3) }
                        Button("+10") { appendMessages(10) }
                        Button("+50") { appendMessages(50) }
                        Button("+5K") { appendMessages(5000) }
                        Button("Burst 20") { burstAppend(20) }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.horizontal)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Group {
                        Button("Pre 1") { prependMessages(1) }
                        Button("Pre 5") { prependMessages(5) }
                        Button("Pre 10") { prependMessages(10) }
                        Button("Pre 50") { prependMessages(50) }
                        Button("⬇ Bottom") { controller.scrollToBottom() }
                        Button("⬆ Top") { controller.scrollToTop() }
                        Button("→ Mid") { scrollToMiddle() }
                        Button("Expand") { expandLastMessage() }
                        Button("Grow") { asyncGrowRandomMessage() }
                        Button("Clear") { resetWith(count: 0) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    // MARK: - Actions

    private func appendMessages(_ count: Int) {
        withAnimation {
            for _ in 0..<count {
                messages.append(LabMessage(text: "Message \(nextIndex)"))
                nextIndex += 1
            }
        }
    }

    private func burstAppend(_ count: Int) {
        for i in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                withAnimation {
                    messages.append(LabMessage(text: "Burst \(nextIndex)"))
                    nextIndex += 1
                }
            }
        }
    }

    private func prependMessages(_ count: Int) {
        controller.prepareToPrepend()
        var newMessages: [LabMessage] = []
        for _ in 0..<count {
            prependCounter += 1
            newMessages.append(LabMessage(text: "History \(prependCounter)"))
        }
        messages.insert(contentsOf: newMessages, at: 0)
        testLog = "Prepended \(count)"
    }

    private func scrollToMiddle() {
        guard messages.count >= 3 else { return }
        let midIndex = messages.count / 2
        controller.scrollTo(id: messages[midIndex].id)
    }

    private func resetWith(count: Int) {
        messages.removeAll()
        prependCounter = 0
        if count > 0 {
            messages = (1...count).map { LabMessage(text: "Message \($0)") }
            nextIndex = count + 1
        } else {
            nextIndex = 1
        }
    }

    private func expandLastMessage() {
        guard !messages.isEmpty else { return }
        withAnimation {
            messages[messages.count - 1].extraHeight = 200
            messages[messages.count - 1].text += "\n[Expanded to 200pt]"
        }
    }

    // MARK: - Automated Prepend Test

    private func runPrependTests() {
        // Setup: add 50 messages
        for _ in 0..<49 {
            messages.append(LabMessage(text: "Message \(nextIndex)"))
            nextIndex += 1
        }

        // Scroll to middle (message 25)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let targetIdx = 24
            let targetID = messages[targetIdx].id
            controller.scrollTo(id: targetID, anchor: .top, animated: false)
            testLog = "At: \(messages[targetIdx].text)"
        }

        // Test 1: Prepend 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let visibleBefore = findVisibleMessageText()
            controller.prepareToPrepend()
            prependCounter += 1
            messages.insert(LabMessage(text: "History \(prependCounter)"), at: 0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                let visibleAfter = findVisibleMessageText()
                testLog = "Pre1: \(visibleBefore) → \(visibleAfter)"
                NSLog("[TEST] Prepend 1: before=\(visibleBefore) after=\(visibleAfter)")
            }
        }

        // Test 2: Prepend 10
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            let visibleBefore = findVisibleMessageText()
            controller.prepareToPrepend()
            var batch: [LabMessage] = []
            for _ in 0..<10 {
                prependCounter += 1
                batch.append(LabMessage(text: "History \(prependCounter)"))
            }
            messages.insert(contentsOf: batch, at: 0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                let visibleAfter = findVisibleMessageText()
                testLog = "Pre10: \(visibleBefore) → \(visibleAfter)"
                NSLog("[TEST] Prepend 10: before=\(visibleBefore) after=\(visibleAfter)")
            }
        }

        // Test 3: Prepend 50
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            let visibleBefore = findVisibleMessageText()
            controller.prepareToPrepend()
            var batch: [LabMessage] = []
            for _ in 0..<50 {
                prependCounter += 1
                batch.append(LabMessage(text: "History \(prependCounter)"))
            }
            messages.insert(contentsOf: batch, at: 0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                let visibleAfter = findVisibleMessageText()
                testLog = "Pre50: \(visibleBefore) → \(visibleAfter)"
                NSLog("[TEST] Prepend 50: before=\(visibleBefore) after=\(visibleAfter)")
            }
        }
    }

    private func findVisibleMessageText() -> String {
        // Use topVisibleItemID to find what's at the top of viewport
        guard let topID = controller.topVisibleItemID,
              let msg = messages.first(where: { $0.id == topID }) else {
            return "unknown"
        }
        return msg.text
    }

    private func asyncGrowRandomMessage() {
        guard !messages.isEmpty else { return }
        let index = Int.random(in: 0..<messages.count)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation {
                messages[index].extraHeight = 150
                messages[index].text += "\n[Async grew to 150pt]"
            }
        }
    }
}
