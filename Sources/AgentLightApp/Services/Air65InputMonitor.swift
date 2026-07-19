import AppKit
import Foundation

enum Air65ObservedInput: Equatable, Sendable {
    case functionKey(Int)
    case fnGlobe

    var keyCode: String {
        switch self {
        case .functionKey(let number): "f\(number)"
        case .fnGlobe: "fn_globe"
        }
    }

    static func detect(
        characters: String?,
        functionModifierIsDown: Bool
    ) -> Self? {
        if let scalar = characters?.unicodeScalars.first,
           characters?.unicodeScalars.count == 1 {
            let value = scalar.value
            let f1 = UInt32(0xF704)
            let f35 = UInt32(0xF726)
            if (f1...f35).contains(value) {
                return .functionKey(Int(value - f1) + 1)
            }
        }
        return functionModifierIsDown ? .fnGlobe : nil
    }

    fileprivate static func detect(event: NSEvent) -> Self? {
        detect(
            characters: event.type == .keyDown ? event.charactersIgnoringModifiers : nil,
            functionModifierIsDown: event.type == .flagsChanged
                && event.modifierFlags.contains(.function)
        )
    }
}

@MainActor
final class Air65InputMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var timeoutTask: Task<Void, Never>?
    private var completion: ((Air65ObservedInput) -> Void)?
    private var timeout: (() -> Void)?

    var isRunning: Bool {
        globalMonitor != nil || localMonitor != nil
    }

    func start(
        timeoutSeconds: Int64 = 8,
        completion: @escaping (Air65ObservedInput) -> Void,
        timeout: @escaping () -> Void
    ) {
        stop()
        self.completion = completion
        self.timeout = timeout

        let mask: NSEvent.EventTypeMask = [.keyDown, .flagsChanged]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            guard let observed = Air65ObservedInput.detect(event: event) else { return }
            Task { @MainActor [weak self] in
                self?.finish(with: observed)
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            if let observed = Air65ObservedInput.detect(event: event) {
                Task { @MainActor [weak self] in
                    self?.finish(with: observed)
                }
            }
            return event
        }
        timeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(timeoutSeconds))
            } catch {
                return
            }
            self?.finishWithTimeout()
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        timeoutTask?.cancel()
        timeoutTask = nil
        completion = nil
        timeout = nil
    }

    private func finish(with observed: Air65ObservedInput) {
        let completion = completion
        stop()
        completion?(observed)
    }

    private func finishWithTimeout() {
        let timeout = timeout
        stop()
        timeout?()
    }
}
