import DesktopPetCore
import SwiftUI

struct FloatingPetHostView: View {
    let pet: PetRecord
    @ObservedObject var store: PetStore
    let chatProvider: any ChatProvider
    @ObservedObject var controller: FloatingPetController

    @State private var input = ""
    @State private var inputFocusToken = 0

    private var avatarSize: CGSize {
        PetDisplayMetrics.avatarSize(for: pet)
    }

    private var panelSize: CGSize {
        PetDisplayMetrics.panelSize(for: pet, showsBubble: controller.isBubbleOpen)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if controller.isBubbleOpen {
                DesktopBubbleView(
                    pet: pet,
                    input: $input,
                    latestReply: controller.latestReply,
                    focusToken: inputFocusToken,
                    send: sendMessage
                )
                .transition(.scale.combined(with: .opacity))
            }

            ZStack {
                PetAvatarView(pet: pet, action: controller.action)

                FloatingPetDragSurface(
                    onHover: { isHovering in
                        controller.handle(isHovering ? .hoverBegan : .hoverEnded)
                    },
                    onClick: {
                        if controller.isBubbleOpen {
                            controller.closeBubble(for: pet)
                        } else {
                            controller.openBubbleForTyping(for: pet)
                            inputFocusToken += 1
                        }
                        controller.reactToClick()
                    },
                    onDragChanged: { startPanelOrigin, startMouseLocation, currentMouseLocation in
                        controller.movePanel(
                            startPanelOrigin: startPanelOrigin,
                            startMouseLocation: startMouseLocation,
                            currentMouseLocation: currentMouseLocation
                        )
                    },
                    onDragEnded: {
                        controller.handle(.dragEnded)
                        controller.persistPosition(for: pet, in: store)
                    }
                )
            }
            .frame(width: avatarSize.width, height: avatarSize.height)
        }
        .padding(12)
        .frame(width: panelSize.width, height: panelSize.height, alignment: .bottomTrailing)
        .background(Color.clear)
        .onChange(of: controller.isBubbleOpen) { _, isOpen in
            if isOpen {
                controller.focusForTyping()
                DispatchQueue.main.async {
                    inputFocusToken += 1
                }
            }
        }
    }

    private func sendMessage() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            controller.latestReply = "\(pet.name)歪头看着你：我在。"
            return
        }

        input = ""
        store.appendMessage(.user, text: text, to: pet.id)
        controller.latestReply = "\(pet.name)正在想..."
        controller.handle(.thinkingBegan)
        let thinkingStartedAt = Date()

        Task {
            let history = pet.sortedMessages.map(\.turn)
            var reply = ""
            var hasStartedReplying = false

            await ReplyPresentationPacer.waitForMinimumThinkingIfNeeded(startedAt: thinkingStartedAt)

            do {
                for try await chunk in chatProvider.replyStream(to: text, pet: pet.profile, history: history) {
                    reply += chunk
                    await MainActor.run {
                        if !hasStartedReplying {
                            controller.handle(.replyingBegan)
                            hasStartedReplying = true
                        }
                        controller.latestReply = reply.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }

                await MainActor.run {
                    let trimmedReply = reply.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedReply.isEmpty {
                        let fallback = "\(pet.name)挠挠头：刚才没想好，等等再试。"
                        store.appendMessage(.pet, text: fallback, to: pet.id)
                        controller.latestReply = fallback
                        controller.handle(.replyFailed)
                    } else {
                        store.appendMessage(.pet, text: trimmedReply, to: pet.id)
                        controller.latestReply = trimmedReply
                        controller.handle(.replySucceeded)
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        controller.handle(.idleTick)
                    }
                }
            } catch {
                await MainActor.run {
                    let fallback = "\(pet.name)连不上模型：\(error.localizedDescription)"
                    store.appendMessage(.pet, text: fallback, to: pet.id)
                    controller.latestReply = fallback
                    controller.handle(.replyFailed)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        controller.handle(.idleTick)
                    }
                }
            }
        }
    }
}

private struct DesktopBubbleView: View {
    let pet: PetRecord
    @Binding var input: String
    let latestReply: String
    let focusToken: Int
    let send: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(latestReply.isEmpty ? "\(pet.name)：我在。" : latestReply)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                DesktopChatInputField(
                    text: $input,
                    placeholder: "和\(pet.name)说话",
                    focusToken: focusToken,
                    onSubmit: send
                )
                .frame(height: 18)

                Button(action: send) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.borderless)
                .help("发送")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(12)
        .frame(width: 250)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
    }
}
