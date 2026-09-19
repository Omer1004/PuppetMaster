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

## What the first version of that fix got wrong

Code review found two defects in the seven points above, both invisible in the
Simulator, and both now fixed.

**The two engines fought over the session.** Point 2 said "both engines observe
configuration changes and rebuild" — but `SoundBank.rebuild()` rebuilt by calling
`activateForPlayback()`. The thing that most reliably posts a configuration change *is*
the microphone upgrading the session to `.playAndRecord`. So every Talk press ran:

1. mic upgrades to `.playAndRecord`
2. hardware reconfigures, notification posted
3. sound bank drags the category back to `.playback` **while the button is still held**
4. mic sees that change and upgrades again — back to 2

`AudioSession` now holds an *intent* (`.playback` or `.recording`) and is the single
place that decides. Owners declare what they need; a rebuilding engine calls
`reactivate()`, which re-asserts whatever is currently intended and never changes it.

**Every Talk press tore the mic down and rebuilt it.** Same root cause from the other
side: the mic's own configuration-change handler could not tell its own session upgrade
from a real route change, so it rebuilt on both. It now compares the hardware format
against the one the live tap was installed with — using `TapFormatCheck` again. If the
format has not moved, the graph is still valid and the engine is simply started again.

**And a narrower version of Leak C.** `apply()` swallowed a throw and cleared the
recording flag regardless, so a `setCategory` that failed left the session in
`.playAndRecord` with the flag saying otherwise — the recording indicator stays lit
until the app is killed, and nothing ever retries. The intent now only moves on success,
so the next `returnToPlaybackIfNeeded()` tries again.

## Round three: the freeze

Reported on device against the build that contained the fix above: pressing Hold to Talk
**froze** the app. No crash, no report — the screen simply stopped updating.

That is a livelock, and it was introduced by the fix. The cycle:

1. `mic.start()` sets the session to `.playAndRecord`, reconfiguring the hardware
2. that posts `AVAudioEngineConfigurationChange` to the **sound bank's** engine
3. `SoundBank.rebuild()` responds by calling `AudioSession.reactivate()`, which applies
   `.playAndRecord` again
4. which reconfigures the hardware again — go to 2

The notifications are delivered on the main queue, so every turn re-enqueues work onto a
queue that never drains. The UI is never given a chance to draw. The previous version had
the same shape with an extra participant (the sound bank set `.playback`, the microphone
undid it); re-asserting the intent instead turned a two-party oscillation into a tight
self-sustaining loop in one handler.

**The rule that was missing, stated plainly:**

> Applying an audio session category *is what posts* `AVAudioEngineConfigurationChange`.
> A handler for that notification must therefore never apply a category. It would be
> re-triggering itself.

A configuration change means the engine's *graph* is invalid. It never means the session
needs re-applying — the session is already whatever caused the notification.

Three changes, so this cannot come back:

1. **`AudioRecovery`** is a pure decision table — which of the three system audio events
   needs the session re-asserted, and which needs a fresh engine object. A plain
   configuration change needs neither. It is unit-tested, including a test that fails if
   a fourth event is added without someone deciding.
2. **Applying a category the session already has is skipped.** It is not a no-op in
   AVFoundation: it reconfigures the hardware and posts the notification regardless.
3. **A tripwire.** Every loop must pass through the one function that reconfigures the
   hardware, so that function counts changes in a rolling two-second window and logs a
   `fault` past eight. A livelock leaves nothing behind to read; this leaves a line in
   Console naming the file to open.

None of this is verified on device. The Simulator has no usable audio input, so the whole
path is gated off there — which is how this shipped twice.

## Confirming it

This diagnosis is from code and documented contract, not from a stack trace. To confirm
against the real crash, get the report off the phone:

- **Settings → Privacy & Security → Analytics & Improvements → Analytics Data**, find
  `PuppetMaster-<date>.ips`, share it; or
- **Xcode → Window → Devices and Simulators → View Device Logs** with the phone attached.

Look at the exception type. `EXC_CRASH (SIGABRT)` with
`com.apple.coreaudio.avfaudio` in the last exception backtrace confirms mechanism A or
B; the `required condition is false: …` line names which.
