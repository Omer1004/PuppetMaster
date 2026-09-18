# The microphone crash on device

Reported 2026-09-18: pressing **Talk** on a real iPhone terminates the app. The
Simulator never showed it. No device crash report had synced to the Mac, so this was
diagnosed by reading the audio layer against AVFoundation's documented contract rather
than from a stack trace — see *Confirming it* at the bottom.

## Why the Simulator could never have caught it

`MicAmplitudeSource.isInputUsable` returns `false` unconditionally under
`targetEnvironment(simulator)`. That guard exists for a good reason (an earlier, real
SIGABRT inside AURemoteIO), but its side effect is that **the entire microphone path,
including the audio session category switch, only ever executes on hardware**. Every
defect below is device-only by construction.

## Root cause

The audio layer treated the audio session and its two engines as static. On a real
device they are dynamic, and every consequence of that was unhandled.

The app runs **two** `AVAudioEngine` instances against **one** process-wide
`AVAudioSession`:

| Engine | Started | Session category it expects |
|---|---|---|
| `SoundBank` | at scene activation, runs all session | `.playback` |
| `MicAmplitudeSource` | while Talk is held | `.playAndRecord` |

Pressing Talk switched the shared session from `.playback` to `.playAndRecord` **while
the sound engine was running**. That is a documented reconfiguration trigger: the
hardware format changes, `AVAudioEngine` stops itself, and every connection made with
an explicit format is invalidated. Nothing in the app observed
`AVAudioEngine.configurationChangeNotification`, `AVAudioSession.interruptionNotification`,
`routeChangeNotification` or `mediaServicesWereResetNotification`.

### Crash mechanism A — tap format mismatch

`installTap(onBus:bufferSize:format:)` asserts that the format handed to it matches the
input hardware format. Violating it raises an `NSException`, which is **not** a Swift
error — no `do`/`catch` can contain it, so the process aborts.

Two ways the old code could violate it:

1. It read `input.outputFormat(forBus: 0)` immediately after `setActive(true)`. The
   engine learns about a session reconfiguration *asynchronously*, so that read could
   return the pre-switch format.
2. The tap was installed once and guarded by `isTapped`, so it was **never reinstalled**.
   Any route change between one Talk press and the next — AirPods connecting, a call
   ending — changes the hardware format while the tap keeps the old one.

### Crash mechanism B — playing into a reconfigured engine

`SoundBank` gated playback on its own `isRunning` flag, set once at start and never
cleared by anything the *system* did. After the session switch stopped the engine
underneath it, that flag still said `true`. `stopAll()` calls `player.play()`, and
`AVAudioPlayerNode.play()` on a node whose engine is not running raises
`required condition is false: _engine->IsRunning()` — again an `NSException`, again an
abort.

### Leak C — the session was left upgraded

`start()` called `AudioSession.activateForRecording()` *before* the `isInputUsable`
guard. On the failure path the category was already `.playAndRecord`, and nothing put
it back: `VoiceInput`'s `catch` only set `source = .silly`, and the later `mic.stop()`
early-returned on `guard isRunning`. The app then behaved as a recording app —
system-wide — until it was killed.

## The fix

Defense in depth, because interruptions and route changes happen whether or not this
app switches categories:

1. **The tap is reinstalled on every start**, against a format read at that moment, and
   validated in Swift first (`TapFormatCheck`) against the exact condition AVFAudio
   asserts on. A mismatch is now a thrown error that falls back to the silly voice.
2. **Both engines observe `configurationChangeNotification`** and rebuild.
3. **Both observe interruption and media-services-reset** and recover.
4. **`SoundBank` asks `engine.isRunning`** rather than trusting a cached flag, and never
   calls `play()` on a node in a stopped engine.
5. **The mic engine is fully stopped and untapped on release**, not paused, so the input
   unit is torn down before the session drops back to a category with no input.
6. **The session is always returned to playback** on every failure path.
7. **Bluetooth HFP input is no longer requested.** It would force the whole route to
   telephony quality for the sake of an amplitude reading, and it is a large source of
   format churn. The built-in mic is enough for a puppet's jaw.

`TapFormatCheck` is pure and unit-tested. The AVFoundation glue around it is thin and
correct by construction, because it cannot be tested without hardware.

## Confirming it

This diagnosis is from code and documented contract, not from a stack trace. To confirm
against the real crash, get the report off the phone:

- **Settings → Privacy & Security → Analytics & Improvements → Analytics Data**, find
  `PuppetMaster-<date>.ips`, share it; or
- **Xcode → Window → Devices and Simulators → View Device Logs** with the phone attached.

Look at the exception type. `EXC_CRASH (SIGABRT)` with
`com.apple.coreaudio.avfaudio` in the last exception backtrace confirms mechanism A or
B; the `required condition is false: …` line names which.
