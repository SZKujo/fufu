import AppKit
import SwiftData
import XCTest
import DesktopPetCore
@testable import DesktopPetApp

@MainActor
final class PetStoreTests: XCTestCase {
    func testSwiftDataStoreCreatesActivatesAndAppendsMessages() throws {
        let container = try makeInMemoryContainer()
        let store = PetStore(modelContainer: container, legacyJSONURL: nil)

        let first = try store.createPet(
            name: "Mainey",
            prompt: "你是 Mainey，一只黏人的桌面宠物。",
            sourceURL: nil
        )
        let second = try store.createPet(
            name: "灰灰",
            prompt: "你是灰灰，说话温柔简短。",
            sourceURL: nil
        )

        XCTAssertEqual(store.pets.count, 2)
        XCTAssertEqual(store.activePet?.id, first.id)

        store.setActive(second.id)
        XCTAssertEqual(store.activePet?.id, second.id)

        let message = store.appendMessage(.user, text: "你好", to: second.id)
        XCTAssertEqual(message?.text, "你好")
        XCTAssertEqual(store.pet(with: second.id)?.messages.last?.role, .user)
    }

    func testStoreCanClearActivePet() throws {
        let container = try makeInMemoryContainer()
        let store = PetStore(modelContainer: container, legacyJSONURL: nil)
        let pet = try store.createPet(
            name: "Mainey",
            prompt: "你是 Mainey，一只黏人的桌面宠物。",
            sourceURL: nil
        )

        XCTAssertEqual(store.activePet?.id, pet.id)

        store.clearActivePet()

        XCTAssertNil(store.activePet)
        XCTAssertFalse(store.pet(with: pet.id)?.isActive ?? true)
    }

    func testDefaultPetCannotBeDeleted() throws {
        let container = try makeInMemoryContainer()
        let store = PetStore(modelContainer: container, legacyJSONURL: nil)
        store.ensureSeedPetIfNeeded()

        let defaultPet = try XCTUnwrap(store.pets.first)
        XCTAssertTrue(defaultPet.isProtectedDefault)

        let didDelete = store.delete(defaultPet.id)

        XCTAssertFalse(didDelete)
        XCTAssertNotNil(store.pet(with: defaultPet.id))
    }

    func testCreatedPetCanBeDeleted() throws {
        let container = try makeInMemoryContainer()
        let store = PetStore(modelContainer: container, legacyJSONURL: nil)
        store.ensureSeedPetIfNeeded()
        let pet = try store.createPet(
            name: "自定义",
            prompt: "你很活泼。",
            sourceURL: nil
        )

        let didDelete = store.delete(pet.id)

        XCTAssertTrue(didDelete)
        XCTAssertNil(store.pet(with: pet.id))
        XCTAssertEqual(store.pets.count, 1)
    }

    func testNewPetsAreCreatedAsSpriteSheetsOnly() throws {
        let container = try makeInMemoryContainer()
        let store = PetStore(modelContainer: container, legacyJSONURL: nil)

        let pet = try store.createPet(
            name: "自定义",
            prompt: "你很活泼。",
            sourceURL: nil
        )

        XCTAssertEqual(pet.assetKind, .spriteSheet)
        XCTAssertEqual(store.pet(with: pet.id)?.assetKind, .spriteSheet)
    }

    func testCreatedPetStoresPromptAndClearsLegacyCatchphrase() throws {
        let container = try makeInMemoryContainer()
        let store = PetStore(modelContainer: container, legacyJSONURL: nil)

        let pet = try store.createPet(
            name: "小灰",
            prompt: "你是小灰，喜欢坐在屏幕角落安静陪伴用户。",
            sourceURL: nil
        )

        XCTAssertEqual(pet.name, "小灰")
        XCTAssertEqual(pet.prompt, "你是小灰，喜欢坐在屏幕角落安静陪伴用户。")
        XCTAssertEqual(pet.catchphrase, "")
        XCTAssertEqual(store.pet(with: pet.id)?.profile.prompt, pet.prompt)
    }

