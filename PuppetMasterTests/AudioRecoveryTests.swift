import Testing
@testable import PuppetMaster

/// The rule these tests protect shipped broken twice, and the second time it froze the
/// app on device with no crash report. It is worth a suite of its own.
@Suite("Audio recovery")
struct AudioRecoveryTests {

    /// **The one that matters.**
    ///
    /// Applying an audio session category reconfigures the hardware, and reconfiguring
    /// the hardware posts `AVAudioEngineConfigurationChange`. A handler for that
    /// notification that responds by applying a category therefore re-triggers itself.
    /// The notifications arrive on the main queue, so the queue never drains: no crash,
    /// no log, the app simply stops drawing.
    @Test("A configuration change must never re-apply the session")
    func configurationChangeLeavesTheSessionAlone() {
        #expect(!AudioRecovery.needsSessionReassertion(after: .configurationChange))
    }

    /// A phone call or Siri deactivates our session when it starts. Nothing else will
    /// bring it back, and re-activating does not re-trigger this event.
    @Test("An interruption ending does re-apply the session")
    func interruptionEndedReassertsTheSession() {
        #expect(AudioRecovery.needsSessionReassertion(after: .interruptionEnded))
    }

    /// The audio server restarted and took the session's configuration with it.
    @Test("A media services reset re-applies the session")
    func mediaServicesResetReassertsTheSession() {
        #expect(AudioRecovery.needsSessionReassertion(after: .mediaServicesReset))
    }

    /// Only a media services reset invalidates the engine *object*. A configuration
    /// change stops the engine and breaks its connections, but the object survives — and
    /// replacing it there would throw away the installed tap for no reason.
    @Test("Only a media services reset needs a new engine object")
    func onlyAResetNeedsAFreshEngine() {
        #expect(AudioRecovery.needsFreshEngine(after: .mediaServicesReset))
        #expect(!AudioRecovery.needsFreshEngine(after: .configurationChange))
        #expect(!AudioRecovery.needsFreshEngine(after: .interruptionEnded))
    }

    /// A new event must not default into re-applying the session. If someone adds one,
    /// this fails until they have thought about the freeze above.
    @Test("Every event has been considered")
    func everyEventIsAccountedFor() {
        #expect(AudioRecovery.Event.allCases.count == 3)
        let reasserting = AudioRecovery.Event.allCases
            .filter(AudioRecovery.needsSessionReassertion(after:))
        #expect(reasserting == [.interruptionEnded, .mediaServicesReset])
    }
}
