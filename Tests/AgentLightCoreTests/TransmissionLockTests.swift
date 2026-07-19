import Dispatch
import Foundation
import Testing
@testable import AgentLightCore

@Test("separate senders cannot transmit at the same time")
func transmissionLockSerializesSenders() throws {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "transmission.lock")
    let firstEntered = DispatchSemaphore(value: 0)
    let releaseFirst = DispatchSemaphore(value: 0)
    let secondEntered = DispatchSemaphore(value: 0)

    DispatchQueue.global().async {
        try! AgentLightTransmissionLock(url: url).withLock { () -> Void in
            firstEntered.signal()
            releaseFirst.wait()
        }
    }
    #expect(firstEntered.wait(timeout: .now() + 1) == .success)

    DispatchQueue.global().async {
        try! AgentLightTransmissionLock(url: url).withLock { () -> Void in
            secondEntered.signal()
        }
    }
    #expect(secondEntered.wait(timeout: .now() + 0.1) == .timedOut)
    releaseFirst.signal()
    #expect(secondEntered.wait(timeout: .now() + 1) == .success)
}

@Test("the async lock remains exclusive across a suspended operation")
func asyncTransmissionLockSerializesSenders() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "transmission.lock")
    let firstEntered = DispatchSemaphore(value: 0)
    let releaseFirst = DispatchSemaphore(value: 0)
    let secondEntered = DispatchSemaphore(value: 0)

    let first = Task.detached {
        try await AgentLightTransmissionLock(url: url).withAsyncLock {
            firstEntered.signal()
            await withCheckedContinuation { continuation in
                DispatchQueue.global().async {
                    releaseFirst.wait()
                    continuation.resume()
                }
            }
        }
    }
    let firstResult = await waitForSemaphore(firstEntered, timeout: 1)
    #expect(firstResult == .success)

    let second = Task.detached {
        try await AgentLightTransmissionLock(url: url).withAsyncLock {
            _ = secondEntered.signal()
        }
    }
    let earlySecondResult = await waitForSemaphore(secondEntered, timeout: 0.1)
    #expect(earlySecondResult == .timedOut)
    releaseFirst.signal()
    try await first.value
    try await second.value
    let finalSecondResult = await waitForSemaphore(secondEntered, timeout: 1)
    #expect(finalSecondResult == .success)
}

private func waitForSemaphore(
    _ semaphore: DispatchSemaphore,
    timeout: TimeInterval
) async -> DispatchTimeoutResult {
    await withCheckedContinuation { continuation in
        DispatchQueue.global().async {
            continuation.resume(
                returning: semaphore.wait(timeout: .now() + timeout)
            )
        }
    }
}