    func testPetPromptCannotExceedLimit() throws {
        let container = try makeInMemoryContainer()
        let store = PetStore(modelContainer: container, legacyJSONURL: nil)
        let longPrompt = String(repeating: "设", count: 2001)

        XCTAssertThrowsError(try store.createPet(
            name: "长设定",
            prompt: longPrompt,
            sourceURL: nil
        )) { error in
            XCTAssertEqual(error.localizedDescription, "设定最多 2000 字。")
        }
    }

    func testStoreUpdatesPetNameAndPromptWithoutChangingAsset() throws {
        let container = try makeInMemoryContainer()
        let store = PetStore(modelContainer: container, legacyJSONURL: nil)
        let pet = try store.createPet(
            name: "旧名字",
            prompt: "旧设定",
            sourceURL: nil
        )

        try store.updatePetSettings(
            pet.id,
            name: "新名字",
            prompt: "新设定：说话像认真工作的伙伴。"
        )

        let updated = try XCTUnwrap(store.pet(with: pet.id))
        XCTAssertEqual(updated.name, "新名字")
        XCTAssertEqual(updated.prompt, "新设定：说话像认真工作的伙伴。")
        XCTAssertEqual(updated.assetFileName, pet.assetFileName)
        XCTAssertEqual(updated.assetKind, pet.assetKind)
    }

