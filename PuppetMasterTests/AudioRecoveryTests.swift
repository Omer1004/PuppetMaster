import AVFoundation
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

    /// After a media services reset the session's read-back is stale, so "it already has
    /// that category" cannot be believed and the configuration is applied in full.
    @Test("Only a media services reset makes the session's read-back untrustworthy")
    func onlyAResetMakesTheReadBackStale() {
        #expect(!AudioRecovery.sessionStateIsTrustworthy(after: .mediaServicesReset))
        #expect(AudioRecovery.sessionStateIsTrustworthy(after: .configurationChange))
        #expect(AudioRecovery.sessionStateIsTrustworthy(after: .interruptionEnded))
    }

    /// A new event must not default into any of these answers. If someone adds one, this
    /// fails until they have decided all three — not only the one about the freeze.
    @Test("Every event has been considered, for every decision")
    func everyEventIsAccountedFor() {
        let all = AudioRecovery.Event.allCases
        #expect(all.count == 3)
        #expect(all.filter(AudioRecovery.needsSessionReassertion(after:))
                == [.interruptionEnded, .mediaServicesReset])
        #expect(all.filter(AudioRecovery.needsFreshEngine(after:)) == [.mediaServicesReset])
        #expect(all.filter { !AudioRecovery.sessionStateIsTrustworthy(after: $0) }
                == [.mediaServicesReset])
    }

    /// `AudioSession` refuses upgrades while this flag is set, so it must be set for
    /// exactly the handler's duration — including a nested one — and never leak out.
    @Test("The configuration-change flag covers the handler and nothing else")
    @MainActor
    func handlerFlagIsScoped() {
        #expect(!AudioRecovery.isHandlingConfigurationChange)
        var seenInside = false
        var seenNested = false
        AudioRecovery.handleConfigurationChange {
            seenInside = AudioRecovery.isHandlingConfigurationChange
            AudioRecovery.handleConfigurationChange {
                seenNested = AudioRecovery.isHandlingConfigurationChange
            }
            // Leaving the inner handler must not clear the outer one.
            #expect(AudioRecovery.isHandlingConfigurationChange)
        }
        #expect(seenInside)
        #expect(seenNested)
        #expect(!AudioRecovery.isHandlingConfigurationChange)
    }
}

/// The skip that stops a redundant reconfiguration. It is half of what keeps the freeze
/// away, so it is tested without the real session.
@Suite("Session configuration")
struct SessionConfigurationTests {

    private let recording = SessionConfiguration.recording

    @Test("An identical configuration is not applied again")
    func identicalIsSkipped() {
        #expect(!SessionConfiguration.needsApplying(recording, current: recording,
                                                    lastApplied: nil))
    }

    @Test("A different category is applied")
    func differentCategoryIsApplied() {
        #expect(SessionConfiguration.needsApplying(recording, current: .playback,
                                                   lastApplied: recording))
    }

    /// The old check ignored the mode, so a mode changed underneath us was never put back.
    @Test("A different mode is applied, even with matching category and options")
    func differentModeIsApplied() {
        var current = recording
        current.mode = .voiceChat
        #expect(SessionConfiguration.needsApplying(recording, current: current,
                                                   lastApplied: recording))
    }

    /// iOS can report options back with a bit added or dropped. If what we last applied
    /// is exactly this, asking again would only reconfigure the hardware for nothing.
    @Test("Options iOS normalised after we applied them are not re-applied")
    func normalisedOptionsAreSkipped() {
        var withExtraBit = recording
        withExtraBit.options.insert(.allowAirPlay)
        #expect(!SessionConfiguration.needsApplying(recording, current: withExtraBit,
                                                    lastApplied: recording))

        var withDroppedBit = recording
        withDroppedBit.options.remove(.mixWithOthers)
        #expect(!SessionConfiguration.needsApplying(recording, current: withDroppedBit,
                                                    lastApplied: recording))
    }

    /// Without the evidence that we applied it, a mismatch is a real difference.
    @Test("Different options are applied when we did not set them")
    func foreignOptionsAreApplied() {
        var current = recording
        current.options = [.mixWithOthers]
        #expect(SessionConfiguration.needsApplying(recording, current: current,
                                                   lastApplied: nil))
        #expect(SessionConfiguration.needsApplying(recording, current: current,
                                                   lastApplied: .playback))
    }
}
