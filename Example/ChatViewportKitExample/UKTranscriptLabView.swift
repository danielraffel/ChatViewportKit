import SwiftUI
import ChatViewportUIKit
import ChatViewportCore

// MARK: - UIKit Backend Transcript Lab

struct UKTranscriptLabView: View {
    @StateObject private var controller = UKChatViewportController<UUID>()
    @State private var messages: [LabMessage] = [LabMessage(text: "Message 1")]
    @State private var nextIndex = 2
    @State private var prependCounter = 0
    @State private var showDebugHUD = true
    @State private var testLog: String = ""
    @State private var useLargeTitle = false
    @State private var composerText = ""
    @State private var jumpToIndex = ""
    @State private var useAccessibilitySize = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showDebugHUD {
                    debugHUD
                }

                UKChatViewport(messages, id: \.id, controller: controller) { message in
                    messageRow(message)
                }
                .environment(\.sizeCategory, useAccessibilitySize ? .accessibilityExtraExtraExtraLarge : .medium)
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }

                composerBar
                controlBar
            }
            .navigationTitle("UIKit Backend")
            .navigationBarTitleDisplayMode(useLargeTitle ? .large : .inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Mid") { scrollToMiddle() }
                        .font(.caption)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        Button(useLargeTitle ? "Inline" : "Title") {
                            useLargeTitle.toggle()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                controller.bounceToTop()
                            }
                        }
                        .foregroundColor(.accentColor)
                        Button("HUD") {
                            showDebugHUD.toggle()
                        }
                        .foregroundColor(showDebugHUD ? .accentColor : .secondary)
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
                    Text("CV: \(controller.collectionView != nil ? "Y" : "N")")
                    Text("Dist: \(distanceText)")
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

    private var distanceText: String {
        guard let dist = controller.distanceFromBottom else { return "—" }
        return String(format: "%.0f", dist)
    }

    private var modeDescription: String {
        switch controller.mode {
        case .initialBottomAnchored: return "initialBottom"
        case .pinnedToBottom: return "pinned"
        case .freeBrowsing: return "free"
        case .programmaticScroll: return "programmatic"
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
                messages.append(LabMessage(text: composerText))
                composerText = ""
                nextIndex += 1
                DispatchQueue.main.async {
                    controller.scrollToBottom()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
        .gesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.height > 20 {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    }
                }
        )
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
                        HStack(spacing: 2) {
                            TextField("#", text: $jumpToIndex)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 50)
                                .keyboardType(.numberPad)
                                .onSubmit { jumpToMessageIndex() }
                            Button("Go") { jumpToMessageIndex() }
                        }
                        Button("Expand") { expandLastMessage() }
                        Button("Grow") { asyncGrowRandomMessage() }
                        Button(useAccessibilitySize ? "AX→Std" : "Std→AX") {
                            useAccessibilitySize.toggle()
                            testLog = "DynType: \(useAccessibilitySize ? "AX-XXL" : "standard")"
                        }
                        Button("VarH") { loadVariableHeights() }
                        Button("Stress") { runStressTest() }
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
        for _ in 0..<count {
            messages.append(LabMessage(text: "Message \(nextIndex)"))
            nextIndex += 1
        }
    }

    private func burstAppend(_ count: Int) {
        for i in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                messages.append(LabMessage(text: "Burst \(nextIndex)"))
                nextIndex += 1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(count) * 0.05 + 0.1) {
            controller.scrollToBottom()
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

    private func jumpToMessageIndex() {
        guard let idx = Int(jumpToIndex), idx > 0, idx <= messages.count else {
            testLog = "Invalid index: \(jumpToIndex)"
            return
        }
        let target = messages[idx - 1]
        testLog = "Jump → \(target.text)"
        controller.scrollTo(id: target.id, anchor: .center)
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
        messages[messages.count - 1].extraHeight = 200
        messages[messages.count - 1].text += "\n[Expanded to 200pt]"
    }

    private func loadVariableHeights() {
        var batch: [LabMessage] = []
        for i in 1...10000 {
            let extra: CGFloat? = i % 3 == 0 ? CGFloat(60 + (i % 100)) : nil
            batch.append(LabMessage(text: "VarH \(i)", extraHeight: extra))
        }
        messages = batch
        nextIndex = 10001
        testLog = "10K variable heights loaded"
    }

    private func asyncGrowRandomMessage() {
        guard !messages.isEmpty else { return }
        let index = Int.random(in: 0..<messages.count)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            messages[index].extraHeight = 150
            messages[index].text += "\n[Async grew to 150pt]"
        }
    }

    private func findVisibleMessageText() -> String {
        guard let topID = controller.topVisibleItemID,
              let msg = messages.first(where: { $0.id == topID }) else {
            return "unknown"
        }
        return msg.text
    }

    private func runStressTest() {
        let start = CFAbsoluteTimeGetCurrent()
        var batch: [LabMessage] = []
        for i in 1...10000 {
            batch.append(LabMessage(text: "Msg \(i)", extraHeight: i % 3 == 0 ? CGFloat(60 + (i % 100)) : nil))
        }
        messages = batch
        nextIndex = 10001
        let loadTime = CFAbsoluteTimeGetCurrent() - start
        testLog = "10K loaded: \(String(format: "%.0fms", loadTime * 1000))"

        // Scroll to middle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            controller.scrollTo(id: messages[5000].id, anchor: .center, animated: false)
            testLog += " | scrolled to 5000"
        }

        // Append 50 while at middle
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            for _ in 0..<50 {
                messages.append(LabMessage(text: "Appended \(nextIndex)"))
                nextIndex += 1
            }
            testLog += " | +50"
        }

        // Prepend 50
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            controller.prepareToPrepend()
            var newBatch: [LabMessage] = []
            for _ in 0..<50 {
                prependCounter += 1
                newBatch.append(LabMessage(text: "History \(prependCounter)"))
            }
            messages.insert(contentsOf: newBatch, at: 0)
            testLog = "Pre50 done"
        }

        // Burst append while scrolling
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            controller.scrollToBottom(animated: false)
            for i in 0..<20 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                    messages.append(LabMessage(text: "Burst \(nextIndex)"))
                    nextIndex += 1
                }
            }
            testLog = "Burst 20 at 10K"
        }
    }
}
