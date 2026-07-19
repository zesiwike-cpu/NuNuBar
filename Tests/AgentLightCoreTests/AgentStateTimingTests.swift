import Foundation
import Testing
@testable import AgentLightCore

@Test("status timing has stable defaults and clamps unsafe values")
func timingDefaultsAndBounds() {
    #expect(AgentStateTiming.default.completionSeconds == 15)
    #expect(AgentStateTiming.default.errorSeconds == 15)
    #expect(AgentStateTiming.default.workingTimeoutSeconds == 15 * 60)
    #expect(AgentStateTiming.default.waitingTimeoutSeconds == 15 * 60)

    let timing = AgentStateTiming(
        completionSeconds: 0,
        errorSeconds: 120,
        workingTimeoutSeconds: 1,
        waitingTimeoutSeconds: 10_000
    )
    #expect(timing.completionSeconds == 1)
    #expect(timing.errorSeconds == 60)
    #expect(timing.workingTimeoutSeconds == 60)
    #expect(timing.waitingTimeoutSeconds == 60 * 60)
}

@Test("partial timing files migrate with defaults")
func partialTimingMigration() throws {
    let data = Data(#"{"completionSeconds":5}"#.utf8)
    let timing = try JSONDecoder().decode(AgentStateTiming.self, from: data)

    #expect(timing.completionSeconds == 5)
    #expect(timing.errorSeconds == AgentStateTiming.default.errorSeconds)
    #expect(timing.workingTimeoutSeconds == AgentStateTiming.default.workingTimeoutSeconds)
    #expect(timing.waitingTimeoutSeconds == AgentStateTiming.default.waitingTimeoutSeconds)
}

@Test("status timing persists beside shared agent state")
func persistedStateTiming() {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let url = directory.appending(path: "timing.json")
    let store = AgentStateTimingStore(url: url)
    defer { try? FileManager.default.removeItem(at: directory) }

    let timing = AgentStateTiming(
        completionSeconds: 5,
        errorSeconds: 8,
        workingTimeoutSeconds: 10 * 60,
        waitingTimeoutSeconds: 20 * 60
    )
    store.save(timing)

    #expect(store.load() == timing)
    #expect((try? FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int) == 0o600)
    store.reset()
    #expect(store.load() == .default)
}
