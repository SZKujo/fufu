import DesktopPetCore
import SwiftUI

struct ChatPageView: View {
    @EnvironmentObject private var runtime: AppRuntime
    @EnvironmentObject private var store: PetStore

    @State private var selectedPetID: UUID?
    @State private var input = ""
    @State private var streamingPetID: UUID?
    @State private var streamingReply = ""

    private var selectedPet: PetRecord? {
        if let selectedPetID, let pet = store.pets.first(where: { $0.id == selectedPetID }) {
            return pet
        }
        return store.activePet ?? store.pets.first
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("聊天对象", selection: Binding(
                    get: { selectedPet?.id },
                    set: { selectedPetID = $0 }
                )) {
                    ForEach(store.pets) { pet in
                        Text(pet.name).tag(Optional(pet.id))
                    }
                }
                .frame(width: 220)

                Spacer()

                if let selectedPet {
                    Button {
                        store.setActive(selectedPet.id)
                        runtime.refreshFloatingPet()
                    } label: {
                        Label("设为桌面宠物", systemImage: "display")
                    }
                    .disabled(selectedPet.isActive)
                }
            }
            .padding(16)

            Divider()

            if let selectedPet {
                ChatTranscriptView(
                    pet: selectedPet,
                    streamingReply: selectedPet.id == streamingPetID ? streamingReply : nil
                )

                Divider()

                HStack(spacing: 10) {
                    TextField("和\(selectedPet.name)说话", text: $input, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            sendMessage(to: selectedPet)
                        }

                    Button {
                        sendMessage(to: selectedPet)
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .help("发送")
                }
                .padding(16)
            } else {
                ContentUnavailableView("还没有聊天对象", systemImage: "bubble.left", description: Text("先创建一只宠物。"))
            }
        }
    }

    private func sendMessage(to pet: PetRecord) {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        input = ""
        store.appendMessage(.user, text: text, to: pet.id)
        streamingPetID = pet.id
        streamingReply = "\(pet.name)正在想..."
        runtime.floatingController.latestReply = streamingReply
        runtime.floatingController.handle(.thinkingBegan)
        let thinkingStartedAt = Date()

        Task {
            let history = pet.sortedMessages.map(\.turn)
            var reply = ""
            var hasStartedReplying = false

            await ReplyPresentationPacer.waitForMinimumThinkingIfNeeded(startedAt: thinkingStartedAt)

            do {
                let provider = runtime.makeChatProvider()
                for try await chunk in provider.replyStream(to: text, pet: pet.profile, history: history) {
                    reply += chunk
                    await MainActor.run {
                        if !hasStartedReplying {
                            runtime.floatingController.handle(.replyingBegan)
                            hasStartedReplying = true
                        }
                        let displayedReply = reply.trimmingCharacters(in: .whitespacesAndNewlines)
                        streamingPetID = pet.id
                        streamingReply = displayedReply
                        runtime.floatingController.latestReply = displayedReply
                    }
                }

                await MainActor.run {
                    let finalReply: String
                    let trimmedReply = reply.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedReply.isEmpty {
                        finalReply = "\(pet.name)挠挠头：刚才没想好，等等再试。"
                        runtime.floatingController.handle(.replyFailed)
                    } else {
                        finalReply = trimmedReply
                        runtime.floatingController.handle(.replySucceeded)
                    }

                    store.appendMessage(.pet, text: finalReply, to: pet.id)
                    runtime.floatingController.latestReply = finalReply
                    if streamingPetID == pet.id {
                        streamingPetID = nil
                        streamingReply = ""
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        runtime.floatingController.handle(.idleTick)
                    }
                }
            } catch {
                await MainActor.run {
                    let finalReply = "\(pet.name)连不上模型：\(error.localizedDescription)"
                    store.appendMessage(.pet, text: finalReply, to: pet.id)
                    runtime.floatingController.latestReply = finalReply
                    streamingPetID = nil
                    streamingReply = ""
                    runtime.floatingController.handle(.replyFailed)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        runtime.floatingController.handle(.idleTick)
                    }
                }
            }
        }
    }
}

private struct ChatTranscriptView: View {
    let pet: PetRecord
    let streamingReply: String?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(pet.sortedMessages) { message in
                        ChatMessageRow(message: message)
                            .id(message.id)
                    }

                    if let streamingReply, !streamingReply.isEmpty {
                        StreamingReplyRow(text: streamingReply)
                            .id("streaming-reply")
                    }
                }
                .padding(18)
            }
            .onChange(of: pet.sortedMessages.count) {
                if let last = pet.sortedMessages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
            .onChange(of: streamingReply) { _, value in
                if value?.isEmpty == false {
                    proxy.scrollTo("streaming-reply", anchor: .bottom)
                }
            }
        }
    }
}

private struct ChatMessageRow: View {
    let message: ChatRecord

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 80)
            }

            Text(message.text.trimmingCharacters(in: .whitespacesAndNewlines))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(message.role == .user ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: 420, alignment: message.role == .user ? .trailing : .leading)

            if message.role == .pet {
                Spacer(minLength: 80)
            }
        }
    }
}

private struct StreamingReplyRow: View {
    let text: String

    var body: some View {
        HStack {
            Text(text.trimmingCharacters(in: .whitespacesAndNewlines))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: 420, alignment: .leading)

            Spacer(minLength: 80)
        }
    }
}
