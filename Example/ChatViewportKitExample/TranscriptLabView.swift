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
    @State private var useAccessibilitySize = false
    @State private var useLargeTitle = false
    @State private var composerText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showDebugHUD {
                    debugHUD
                }

                ChatViewport(messages, controller: controller) { message in
                    messageRow(message)
                }
                .environment(\.sizeCategory, useAccessibilitySize ? .accessibilityExtraExtraExtraLarge : .medium)

                composerBar
                controlBar
            }
            .navigationTitle("Transcript Lab")
            .navigationBarTitleDisplayMode(useLargeTitle ? .large : .inline)
            // .onAppear { runStressTest() } // Uncomment for automated tests
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        Button(useLargeTitle ? "Inline" : "Large") {
                            useLargeTitle.toggle()
                        }
                        Button(showDebugHUD ? "HUD" : "HUD") {
                            showDebugHUD.toggle()
                        }
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
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Msgs: \(messages.count)")
                    Text("Mode: \(modeDescription)")
                    Text("Pin: \(controller.isPinnedToBottom ? "Y" : "N")")
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Top: \(topVisibleText)")
                    Text("SV: \(controller.hasScrollViewRef ? "Y" : "N")")
                    Text("Freeze: \(controller.freezeAnchorState ? "Y" : "N")")
                }
            }
            if !testLog.isEmpty {
                Text(testLog).foregroundColor(.green)
            }
        }
        .font(.system(.caption2, design: .monospaced))
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray5).opacity(0.8))
    }

    private var topVisibleText: String {
        guard let topID = controller.topVisibleItemID,
              let msg = messages.first(where: { $0.id == topID }) else {
            return "—"
        }
        return msg.text
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

    // MARK: - Composer

    private var composerBar: some View {
        HStack(spacing: 8) {
            TextField("Type a message...", text: $composerText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...5)
            Button("Send") {
                guard !composerText.isEmpty else { return }
                withAnimation {
                    messages.append(LabMessage(text: composerText))
                    composerText = ""
                    nextIndex += 1
                }
                controller.scrollToBottom()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
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
                        Button("+10K") { appendMessages(10000) }
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
                        Button(useAccessibilitySize ? "AX→Std" : "Std→AX") {
                            useAccessibilitySize.toggle()
                            testLog = "DynType: \(useAccessibilitySize ? "AX-XXL" : "standard")"
                        }
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

    // MARK: - Stress Test

    private func runStressTest() {
        let start = CFAbsoluteTimeGetCurrent()
        // Load 10K messages
        var batch: [LabMessage] = []
        for i in 1...10000 {
            batch.append(LabMessage(text: "Msg \(i)", extraHeight: i % 3 == 0 ? CGFloat(60 + (i % 100)) : nil))
        }
        messages = batch
        nextIndex = 10001
        let loadTime = CFAbsoluteTimeGetCurrent() - start
        testLog = "10K loaded: \(String(format: "%.0fms", loadTime * 1000))"
        NSLog("[STRESS] 10K load: \(loadTime * 1000)ms")

        // Scroll to middle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            controller.scrollTo(id: messages[5000].id, anchor: .center, animated: false)
            testLog += " | scrolled to 5000"
        }

        // Append 50 while at middle
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let appendStart = CFAbsoluteTimeGetCurrent()
            for _ in 0..<50 {
                messages.append(LabMessage(text: "Appended \(nextIndex)"))
                nextIndex += 1
            }
            let appendTime = CFAbsoluteTimeGetCurrent() - appendStart
            NSLog("[STRESS] Append 50 at 10K: \(appendTime * 1000)ms")
            testLog += " | +50: \(String(format: "%.0fms", appendTime * 1000))"
        }

        // Prepend 50
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            let prependStart = CFAbsoluteTimeGetCurrent()
            controller.prepareToPrepend()
            var newBatch: [LabMessage] = []
            for _ in 0..<50 {
                prependCounter += 1
                newBatch.append(LabMessage(text: "History \(prependCounter)"))
            }
            messages.insert(contentsOf: newBatch, at: 0)
            let prependTime = CFAbsoluteTimeGetCurrent() - prependStart
            NSLog("[STRESS] Prepend 50 at 10K: \(prependTime * 1000)ms")
            testLog = "Pre50: \(String(format: "%.0fms", prependTime * 1000))"
        }

        // Burst append while scrolling
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            controller.scrollToBottom(animated: false)
            for i in 0..<20 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                    withAnimation {
                        messages.append(LabMessage(text: "Burst \(nextIndex)"))
                        nextIndex += 1
                    }
                }
            }
            testLog = "Burst 20 at 10K"
        }

        // Height mutation
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            let idx = 5000
            messages[idx].extraHeight = 200
            messages[idx].text += "\n[Stress expanded]"
            testLog = "Height mutated at 10K"
            NSLog("[STRESS] All stress tests complete")
        }
    }

    // MARK: - Navigation Test

    private func runNavTest() {
        // Add 30 messages
        for _ in 0..<29 {
            messages.append(LabMessage(text: "Message \(nextIndex)"))
            nextIndex += 1
        }
        // After a moment, switch to large title
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            useLargeTitle = true
            testLog = "Large title mode"
        }
        // After more time, switch back to inline
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            useLargeTitle = false
            testLog = "Inline title mode"
        }
    }

    // MARK: - Dynamic Type Test

    private func runDynamicTypeTest() {
        // Setup: 50 messages
        for _ in 0..<49 {
            messages.append(LabMessage(text: "Message \(nextIndex)"))
            nextIndex += 1
        }

        // Scroll to middle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            controller.scrollTo(id: messages[24].id, anchor: .top, animated: false)
            testLog = "At Message 25"
        }

        // Toggle to accessibility size
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let before = findVisibleMessageText()
            useAccessibilitySize = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let after = findVisibleMessageText()
                testLog = "DT→AX: \(before)→\(after)"
                NSLog("[TEST] DynType to AX: before=\(before) after=\(after)")
            }
        }

        // Toggle back to standard
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            let before = findVisibleMessageText()
            useAccessibilitySize = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let after = findVisibleMessageText()
                testLog = "DT→Std: \(before)→\(after)"
                NSLog("[TEST] DynType to Std: before=\(before) after=\(after)")
            }
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