    func testMigratesLegacyJSONIntoSwiftDataOnce() throws {
        let container = try makeInMemoryContainer()
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let jsonURL = directory.appending(path: "pets.json", directoryHint: .notDirectory)
        let petID = UUID()
        let legacyPet = PetRecord(
            id: petID,
            name: "旧宠物",
            prompt: "你是旧宠物，喜欢怀旧。",
            assetFileName: "legacy.webp",
            assetKind: .spriteSheet,
            isActive: true,
            messages: [
                ChatRecord(role: .pet, text: "我从 JSON 来")
            ]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode([legacyPet]).write(to: jsonURL)

        let store = PetStore(modelContainer: container, legacyJSONURL: jsonURL)

        XCTAssertEqual(store.pets.count, 1)
        XCTAssertEqual(store.activePet?.id, petID)
        XCTAssertEqual(store.activePet?.prompt, "你是旧宠物，喜欢怀旧。")
        XCTAssertEqual(store.activePet?.messages.first?.text, "我从 JSON 来")
        XCTAssertFalse(FileManager.default.fileExists(atPath: jsonURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: jsonURL.appendingPathExtension("migrated").path))
    }

    func testMigratesLegacyJSONWithoutBundledFlag() throws {
        let container = try makeInMemoryContainer()
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let jsonURL = directory.appending(path: "pets.json", directoryHint: .notDirectory)
        let petID = UUID().uuidString
        let json = """
        [{
          "id": "\(petID)",
          "name": "旧宠物",
          "personality": "怀旧",
          "catchphrase": "还在",
          "assetFileName": "legacy.webp",
          "assetKind": "spriteSheet",
          "spriteSpecID": "codex-mainey",
          "isActive": true,
          "windowX": 1120,
          "windowY": 180,
          "scale": 1,
          "createdAt": "2026-05-26T10:00:00Z",
          "messages": []
        }]
        """
        try Data(json.utf8).write(to: jsonURL)

        let store = PetStore(modelContainer: container, legacyJSONURL: jsonURL)

        XCTAssertEqual(store.pets.count, 1)
        XCTAssertEqual(store.activePet?.id.uuidString.uppercased(), petID.uppercased())
        XCTAssertTrue(store.activePet?.prompt.contains("怀旧") == true)
        XCTAssertTrue(store.activePet?.prompt.contains("还在") == true)
    }

    func testLocalMockReplyUsesPetVoiceAndStaysWithinBubbleLimit() async {
        let provider = LocalMockChatProvider()
        let pet = PetProfile(name: "Mainey", prompt: "你黏人、爱鼓励人，说话会轻轻喵一声。")

        let reply = await provider.reply(to: "你好，今天写代码好累", pet: pet, history: [])

        XCTAssertLessThanOrEqual(reply.count, 50)
        XCTAssertTrue(reply.contains("Mainey") || reply.contains("喵"))
    }

    func testLocalMockReplyStreamsMultipleChunksToFinalReply() async throws {
        let provider = LocalMockChatProvider()
        let pet = PetProfile(name: "Mainey", prompt: "你黏人、爱鼓励人。")
        let expected = await provider.reply(to: "你好", pet: pet, history: [])
        var chunks: [String] = []

        for try await chunk in provider.replyStream(to: "你好", pet: pet, history: []) {
            chunks.append(chunk)
        }

        XCTAssertGreaterThan(chunks.count, 1)
        XCTAssertEqual(chunks.joined(), expected)
    }

    func testDesktopPetAppIconUsesBundledPNGResource() throws {
        let url = try XCTUnwrap(DesktopPetAppIcon.resourceURL())
        XCTAssertEqual(url.lastPathComponent, "DesktopPetIcon.png")
        XCTAssertNotNil(DesktopPetAppIcon.iconImage(resourceURL: url))
    }

    func testDesktopPetAppIconLoadsImageFromURL() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "test-icon.png", directoryHint: .notDirectory)
        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 2, height: 2).fill()
        image.unlockFocus()
        let tiffData = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiffData))
        let pngData = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try pngData.write(to: url)
        let loadedImage = try XCTUnwrap(DesktopPetAppIcon.iconImage(resourceURL: url))
        XCTAssertEqual(Int(loadedImage.size.width), 2)
        XCTAssertEqual(Int(loadedImage.size.height), 2)
    }

    func testOpenAICompatibleRequestBuilderCreatesMiniMaxChatCompletionRequest() throws {
        let config = OpenAICompatibleChatConfiguration(
            baseURL: URL(string: "https://api.minimax.io/v1")!,
            apiKey: "test-key",
            model: "MiniMax-M2.7"
        )
        let pet = PetProfile(name: "Mainey", prompt: "你是 Mainey，黏人但不打扰，回复要简短温暖。")
        let history = [
            ChatTurn(role: .user, text: "上一句"),
            ChatTurn(role: .pet, text: "上一句回复")
        ]

        let request = try OpenAICompatibleRequestBuilder.request(
            input: "你好",
            pet: pet,
            history: history,
            configuration: config
        )

        XCTAssertEqual(request.url?.absoluteString, "https://api.minimax.io/v1/chat/completions")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "MiniMax-M2.7")
        XCTAssertEqual(json["stream"] as? Bool, true)
        XCTAssertEqual(json["reasoning_split"] as? Bool, true)
        XCTAssertEqual(json["max_completion_tokens"] as? Int, 160)

        let messages = try XCTUnwrap(json["messages"] as? [[String: String]])
        XCTAssertEqual(messages.map { $0["role"] }, ["system", "user", "assistant", "user"])
        XCTAssertTrue(messages[0]["content"]?.contains("Mainey") == true)
        XCTAssertTrue(messages[0]["content"]?.contains("黏人但不打扰") == true)
        XCTAssertFalse(messages[0]["content"]?.contains("口头禅") == true)
        XCTAssertEqual(messages.last?["content"], "你好")
    }

    func testOpenAICompatibleStreamParserExtractsContentAndSkipsReasoning() throws {
        var parser = OpenAICompatibleStreamParser()

        let first = try parser.contentChunk(fromSSELine: #"data: {"choices":[{"delta":{"content":"你"}}]}"#)
        let reasoning = try parser.contentChunk(fromSSELine: #"data: {"choices":[{"delta":{"reasoning_details":"思考"}}]}"#)
        let cumulative = try parser.contentChunk(fromSSELine: #"data: {"choices":[{"delta":{"content":"你好"}}]}"#)
        let done = try parser.contentChunk(fromSSELine: "data: [DONE]")

        XCTAssertEqual(first, "你")
        XCTAssertEqual(reasoning, nil)
        XCTAssertEqual(cumulative, "好")
        XCTAssertEqual(done, nil)
    }

    func testAnthropicCompatibleRequestBuilderCreatesMiniMaxMessagesRequest() throws {
        let config = AnthropicCompatibleChatConfiguration(
            baseURL: URL(string: "https://api.minimaxi.com/anthropic")!,
            apiKey: "test-key",
            model: "MiniMax-M2.7"
        )
        let pet = PetProfile(name: "Mainey", prompt: "你是 Mainey，黏人但不打扰，回复要简短温暖。")
        let history = [
            ChatTurn(role: .user, text: "上一句"),
            ChatTurn(role: .pet, text: "上一句回复")
        ]

        let request = try AnthropicCompatibleRequestBuilder.request(
            input: "你好",
            pet: pet,
            history: history,
            configuration: config
        )

        XCTAssertEqual(request.url?.absoluteString, "https://api.minimaxi.com/anthropic/v1/messages")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Api-Key"), "test-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Anthropic-Version"), "2023-06-01")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "MiniMax-M2.7")
        XCTAssertEqual(json["stream"] as? Bool, true)
        XCTAssertEqual(json["max_tokens"] as? Int, 160)
        XCTAssertTrue((json["system"] as? String)?.contains("Mainey") == true)
        XCTAssertTrue((json["system"] as? String)?.contains("黏人但不打扰") == true)
        XCTAssertFalse((json["system"] as? String)?.contains("口头禅") == true)

        let messages = try XCTUnwrap(json["messages"] as? [[String: String]])
        XCTAssertEqual(messages.map { $0["role"] }, ["user", "assistant", "user"])
        XCTAssertEqual(messages.last?["content"], "你好")
    }

    func testAnthropicCompatibleStreamParserExtractsTextDelta() throws {
        let parser = AnthropicCompatibleStreamParser()

        let event = try parser.contentChunk(fromSSELine: "event: content_block_delta")
        let first = try parser.contentChunk(fromSSELine: #"data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"你"}}"#)
        let ping = try parser.contentChunk(fromSSELine: #"data: {"type":"ping"}"#)
        let second = try parser.contentChunk(fromSSELine: #"data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"好"}}"#)
        let stop = try parser.contentChunk(fromSSELine: #"data: {"type":"message_stop"}"#)
        let done = try parser.contentChunk(fromSSELine: "data: [DONE]")

        XCTAssertNil(event)
        XCTAssertEqual(first, "你")
        XCTAssertNil(ping)
        XCTAssertEqual(second, "好")
        XCTAssertNil(stop)
        XCTAssertNil(done)
    }

    func testChatSettingsStoreDoesNotReadKeychainOnInitializationOrProviderCreation() {
        let defaults = makeIsolatedDefaults()
        defaults.set(ChatProviderMode.anthropicCompatible.rawValue, forKey: "chat.mode")
        defaults.set(true, forKey: "chat.hasAPIKey")
        let readCounter = ReadCounter()
        let keychain = APIKeychain(
            readAPIKey: {
                readCounter.increment()
                return "secret-key"
            },
            saveAPIKey: { _ in },
            deleteAPIKey: {}
        )

        let store = ChatSettingsStore(defaults: defaults, keychain: keychain)
        _ = store.makeProvider()

        XCTAssertTrue(store.hasAPIKey)
        XCTAssertEqual(readCounter.count, 0)
    }

    func testChatSettingsProviderReadsKeychainOnlyWhenStreamingAndSurfacesReadError() async {
        let defaults = makeIsolatedDefaults()
        defaults.set(ChatProviderMode.anthropicCompatible.rawValue, forKey: "chat.mode")
        defaults.set(true, forKey: "chat.hasAPIKey")
        let readCounter = ReadCounter()
        let keychain = APIKeychain(
            readAPIKey: {
                readCounter.increment()
                throw DeniedKeychainError()
            },
            saveAPIKey: { _ in },
            deleteAPIKey: {}
        )
        let store = ChatSettingsStore(defaults: defaults, keychain: keychain)
        let provider = store.makeProvider()
        let pet = PetProfile(name: "Mainey", prompt: "你是 Mainey，回复要简短温暖。")

        do {
            for try await _ in provider.replyStream(to: "你好", pet: pet, history: []) {}
            XCTFail("Expected keychain read failure")
        } catch {
            XCTAssertEqual(error.localizedDescription, "钥匙串拒绝读取")
        }

        XCTAssertEqual(readCounter.count, 1)
    }

    func testChatSettingsAPIKeyCacheReadsKeychainOnlyOncePerStoredValue() throws {
        let readCounter = ReadCounter()
        let cache = APIKeyCache(keychain: APIKeychain(
            readAPIKey: {
                readCounter.increment()
                return "secret-key"
            },
            saveAPIKey: { _ in },
            deleteAPIKey: {}
        ))

        XCTAssertEqual(try cache.readAPIKey(), "secret-key")
        XCTAssertEqual(try cache.readAPIKey(), "secret-key")
        XCTAssertEqual(readCounter.count, 1)
    }

    func testChatSettingsAPIKeyCacheSerializesConcurrentReads() {
        let readCounter = ReadCounter()
        let cache = APIKeyCache(keychain: APIKeychain(
            readAPIKey: {
                readCounter.increment()
                Thread.sleep(forTimeInterval: 0.03)
                return "secret-key"
            },
            saveAPIKey: { _ in },
            deleteAPIKey: {}
        ))

        DispatchQueue.concurrentPerform(iterations: 4) { _ in
            let value = try? cache.readAPIKey()
            XCTAssertEqual(value, "secret-key")
        }

        XCTAssertEqual(readCounter.count, 1)
    }

    func testDesktopPetLaunchPolicyKeepsDockEntryAvailable() {
        XCTAssertEqual(DesktopPetActivationPolicy.launchPolicy, .regular)
    }

    func testActionEnginePrioritizesDirectionalDragAndReplyStates() {
        var engine = PetActionEngine()

        XCTAssertEqual(engine.handle(.hoverBegan), .hover)
        XCTAssertEqual(engine.handle(.dragChanged(.right)), .dragRight)
        XCTAssertEqual(engine.handle(.hoverEnded), .dragRight)
        XCTAssertEqual(engine.handle(.dragChanged(.left)), .dragLeft)
        XCTAssertEqual(engine.handle(.dragEnded), .idle)
        XCTAssertEqual(engine.handle(.thinkingBegan), .thinking)
        XCTAssertEqual(engine.handle(.replyingBegan), .replying)
        XCTAssertEqual(engine.handle(.replySucceeded), .replyDone)
        XCTAssertEqual(engine.handle(.idleTick), .idle)
    }

    func testFloatingPetControllerDoesNotPublishWhenActionIsUnchanged() {
        let controller = FloatingPetController()
        var publishCount = 0
        let cancellable = controller.objectWillChange.sink {
            publishCount += 1
        }

        controller.handle(.dragChanged(.right))
        controller.handle(.dragChanged(.right))

        XCTAssertEqual(controller.action, .dragRight)
        XCTAssertEqual(publishCount, 1)
        withExtendedLifetime(cancellable) {}
    }

    func testFloatingPetPanelOnlyBecomesKeyWhenTextInputIsEnabled() {
        let panel = FloatingPetPanel(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 120),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        panel.configureForDesktopPet()
        XCTAssertFalse(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)

        panel.allowsKeyInput = true
        XCTAssertTrue(panel.canBecomeKey)
        XCTAssertTrue(panel.canBecomeMain)
    }

    func testFloatingPetPanelFloatsAcrossSpacesAndFullscreenWithoutStationaryPinning() {
        let panel = FloatingPetPanel(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 120),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.configureForDesktopPet()

        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
        XCTAssertTrue(panel.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(panel.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertTrue(panel.collectionBehavior.contains(.ignoresCycle))
        XCTAssertFalse(panel.collectionBehavior.contains(.transient))
        XCTAssertFalse(panel.collectionBehavior.contains(.stationary))
        XCTAssertGreaterThan(panel.level.rawValue, NSWindow.Level.floating.rawValue)
    }

    func testDesktopInputFocusRetryPolicyWaitsForActiveApplicationAndKeyWindow() {
        XCTAssertTrue(DesktopInputFocusRetryPolicy.shouldRetry(
            isApplicationActive: false,
            isWindowKey: true,
            didAcceptFirstResponder: true
        ))
        XCTAssertFalse(DesktopInputFocusRetryPolicy.shouldRetry(
            isApplicationActive: false,
            isWindowKey: true,
            didAcceptFirstResponder: true,
            allowsNonActiveApplication: true
        ))
        XCTAssertTrue(DesktopInputFocusRetryPolicy.shouldRetry(
            isApplicationActive: true,
            isWindowKey: false,
            didAcceptFirstResponder: true
        ))
        XCTAssertTrue(DesktopInputFocusRetryPolicy.shouldRetry(
            isApplicationActive: true,
            isWindowKey: true,
            didAcceptFirstResponder: false
        ))
        XCTAssertFalse(DesktopInputFocusRetryPolicy.shouldRetry(
            isApplicationActive: true,
            isWindowKey: true,
            didAcceptFirstResponder: true
        ))
    }

    func testFloatingDragGeometryUsesScreenCoordinatesWithoutLagCompensation() {
        let origin = FloatingDragGeometry.panelOrigin(
            startPanelOrigin: NSPoint(x: 100, y: 200),
            startMouseLocation: NSPoint(x: 320, y: 420),
            currentMouseLocation: NSPoint(x: 470, y: 360)
        )

        XCTAssertEqual(origin, NSPoint(x: 250, y: 140))
        XCTAssertEqual(
            FloatingDragGeometry.direction(
                startMouseLocation: NSPoint(x: 320, y: 420),
                currentMouseLocation: NSPoint(x: 470, y: 360)
            ),
            .right
        )
    }

    func testFloatingPetWindowPlacementKeepsPanelOnVisibleScreen() {
        let origin = FloatingPetWindowPlacement.visibleOrigin(
            preferredOrigin: CGPoint(x: 2_000, y: -200),
            size: CGSize(width: 120, height: 100),
            visibleFrames: [CGRect(x: 0, y: 0, width: 1440, height: 900)]
        )

        XCTAssertEqual(origin.x, 1308)
        XCTAssertEqual(origin.y, 12)
    }

    func testMaineySpriteSheetUsesDetectedPackedFrameRects() {
        let spec = SpriteSheetSpec.codexMainey
        let firstFrame = spec.frameRect(for: 0)

        XCTAssertEqual(spec.frameCount, 57)
        XCTAssertEqual(firstFrame, SpriteFrameRect(minX: 7, minY: 5, width: 178, height: 198))
        XCTAssertGreaterThan(Set((0..<8).map { spec.frameIndex(for: .dragRight, tick: $0) }).count, 4)
    }

    func testMaineySpriteSheetUsesNineRowActionProtocol() {
        let spec = SpriteSheetSpec.codexMainey

        XCTAssertEqual(spec.actions[.idle], [0, 1, 2, 3, 4, 5])
        XCTAssertEqual(spec.actions[.dragRight], [6, 7, 8, 9, 10, 11, 12, 13])
        XCTAssertEqual(spec.actions[.dragLeft], [14, 15, 16, 17, 18, 19, 20, 21])
        XCTAssertEqual(spec.actions[.wake], [22, 23, 24, 25])
        XCTAssertEqual(spec.actions[.hover], [26, 27, 28, 29, 30])
        XCTAssertEqual(spec.actions[.replyError], [31, 32, 33, 34, 35, 36, 37, 38])
        XCTAssertEqual(spec.actions[.replyDone], [39, 40, 41, 42, 43, 44])
        XCTAssertEqual(spec.actions[.thinking], [45, 46, 47, 48, 49, 50])
        XCTAssertEqual(spec.actions[.replying], [51, 52, 53, 54, 55, 56])
    }

    func testNineRowSpriteSheetAnalyzerBuildsActionsByRowsLeftToRight() {
        let rows: [[ClosedRange<Int>]] = [
            [2...9, 20...29],
            [40...49, 4...11, 22...30],
            [3...13],
            [6...14, 25...34],
            [5...12],
            [7...15],
            [1...8, 16...23, 32...39],
            [10...18],
            [2...10, 24...32]
        ]

        let spec = NineRowSpriteSheetAnalyzer.spec(
            imageWidth: 54,
            imageHeight: 90,
            framesPerSecond: 9
        ) { x, y in
            let row = y / 10
            guard rows.indices.contains(row) else { return false }
            return rows[row].contains { $0.contains(x) }
        }

        XCTAssertEqual(spec.actions[.idle], [0, 1])
        XCTAssertEqual(spec.actions[.dragRight], [2, 3, 4])
        XCTAssertEqual(spec.frameRect(for: 2).minX, 4)
        XCTAssertEqual(spec.frameRect(for: 4).minX, 40)
        XCTAssertEqual(spec.actions[.dragLeft], [5])
        XCTAssertEqual(spec.actions[.wake], [6, 7])
        XCTAssertEqual(spec.actions[.hover], [8])
        XCTAssertEqual(spec.actions[.replyError], [9])
        XCTAssertEqual(spec.actions[.replyDone], [10, 11, 12])
        XCTAssertEqual(spec.actions[.thinking], [13])
        XCTAssertEqual(spec.actions[.replying], [14, 15])
    }

    func testMaineyWebPParsesAsNineRowsFromAlpha() throws {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appending(path: "Sources/DesktopPetApp/Resources/MaineySpritesheet.webp")

        let spec = try XCTUnwrap(NineRowSpriteSheetAnalyzer.spec(for: url))

        XCTAssertEqual(spec.actions[.idle]?.count, 6)
        XCTAssertEqual(spec.actions[.dragRight]?.count, 8)
        XCTAssertEqual(spec.actions[.dragLeft]?.count, 8)
        XCTAssertEqual(spec.actions[.wake]?.count, 4)
        XCTAssertEqual(spec.actions[.hover]?.count, 5)
        XCTAssertEqual(spec.actions[.replyError]?.count, 8)
        XCTAssertEqual(spec.actions[.replyDone]?.count, 6)
        XCTAssertEqual(spec.actions[.thinking]?.count, 6)
        XCTAssertEqual(spec.actions[.replying]?.count, 6)
        XCTAssertEqual(spec.frameRect(for: try XCTUnwrap(spec.actions[.dragRight]?.first)).minX, 5)
        XCTAssertEqual(spec.frameRect(for: try XCTUnwrap(spec.actions[.dragRight]?.last)).minX, 1351)
    }

    func testSpriteFrameRendererUsesTopOriginFrameRects() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "\(UUID().uuidString)-top-origin.png", directoryHint: .notDirectory)
        try makeTwoColorTestImage().write(to: url)
        let spec = SpriteSheetSpec(
            id: "top-origin-test",
            imageWidth: 12,
            imageHeight: 12,
            columns: 1,
            rows: 1,
            framesPerSecond: 1,
            frameRects: [
                SpriteFrameRect(minX: 0, minY: 0, width: 12, height: 6)
            ],
            actions: [.idle: [0]]
        )

        let image = try XCTUnwrap(SpriteFrameRenderer.shared.image(assetURL: url, spec: spec, frameIndex: 0))
        let pixel = try XCTUnwrap(image.rgbaPixelAtCenter())

        XCTAssertGreaterThan(pixel.red, 200)
        XCTAssertLessThan(pixel.blue, 80)
    }

    func testSpriteFrameRendererNormalizesVariableFrameSizes() throws {
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appending(path: "Sources/DesktopPetApp/Resources/MaineySpritesheet.webp")
        let spec = try XCTUnwrap(NineRowSpriteSheetAnalyzer.spec(for: url))
        let frames = try XCTUnwrap(spec.actions[.dragRight])

        let firstImage = try XCTUnwrap(SpriteFrameRenderer.shared.image(assetURL: url, spec: spec, frameIndex: frames[0]))
        let secondImage = try XCTUnwrap(SpriteFrameRenderer.shared.image(assetURL: url, spec: spec, frameIndex: frames[1]))

        XCTAssertEqual(firstImage.size, secondImage.size)
        XCTAssertEqual(firstImage.size.width, CGFloat(spec.maxFrameWidth))
        XCTAssertEqual(firstImage.size.height, CGFloat(spec.maxFrameHeight))
    }

    func testFloatingAvatarSizeUsesTwoThirdsDesktopScaleForSpriteSheets() {
        let pet = PetRecord(
            name: "Mainey",
            prompt: "你是 Mainey。",
            assetFileName: "missing.webp",
            assetKind: .spriteSheet
        )
        let size = PetDisplayMetrics.avatarSize(for: pet)

        XCTAssertEqual(size.width, CGFloat(SpriteSheetSpec.codexMainey.maxFrameWidth) * 2 / 3, accuracy: 0.01)
        XCTAssertEqual(size.height, CGFloat(SpriteSheetSpec.codexMainey.maxFrameHeight) * 2 / 3, accuracy: 0.01)
    }

    func testIdleAnimationStaysStillMostOfTheTimeAndOccasionallyMoves() {
        let policy = PetAnimationPolicy()
        let spec = SpriteSheetSpec.codexMainey
        let idleFrames = (0..<120).map { policy.frameIndex(for: .idle, tick: $0, spec: spec) }

        XCTAssertGreaterThan(idleFrames.filter { $0 == spec.frameIndex(for: .idle, tick: 0) }.count, 100)
        XCTAssertGreaterThan(Set(idleFrames).count, 1)
    }

    func testInteractiveAnimationsUseResponsiveCadence() {
        let policy = PetAnimationPolicy()
        let spec = SpriteSheetSpec.codexMainey
        let dragFrames = (0..<18).map { policy.frameIndex(for: .dragRight, tick: $0, spec: spec) }
        let wakeFrames = (0..<8).map { policy.frameIndex(for: .wake, tick: $0, spec: spec) }

        XCTAssertGreaterThan(Set(dragFrames).count, 4)
        XCTAssertGreaterThan(Set(wakeFrames).count, 2)
    }

    func testReplyAnimationsUseReadableCadence() {
        let policy = PetAnimationPolicy()
        let spec = SpriteSheetSpec.codexMainey
        let replyingFrames = (0..<12).map { policy.frameIndex(for: .replying, tick: $0, spec: spec) }
        let replyDoneFrames = (0..<12).map { policy.frameIndex(for: .replyDone, tick: $0, spec: spec) }

        XCTAssertEqual(replyingFrames[0], replyingFrames[3])
        XCTAssertLessThanOrEqual(Set(replyingFrames).count, 3)
        XCTAssertEqual(replyDoneFrames[0], replyDoneFrames[4])
        XCTAssertLessThanOrEqual(Set(replyDoneFrames).count, 3)
    }

    func testReplyPresentationPacerKeepsThinkingVisibleBriefly() {
        let startedAt = Date(timeIntervalSince1970: 100)
        let soonAfter = Date(timeIntervalSince1970: 100.2)
        let lateAfter = Date(timeIntervalSince1970: 101)

        XCTAssertEqual(
            ReplyPresentationPacer.remainingThinkingDelay(startedAt: startedAt, now: soonAfter),
            0.4,
            accuracy: 0.01
        )
        XCTAssertEqual(
            ReplyPresentationPacer.remainingThinkingDelay(startedAt: startedAt, now: lateAfter),
            0,
            accuracy: 0.01
        )
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([PetEntity.self, ChatMessageEntity.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "DesktopPetTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeTwoColorTestImage() throws -> Data {
        let width = 12
        let height = 12
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                if y < height / 2 {
                    pixels[offset] = 255
                    pixels[offset + 1] = 0
                    pixels[offset + 2] = 0
                } else {
                    pixels[offset] = 0
                    pixels[offset + 1] = 0
                    pixels[offset + 2] = 255
                }
                pixels[offset + 3] = 255
            }
        }

        let context = try XCTUnwrap(CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ))
        let image = try XCTUnwrap(context.makeImage())
        let representation = NSBitmapImageRep(cgImage: image)
        return try XCTUnwrap(representation.representation(using: .png, properties: [:]))
    }
}

private struct DeniedKeychainError: LocalizedError {
    var errorDescription: String? { "钥匙串拒绝读取" }
}

private final class ReadCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    var count: Int {
        lock.withLock { value }
    }

    func increment() {
        lock.withLock {
            value += 1
        }
    }
}

private extension NSImage {
    func rgbaPixelAtCenter() -> (red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8)? {
        var proposedRect = NSRect(origin: .zero, size: size)
        guard let cgImage = cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return nil
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let x = width / 2
        let y = height / 2
        let offset = y * bytesPerRow + x * bytesPerPixel
        return (pixels[offset], pixels[offset + 1], pixels[offset + 2], pixels[offset + 3])
    }
}
