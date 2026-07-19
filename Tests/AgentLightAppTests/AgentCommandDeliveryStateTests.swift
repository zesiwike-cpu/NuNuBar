import AgentLightCore
import Testing
@testable import AgentLightApp

@Test("reconnecting invalidates the last delivered keyboard state")
func reconnectingReplaysTheCurrentState() {
    var delivery = AgentCommandDeliveryState()

    #expect(delivery.shouldSend(.working))
    delivery.markDelivered(.working)
    #expect(!delivery.shouldSend(.working))

    delivery.connectionRestored()

    #expect(delivery.shouldSend(.working))
}

@Test("a failed delivery waits for the HID session to recover")
func failedDeliveryWaitsForRecovery() {
    var delivery = AgentCommandDeliveryState()

    #expect(delivery.shouldSend(.waiting))
    delivery.markFailed()

    #expect(!delivery.shouldSend(.waiting))

    delivery.connectionRestored()

    #expect(delivery.shouldSend(.waiting))
}

@Test("state changes during a HID send are coalesced into one follow-up refresh")
func stateChangesDuringSendAreCoalesced() {
    var activity = AgentDeliveryActivity()

    let began = activity.begin()
    #expect(began)
    activity.requestRefresh()
    activity.requestRefresh()

    let shouldRefresh = activity.finish()
    #expect(shouldRefresh)
    #expect(!activity.isSending)
}

@Test("a completed HID send does not refresh without a new state event")
func completedSendWithoutStateChangeDoesNotRefresh() {
    var activity = AgentDeliveryActivity()

    let began = activity.begin()
    let shouldRefresh = activity.finish()
    #expect(began)
    #expect(!shouldRefresh)
}

@Test("the fallback monitor does not duplicate an in-flight payload")
func inFlightPayloadIsCoalesced() {
    var delivery = AgentCommandDeliveryState()

    #expect(delivery.shouldSend(.waiting))
    delivery.markInFlight(.waiting)
    #expect(!delivery.shouldSend(.waiting))
    #expect(delivery.shouldSend(.complete))

    delivery.markDelivered(.waiting)
    #expect(!delivery.shouldSend(.waiting))
    #expect(delivery.shouldSend(.complete))
}

@Test("changing a light color resends the active state")
func paletteChangesResendTheCurrentState() {
    var delivery = AgentCommandDeliveryState()
    var palette = AgentLightPalette.default

    delivery.markDelivered(.working, palette: palette)
    #expect(!delivery.shouldSend(.working, palette: palette))

    palette.setColor(AgentLightRGBColor(red: 8, green: 16, blue: 24), for: .working)
    #expect(delivery.shouldSend(.working, palette: palette))
}

@Test("changing a light effect resends the active state")
func effectChangesResendTheCurrentState() {
    var delivery = AgentCommandDeliveryState()
    var palette = AgentLightPalette.default

    delivery.markDelivered(.idle, palette: palette)
    #expect(!delivery.shouldSend(.idle, palette: palette))

    palette.setEffect(.blink, for: .idle)
    #expect(delivery.shouldSend(.idle, palette: palette))
}

@Test("a new delivery checkpoint resends an unchanged keyboard state")
func deliveryRevisionResendsCurrentState() {
    var delivery = AgentCommandDeliveryState()

    delivery.markDelivered(.working, deliveryRevision: 3)
    #expect(!delivery.shouldSend(.working, deliveryRevision: 3))
    #expect(delivery.shouldSend(.working, deliveryRevision: 4))
}
