import Testing
@testable import AgentLightCore

@Test("status commands map to wire commands")
func statusCommands() throws {
    #expect(try CommandLineRequest.parse(["working"]) == .send(.working))
    #expect(try CommandLineRequest.parse(["waiting"]) == .send(.waiting))
    #expect(try CommandLineRequest.parse(["complete"]) == .send(.complete))
    #expect(try CommandLineRequest.parse(["idle"]) == .send(.idle))
    #expect(try CommandLineRequest.parse(["demo"]) == .demo)
    #expect(try CommandLineRequest.parse(["recovery-test", "10"]) == .recoveryTest(10))
    #expect(try CommandLineRequest.parse(["soak-test", "60"]) == .soakTest(60))
    #expect(try CommandLineRequest.parse(["stress", "20"]) == .stress(20))
}

@Test("commands unsupported by the safe BLE report are not advertised")
func unsupportedLegacyCommands() {
    #expect(throws: CommandLineError.invalidCommand) {
        try CommandLineRequest.parse(["progress", "3"])
    }
    #expect(throws: CommandLineError.invalidCommand) {
        try CommandLineRequest.parse(["color", "0C2238"])
    }
    #expect(throws: CommandLineError.invalidCommand) {
        try CommandLineRequest.parse(["heartbeat"])
    }
}

@Test("hook and explicit agent events identify their provider and session")
func agentEvents() throws {
    #expect(try CommandLineRequest.parse(["hook", "codex", "Stop"]) == .hook(.codex, "Stop"))
    #expect(try CommandLineRequest.parse(["hook", "antigravity", "PreInvocation"])
            == .hook(.antigravity, "PreInvocation"))
    #expect(try CommandLineRequest.parse(["event", "opencode", "working", "session-1"])
            == .event(.init(provider: .openCode, sessionID: "session-1", status: .working)))
    #expect(throws: CommandLineError.invalidCommand) {
        try CommandLineRequest.parse(["event", "opencode", "progress", "session-1", "4"])
    }
}
