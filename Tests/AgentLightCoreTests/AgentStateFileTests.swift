import Foundation
import Testing
@testable import AgentLightCore

@Test("state persists across short-lived hook helper processes")
func statePersistsAcrossInstances() throws {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let url = directory.appending(path: "state.json")
    defer { try? FileManager.default.removeItem(at: directory) }

    let first = AgentStateFile(url: url)
    #expect(try first.apply(.init(provider: .codex, sessionID: "one", status: .working), now: 100)
            == .working)

    let second = AgentStateFile(url: url)
    #expect(try second.apply(.init(provider: .claudeCode, sessionID: "two", status: .complete), now: 101)
            == nil)

    let snapshot = try second.load()
    #expect(snapshot.sessions.count == 2)
}

@Test("repeated lifecycle events are coalesced instead of resending BLE frames")
func repeatedEventsAreCoalesced() throws {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = AgentStateFile(url: directory.appending(path: "state.json"))

    #expect(try file.apply(.init(provider: .codex, sessionID: "one", status: .working), now: 100)
            == .working)
    #expect(try file.apply(.init(provider: .codex, sessionID: "one", status: .working), now: 101)
            == nil)
}

@Test("forced hook deliveries persist a monotonic revision across helper processes")
func forcedDeliveryRevisionPersists() throws {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "state.json")

    let first = AgentStateFile(url: url)
    _ = try first.apply(.init(
        provider: .codex,
        sessionID: "one",
        status: .working,
        forceDelivery: true
    ), now: 100)

    let second = AgentStateFile(url: url)
    _ = try second.apply(.init(
        provider: .codex,
        sessionID: "one",
        status: .working,
        forceDelivery: true
    ), now: 100)

    #expect(try second.load().deliveryRevision == 2)
}

@Test("state files written before delivery revisions remain readable")
func legacyStateWithoutDeliveryRevisionLoads() throws {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let url = directory.appending(path: "state.json")
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data(#"{"sessions":[]}"#.utf8).write(to: url)

    let state = try AgentStateFile(url: url).load()
    #expect(state.sessions.isEmpty)
    #expect(state.deliveryRevision == nil)
}

@Test("a missing state file starts empty")
func missingStateStartsEmpty() throws {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: directory) }

    let file = AgentStateFile(url: directory.appending(path: "state.json"))
    #expect(try file.load() == AgentState())
}

@Test("a damaged transient state file repairs itself on the next event")
func damagedStateRepairsOnNextEvent() throws {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let url = directory.appending(path: "state.json")
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data("not-json".utf8).write(to: url)

    let file = AgentStateFile(url: url)
    #expect(try file.apply(.init(provider: .codex, sessionID: "one", status: .working), now: 100)
            == .working)
    #expect(try file.load().sessions.count == 1)
}

@Test("hook helpers use the timing file stored beside agent state")
func stateFileUsesPersistedTiming() throws {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let stateURL = directory.appending(path: "state.json")
    let timingURL = directory.appending(path: "timing.json")
    defer { try? FileManager.default.removeItem(at: directory) }

    AgentStateTimingStore(url: timingURL).save(AgentStateTiming(
        completionSeconds: 5,
        errorSeconds: 8,
        workingTimeoutSeconds: 60,
        waitingTimeoutSeconds: 60
    ))
    let file = AgentStateFile(url: stateURL, timingURL: timingURL)
    #expect(try file.apply(.init(provider: .codex, sessionID: "one", status: .complete), now: 100)
            == .complete)
    #expect(try file.apply(.init(provider: .codex, sessionID: "two", status: .idle), now: 106)
            == nil)
    #expect(try file.load().sessions.isEmpty)
}
