import AgentLightCore
import AgentLightHID

actor KeyboardController {
    private let transport = NuPhyHIDTransport()

    func connectionStates() -> AsyncStream<NuPhyHIDConnectionState> {
        transport.connectionStates
    }

    func refresh() {
        transport.refresh()
    }

    func rebuildSession() {
        transport.rebuildSession()
    }

    func diagnostics() -> NuPhyHIDDiagnostics {
        transport.diagnostics()
    }

    func readAirV3FirmwareInfo() async throws -> [UInt8] {
        try await transport.readAirV3FirmwareInfo()
    }

    func send(_ command: AgentLightCommand, palette: AgentLightPalette) async throws {
        try await transport.send(command, palette: palette)
    }
}
