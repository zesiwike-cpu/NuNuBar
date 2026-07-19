import Testing
@testable import AgentLightCore

@Test("a working session is not hidden by another session completing")
func workingBeatsComplete() {
    var state = AgentState()
    state.apply(.init(provider: .codex, sessionID: "one", status: .working), now: 100)
    state.apply(.init(provider: .claudeCode, sessionID: "two", status: .complete), now: 101)

    #expect(state.displayCommand(now: 101) == .working)
}

@Test("waiting and errors take priority over ordinary work")
func attentionPriorities() {
    var state = AgentState()
    state.apply(.init(provider: .codex, sessionID: "one", status: .working), now: 100)
    state.apply(.init(provider: .openCode, sessionID: "two", status: .waiting), now: 101)
    #expect(state.displayCommand(now: 101) == .waiting)

    state.apply(.init(provider: .claudeCode, sessionID: "three", status: .error), now: 102)
    #expect(state.displayCommand(now: 102) == .error)
}

@Test("idle removes a session and expired states are pruned")
func idleAndExpiry() {
    var state = AgentState()
    let key = AgentSessionKey(provider: .codex, sessionID: "one")
    state.apply(.init(provider: .codex, sessionID: "one", status: .working), now: 100)
    #expect(state.sessions[key] != nil)

    state.apply(.init(provider: .codex, sessionID: "one", status: .idle), now: 101)
    #expect(state.sessions[key] == nil)

    state.apply(.init(provider: .claudeCode, sessionID: "two", status: .complete), now: 200)
    #expect(state.displayCommand(now: 200 + AgentState.completionRetention + 1) == .idle)
}

@Test("an error is shown briefly and then returns to idle")
func errorExpiry() {
    var state = AgentState()
    state.apply(.init(provider: .antigravity, sessionID: "one", status: .error), now: 200)

    #expect(state.displayCommand(now: 200) == .error)
    #expect(state.displayCommand(now: 200 + AgentState.completionRetention + 1) == .idle)
}

@Test("custom durations expire complete, error, working, and waiting independently")
func customStatusExpiry() {
    let timing = AgentStateTiming(
        completionSeconds: 5,
        errorSeconds: 8,
        workingTimeoutSeconds: 2 * 60,
        waitingTimeoutSeconds: 3 * 60
    )

    var complete = AgentState()
    complete.apply(.init(provider: .codex, sessionID: "one", status: .complete), now: 100, timing: timing)
    #expect(complete.displayCommand(now: 105, timing: timing) == .complete)
    #expect(complete.displayCommand(now: 106, timing: timing) == .idle)

    var error = AgentState()
    error.apply(.init(provider: .codex, sessionID: "one", status: .error), now: 100, timing: timing)
    #expect(error.displayCommand(now: 108, timing: timing) == .error)
    #expect(error.displayCommand(now: 109, timing: timing) == .idle)

    var working = AgentState()
    working.apply(.init(provider: .codex, sessionID: "one", status: .working), now: 100, timing: timing)
    #expect(working.displayCommand(now: 220, timing: timing) == .working)
    #expect(working.displayCommand(now: 221, timing: timing) == .idle)

    var waiting = AgentState()
    waiting.apply(.init(provider: .codex, sessionID: "one", status: .waiting), now: 100, timing: timing)
    #expect(waiting.displayCommand(now: 280, timing: timing) == .waiting)
    #expect(waiting.displayCommand(now: 281, timing: timing) == .idle)
}

@Test("state presentation schedules the earliest exact expiration")
func presentationSchedulesEarliestExpiration() {
    var state = AgentState()
    state.apply(.init(provider: .codex, sessionID: "working", status: .working), now: 100)
    state.apply(.init(provider: .claudeCode, sessionID: "complete", status: .complete), now: 200)

    let beforeExpiry = state.presentation(now: 201)
    #expect(beforeExpiry.command == .working)
    #expect(beforeExpiry.nextExpiration == 200 + AgentState.completionRetention + 1)

    let afterExpiry = state.presentation(now: 200 + AgentState.completionRetention + 1)
    #expect(afterExpiry.command == .working)
    #expect(afterExpiry.nextExpiration == 100 + AgentState.activeRetention + 1)
}

@Test("an empty presentation has no expiration timer")
func emptyPresentationHasNoExpiration() {
    var state = AgentState()
    let presentation = state.presentation(now: 100)

    #expect(presentation.command == .idle)
    #expect(presentation.nextExpiration == nil)
}

@Test("delivery checkpoints advance even when the visible Codex state is unchanged")
func forcedDeliveryRevisionAdvances() {
    var state = AgentState()

    state.apply(.init(
        provider: .codex,
        sessionID: "one",
        status: .working,
        forceDelivery: true
    ), now: 100)
    #expect(state.deliveryRevision == 1)

    state.apply(.init(
        provider: .codex,
        sessionID: "one",
        status: .working
    ), now: 101)
    #expect(state.deliveryRevision == 1)

    state.apply(.init(
        provider: .codex,
        sessionID: "one",
        status: .working,
        forceDelivery: true
    ), now: 101)
    #expect(state.deliveryRevision == 2)
}
