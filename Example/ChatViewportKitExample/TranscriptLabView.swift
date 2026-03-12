import SwiftUI
import ChatViewportKit

// MARK: - Data Model

struct LabMessage: Identifiable {
    let id: UUID
    var text: String
    var height: CGFloat?

    init(text: String, height: CGFloat? = nil) {
        self.id = UUID()
        self.text = text
        self.height = height
    }
}

// MARK: - Transcript Lab

struct TranscriptLabView: View {
    @StateObject private var controller = ChatViewportController<UUID>()
    @State private var messages: [LabMessage] = []
    @State private var nextIndex = 1

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ChatViewport(messages, controller: controller) { message in
                    Text(message.text)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: message.height)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                }

                controlBar
            }
            .navigationTitle("Transcript Lab")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var controlBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button("+ 1") { appendMessages(1) }
                Button("+ 5") { appendMessages(5) }
                Button("+ 50") { appendMessages(50) }
                Button("Prepend 5") { prependMessages(5) }
                Button("⬇ Bottom") { controller.scrollToBottom() }
                Button("⬆ Top") { controller.scrollToTop() }
                Button("Clear") { messages.removeAll(); nextIndex = 1 }
            }
            .buttonStyle(.borderedProminent)
            .padding()
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
        var newMessages: [LabMessage] = []
        for i in 0..<count {
            newMessages.append(LabMessage(text: "Old message \(count - i)"))
        }
        messages.insert(contentsOf: newMessages, at: 0)
    }
}
