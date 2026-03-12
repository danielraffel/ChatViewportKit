import SwiftUI
import ChatViewportUIKit

// MARK: - UIKit Backend Transcript Lab

struct UKTranscriptLabView: View {
    @StateObject private var controller = UKChatViewportController<UUID>()
    @State private var messages: [LabMessage] = [LabMessage(text: "Message 1")]
    @State private var nextIndex = 2

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                UKChatViewport(messages, id: \.id, controller: controller) { message in
                    messageRow(message)
                }

                controlBar
            }
            .navigationTitle("UIKit Backend")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func messageRow(_ message: LabMessage) -> some View {
        HStack {
            Text(message.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            Spacer()
        }
        .frame(minHeight: message.extraHeight.map { $0 + 40 } ?? 40)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
    }

    private var controlBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button("+1") { appendMessages(1) }
                Button("+50") { appendMessages(50) }
                Button("+5K") { appendMessages(5000) }
                Button("Prepend") { prependMessages(10) }
                Button("Top") { controller.scrollToTop() }
                Button("Bottom") { controller.scrollToBottom() }
                Button("Mid") { scrollToMiddle() }
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }

    private func appendMessages(_ count: Int) {
        for _ in 0..<count {
            messages.append(LabMessage(text: "Message \(nextIndex)"))
            nextIndex += 1
        }
    }

    private func prependMessages(_ count: Int) {
        controller.prepareToPrepend()
        var newMessages: [LabMessage] = []
        for i in (1...count).reversed() {
            newMessages.append(LabMessage(text: "Prepended \(i)"))
        }
        messages.insert(contentsOf: newMessages, at: 0)
    }

    private func scrollToMiddle() {
        guard messages.count > 1 else { return }
        let midIndex = messages.count / 2
        controller.scrollTo(id: messages[midIndex].id, anchor: .center)
    }
}
