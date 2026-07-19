import AgentLightCore
import AgentLightHID
import Darwin
import Foundation

@main
struct AgentLightCLI {
    static func main() async {
        do {
            let request = try CommandLineRequest.parse(Array(CommandLine.arguments.dropFirst()))

            switch request {
            case .describe:
                // Enumeration must not replace the device-global Air65 V3 session
                // currently owned by the menu app.
                print(try NuPhyHIDTransport(preparesAir65Session: false).describe())
            case .demo:
                try await runDemo()
            case .recoveryTest(let iterations):
                try await runRecoveryTest(iterations: iterations)
            case .soakTest(let seconds):
                try await runSoakTest(seconds: seconds)
            case .stress(let iterations):
                try await runStress(iterations: iterations)
            case .send(let command):
                try await NuPhyHIDTransport().send(
                    command,
                    palette: AgentLightPaletteStore().load()
                )
            case .hook(let provider, let eventName):
                let payload = FileHandle.standardInput.readDataToEndOfFile()
                if let event = try? HookEventMapper.map(
                    provider: provider,
                    eventName: eventName,
                    payload: payload
                ) {
                    recordAgentEvent(event)
                }
                if let response = HookEventMapper.response(provider: provider, eventName: eventName) {
                    FileHandle.standardOutput.write(response + Data("\n".utf8))
                }
            case .event(let event):
                recordAgentEvent(event)
            }
        } catch {
            fputs("agent-light: \(error)\n", stderr)
            exit(1)
        }
    }

    private static func runDemo() async throws {
        let transport = NuPhyHIDTransport()
        let palette = AgentLightPaletteStore().load()
        let steps: [(String, AgentLightCommand)] = [
            ("working: orange breathe", .working),
            ("complete: green solid", .complete),
            ("waiting: red blink", .waiting),
        ]
        for (label, command) in steps {
            print(label)
            try await transport.send(command, palette: palette)
            try await Task.sleep(for: .seconds(5))
        }
        try await transport.send(.idle, palette: palette)
        print("idle: restored")
    }

    private static func runStress(iterations: Int) async throws {
        let transport = NuPhyHIDTransport()
        let palette = AgentLightPaletteStore().load()
        let sequence: [AgentLightCommand] = [.working, .complete, .waiting, .idle]
        for iteration in 1...iterations {
            for command in sequence {
                try await transport.send(command, palette: palette)
            }
            print("iteration \(iteration)/\(iterations)")
        }
    }

    private static func runRecoveryTest(iterations: Int) async throws {
        let transport = NuPhyHIDTransport()
        let palette = AgentLightPaletteStore().load()
        let sequence: [AgentLightCommand] = [.working, .complete, .waiting, .idle]
        for iteration in 1...iterations {
            transport.rebuildSession()
            try await Task.sleep(for: .milliseconds(300))
            let command = sequence[(iteration - 1) % sequence.count]
            try await transport.send(command, palette: palette)
            print("recovery \(iteration)/\(iterations): \(command)")
        }
        try await transport.send(.idle, palette: palette)
    }

    private static func runSoakTest(seconds: Int) async throws {
        let transport = NuPhyHIDTransport()
        let palette = AgentLightPaletteStore().load()
        let deadline = Date().addingTimeInterval(TimeInterval(seconds))
        let phases: [(AgentLightCommand, TimeInterval)] = [
            (.working, 10),
            (.complete, 5),
            (.waiting, 15),
            (.idle, 5),
        ]
        var phaseIndex = 0

        while Date() < deadline {
            let phase = phases[phaseIndex % phases.count]
            try await transport.send(phase.0, palette: palette)
            let remaining = max(0, deadline.timeIntervalSinceNow)
            let duration = min(phase.1, remaining)
            if duration > 0 {
                try await Task.sleep(for: .milliseconds(Int64(duration * 1_000)))
            }
            phaseIndex += 1
        }
        try await transport.send(.idle, palette: palette)

        let diagnostics = transport.diagnostics()
        print("acknowledged reports: \(diagnostics.acknowledgedAir65Reports)")
        print("report timeouts: \(diagnostics.air65ReportTimeouts)")
        print("session recoveries: \(diagnostics.air65SessionRecoveries)")
        print("active mode: \(diagnostics.air65CurrentMode.map(String.init) ?? "not applicable")")
        guard diagnostics.air65ReportTimeouts == 0,
              diagnostics.air65SessionRecoveries == 0 else {
            throw NuPhyHIDError.protocolFailed("Air65 V3 soak test required recovery")
        }
    }

    private static func recordAgentEvent(_ event: AgentEvent) {
        // Hooks only persist state. The menu app owns HID access and sends the report.
        _ = try? AgentStateFile().record(
            event,
            now: Int64(Date().timeIntervalSince1970)
        )
    }
}
