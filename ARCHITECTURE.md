# Puppet Master — Technical Architecture

**Status:** v0.2 · Largely implemented — see [docs/PROTOTYPE.md](docs/PROTOTYPE.md)
for exactly what is built, verified, and still outstanding
**Toolchain (verified on this machine):** Xcode 27.0, Swift 6.4, iOS 27.0 SDK
**Proposed deployment target:** iOS 26.0 — see [OPEN-QUESTIONS.md](docs/OPEN-QUESTIONS.md) Q8

> **Ground rule.** Nothing in this document assumes an unreleased or private Apple
> API. Where a capability is unverified it is marked **⚠️ spike required** and must
> be proven with a throwaway prototype before it is promised in scope. Anything
> Duo-specific is an abstraction boundary, never a call site.

---

## 1. Design principles

1. **One source of truth.** A single `PuppetEngine` owns all puppet state. Views never
   own animation state.
2. **The pose is a value.** Each frame the engine produces a plain `PuppetPose` struct.
   Renderers consume it. They never talk back.
3. **Stage and Controls are strangers.** They share the engine and nothing else — no
   shared view hierarchy, no shared geometry, no parent/child relationship. This is
   what makes a second display cheap later.
4. **Layer, don't switch.** Expression, action, live drivers and idle all contribute to
   the same pose additively. No global state machine that makes "happy" and "waving"
   mutually exclusive.
5. **The renderer is replaceable.** Nothing above the renderer imports SpriteKit.
6. **No backend.** No accounts, no server, no network calls except the App Store.

---

## 2. Layer diagram

```
┌──────────────────────────────────────────────────────────────────┐
│  PRESENTATION                                                     │
│                                                                   │
│   ┌──────────────────┐            ┌──────────────────┐            │
│   │   ControlsView   │            │    StageView     │            │
│   │    (SwiftUI)     │            │  (SwiftUI shell  │            │
│   │                  │            │   + SpriteView)  │            │
│   └────────┬─────────┘            └─────────▲────────┘            │
│            │ PuppetIntent                   │ PuppetPose          │
└────────────┼────────────────────────────────┼─────────────────────┘
             │                                │
┌────────────▼────────────────────────────────┴─────────────────────┐
│  DOMAIN  (pure Swift — no UIKit, no SpriteKit, no AVFoundation)   │
│                                                                    │
│   ┌────────────────────────────────────────────────────────┐      │
│   │                     PuppetEngine                       │      │
│   │  ┌──────────┐ ┌───────────┐ ┌──────────┐ ┌──────────┐ │      │
│   │  │IdleDriver│ │ Expression│ │  Action  │ │   Live   │ │      │
│   │  │          │ │   Layer   │ │ Scheduler│ │ Drivers  │ │      │
│   │  └────┬─────┘ └─────┬─────┘ └────┬─────┘ └────┬─────┘ │      │
│   │       └─────────────┴────────────┴────────────┘        │      │
│   │                    PoseBlender → PuppetPose            │      │
│   └────────────────────────────────────────────────────────┘      │
└────────────▲───────────────────────────────────────▲──────────────┘
             │ jaw / aim signals                     │ character data
┌────────────┴──────────┐  ┌──────────────┐  ┌───────┴──────────────┐
│  SERVICES             │  │  DISPLAY     │  │  CONTENT             │
│  MicAmplitudeSource   │  │ StageRouter  │  │  CharacterCatalog    │
│  VoiceFXChain         │  │ DisplayRole  │  │  CharacterDescriptor │
│  SoundBank            │  │ Presenters   │  │  (JSON + atlases)    │
│  AudioSessionManager  │  │              │  │                      │
│  UnlockStore          │  │              │  │                      │
└───────────────────────┘  └──────────────┘  └──────────────────────┘
```

**Dependency rule:** arrows point inward. Domain imports nothing from Presentation,
Services, or Display.

---

## 3. The character / animation system

### 3.1 Renderer-agnostic pose model

The one abstraction that must not be got wrong. Everything above the renderer speaks
in this vocabulary:

```swift
/// Every animatable property of a puppet. 21 channels.
public enum PoseChannel: Int, CaseIterable, Sendable, Codable {
    case jawOpen, mouthSmile, tongueOut, gazeX, gazeY, blink, browLift, browAngle,
         headTilt, headTurn, headNod, bodyLean, bodyOffsetX, bodyOffsetY,
         bodyRotation, squash, breath, armLeft, armRight, hairLag, shadowScale
}

/// A complete description of the puppet for one frame. Pure value type.
///
/// Channel-indexed rather than a struct of named fields, so layers can compose
/// generically (`override` / `add` over any channel) without a switch per property.
public struct PuppetPose: Equatable, Sendable {
    private var storage: [Double]
    public subscript(channel: PoseChannel) -> Double { get set }

    public mutating func override(_ channel: PoseChannel, _ target: Double, weight: Double)
    public mutating func add(_ channel: PoseChannel, _ delta: Double, weight: Double)
    public mutating func clampToLimits()
}
```

`PuppetPose` is trivially unit-testable and completely decoupled from how pixels
end up on screen. If we ever swap SpriteKit for something else, only the renderer
and the atlases change.

### 3.2 Layered composition

```
  IDLE          breathing, blinking, micro-sway          weight 1.0, always on
+ EXPRESSION    held face/posture target                 weight 1.0, eased
+ ACTION        one-shot keyframe track (wave, jump…)    weight ramps 0→1→0
+ LIVE          mic jaw, drag aim                        weight 1.0, additive
───────────────────────────────────────────────────────────────────────────
= PuppetPose                                             clamped per channel
```

Each layer emits a partial pose plus a per-channel weight; `PoseBlender` combines
them. Consequence: the puppet can be *happy*, *mid-wave*, *talking*, and *breathing*
at the same time — which is what makes it read as alive instead of as a menu of
canned clips.

### 3.3 Character content format — built

A character is **data**, not code. `CharacterDescriptor` holds nine groups of numbers
(palette, body, head, eyes, mouth, brows, arms, crest, personality) and `PuppetRig`
builds an identical node hierarchy for every one of them. Adding a cast member is one
value in `CharacterLibrary` — no views, no actions, no renderer work. See
[docs/CHARACTERS.md](docs/CHARACTERS.md).

**Personality is part of the character.** `Personality` feeds the idle layer, so breath
period, blink interval and sway are character traits rather than constants. This does
more work than the geometry: Bramble and Pip would still read as different creatures if
they were the same shape.

The descriptors currently live as Swift values rather than bundled JSON. They are
`Codable` throughout and a test asserts the round trip, so moving them to per-character
JSON — and from there to downloadable packs — is a *loading* change, not a runtime one.
Nothing in the engine, rig or action library learns where a character came from.

Backdrops are modelled the same way and kept deliberately separate: any character can
perform against any backdrop, and neither knows about the other.

### 3.4 Action tracks

An action is a short keyframe track over pose channels, with an optional sound and
particle cue:

```swift
public struct ActionTrack: Sendable {
    public let id: PuppetAction
    public let duration: Double
    public let channels: [PoseChannel: [Keyframe]]   // time, value, easing
    /// Channels that displace the pose instead of taking it over — anything a live
    /// driver also writes, above all `jawOpen`, which the microphone owns.
    public let additive: Set<PoseChannel>
    public let cues: [EffectCue]      // dust, sparkle, confetti, music notes
    public let sounds: [SoundCue]     // with a pitch multiplier
    public let interruptible: Bool
}
```

Authored as Swift literals today, in `ActionLibrary`. **They are not yet `Codable` and
there is no JSON loading** — tuning a curve means a recompile. The shape is data, so the
move is mechanical, but it has not been made.

---

## 4. Input / control system

### 4.1 Intents, not method calls

Controls never mutate the puppet. They emit intents:

```swift
enum PuppetIntent: Sendable {
    case setExpression(Expression)
    case perform(PuppetAction)
    case aim(SIMD2<Double>)       // normalized stage coordinates
    case releaseAim
    case setMicEnabled(Bool)
    case setVoiceFX(VoiceFXPreset)
    case playSound(SoundID)
}
```

The engine is the only thing that interprets them. Three payoffs:

1. A second device or second display can send the *same* intents over a transport —
   the engine cannot tell the difference between a local tap and a remote one.
2. Intents are trivially recordable, which gives us replay, automated UI tests, and
   a possible "record a performance" feature for free.
3. Control-surface redesign (phone vs. Duo inner screen) never touches the engine.

### 4.2 Control surfaces

| Control | Gesture | Feel |
|---|---|---|
| Expression pad | Tap | Instant, eased over ~120 ms |
| Action buttons | Tap | Fires immediately; re-tap restarts |
| Aim pad | Drag anywhere on the stage | Continuous; springs back on release |
| Talk | Press-and-hold | Mic live only while held — visible, honest, battery-friendly |
| Sound buttons | Tap | One-shot SFX |

Haptics (`UIImpactFeedbackGenerator`) on every action fire. Cheap, and it makes the
puppet feel like it has weight.

### 4.3 Concurrency

The engine is `@MainActor` and `@Observable`. Intents are `Sendable`. The project
builds under **Swift 6 strict concurrency** from the first commit — retrofitting it
later onto a real-time audio path is materially harder than starting with it.

---

## 5. Audio and voice

### 5.1 Microphone → jaw (the important one)

```
AVAudioEngine.inputNode
    └─ installTap(onBus:bufferSize:format:)          [audio thread]
         └─ compute RMS over the buffer
              └─ convert to dB, clamp to a noise floor
                   └─ publish through a lock-free box   ← no allocation,
                        no locks, no Swift concurrency
                        on this thread
                                │
                        [main / render loop]
                                └─ attack/release smoothing
                                     └─ pose.jawOpen
```

Deliberately **not** speech recognition. Amplitude is enough to sell talking, works
in any language, needs no network, no model, and no transcription — which also keeps
the privacy story simple: *we measure loudness, we do not listen to words.*

**Non-negotiables:** the audio thread allocates nothing, takes no locks, and never
touches Swift concurrency primitives. Asymmetric smoothing (fast attack ~20 ms, slow
release ~80 ms) is what makes the mouth look like a mouth rather than a VU meter.

### 5.2 Voice effects

For the "puppet repeats what you said" feature: buffer the held-to-talk audio, then
replay it through an `AVAudioEngine` graph with `AVAudioUnitTimePitch` (pitch shift)
and optionally `AVAudioUnitDistortion` / `AVAudioUnitReverb`. Presets: *Squeaky*,
*Rumbly*, *Robot*. All native AVFoundation; no third-party DSP.

### 5.3 Session and permission policy

- Category `.playAndRecord`, options `.defaultToSpeaker` + `.allowBluetooth`.
- Permission requested via `AVAudioApplication.requestRecordPermission` only when
  the user first presses Talk — never at launch.
- **Nothing is written to disk and nothing leaves the device.** Buffers are in-memory
  and discarded on release. Declared in `PrivacyInfo.xcprivacy` and stated in the
  in-app reason screen in plain language.
- Denied permission is a first-class path: the Talk button becomes "Silly Voice" and
  drives the jaw from a procedural rhythm generator.

### 5.4 Sound bank — built, and synthesised

Every sound is **generated at runtime** by `Synth` (pure maths over a `[Float]`) and
played from an `AVAudioPCMBuffer` on a pool of eight `AVAudioPlayerNode`s. There are no
audio files in the project.

The reason is not minimalism. Because sounds are rendered *at the pitch they are needed*,
a character's voice is one number in its `Personality` — Pip squeaks at 1.42×, Bramble
rumbles at 0.66×, from one bank and with no pitch-shifting unit in the graph. Buffers are
cached per (sound, pitch bucket); the first render of each is well under a millisecond.

**Sound does not go through `PuppetRenderer`.** Renderers are per-surface, and audio is
not: the engine emits it once per performance through `onSound`, or two stages would
double every noise.

`AudioSession` owns the category. Recording is a temporary *upgrade* from playback while
the Talk button is held, and releasing returns to playback — an earlier version
deactivated the session on release and cut off any sound still ringing.

---

## 6. Display abstraction — the future-Duo boundary

### 6.1 The contract

```swift
/// Which half of the experience a surface is showing.
public enum DisplayRole: String, Sendable, CaseIterable {
    case combined   // one screen: stage + controls stacked
    case stage      // audience-facing only, zero chrome
    case controls   // performer-facing only
}

/// How the app is currently spreading itself across surfaces.
public enum PresentationMode: String, CaseIterable, Sendable {
    case solo, duoRehearsal, externalDisplay, duo
    public var roles: Set<DisplayRole> { … }
}
```

`StageRouter` is the **only** type in the app that knows how many screens there are. It
owns the current `PresentationMode`, reports which modes are available and why the rest
are not, and tracks external-display connect/disconnect. `StageView` and `ControlsView`
are written once and never learn which mode mounted them — that ignorance is precisely
what makes adding a surface cheap.

> **Earlier drafts of this document described a `StagePresenter` protocol with
> `attach(engine:)`/`detach()` and one conformance per mode. It was never built and the
> name appears nowhere in the code.** What shipped is simpler: the router picks a mode,
> `RootView` switches on it, and the system's own scene delegates supply extra surfaces.
> The important property — that surfaces are independent and the engine drives all of
> them — is delivered by `PuppetEngine`'s renderer list, not by a presenter abstraction.

### 6.2 How each mode gets its surfaces

| Mode | Roles | Mechanism | Status |
|---|---|---|---|
| **Solo** | `.combined` | One SwiftUI scene, stage above controls | ✅ Built |
| **Duo Rehearsal** | `.stage` + `.controls` | Two panels in `DuoRehearsalView`, same views a two-screen device would use | ✅ Built |
| **Big Screen** | `.stage` + `.controls` | `ExternalDisplaySceneDelegate` on the `externalDisplayNonInteractive` scene role | ⚠️ Written, never run against a display |
| **Duo** | `.stage` + `.controls` | **Unknown.** Not written until an SDK exists. | Blocked |

Multi-surface output does not come from this table — it comes from `PuppetEngine`
pushing every frame to every registered `PuppetRenderer`. Adding a surface means adding
a renderer, not a presenter.

### 6.3 External display — partly resolved

**Answered:** a SwiftUI-lifecycle app does *not* compose cleanly with multiple scene
roles, so the app uses the **UIKit lifecycle** (`AppDelegate` + scene delegates) and
hosts SwiftUI inside each scene via `UIHostingController`. Every view is still SwiftUI;
only the scene plumbing is UIKit. `Info.plist` declares both the application role and
`UIWindowSceneSessionRoleExternalDisplayNonInteractive`, and
`ExternalDisplaySceneDelegate` mounts a chrome-free `StageView` on the connected
display while the phone keeps the controls plus a confidence monitor.

**Still open ⚠️:** none of this has run against a real display. The code path is
written and wired but unexercised. Until someone plugs a display in, Big Screen stays
out of committed scope.

### 6.4 Duo: what we will and will not do

**Will:** keep Stage and Controls independently renderable; ship Two Devices mode so
that separation is exercised by real users on real hardware; keep all presenter
selection in one file.

**Will not:** write a `DuoPresenter` against a guessed API, add Duo-named build
settings, ship dead code paths, or make any product promise that depends on
unannounced hardware.

When an SDK lands, the expected work is a `duo` branch in `StageRouter`, a scene (or
whatever the SDK offers) hosting the existing `StageView`, and a control layout tuned
for a larger inner screen. The engine already drives any number of renderers, so the
surfaces themselves need nothing new. If it turns out to need more, the
abstraction was wrong — and it will have cost us roughly one file to find out.

---

## 7. Animation approach — recommendation

### Recommendation

> **SpriteKit for the stage, embedded in SwiftUI via `SpriteView`; SwiftUI for every
> other pixel in the app. Puppets are cut-out rigs — a hierarchy of flat PNG parts
> with pivots — driven by the renderer-agnostic `PuppetPose`.**

### Why

A puppet *is* a node hierarchy with pivots. SpriteKit gives that natively via
`SKNode` parent/child transforms, plus texture atlases, `SKAction` sequencing,
`SKEmitterNode` particles for confetti and dust, and a real render loop we can tick
the engine from. It is a first-party Apple framework — no dependency, no licence, no
build-tooling risk. And `SKPhysicsJointPin` gives genuinely floppy limbs and a
lagging hair tuft for nearly free, which is exactly the secondary motion that makes
a puppet look alive.

### Options considered

| Approach | Strengths | Weaknesses | Verdict |
|---|---|---|---|
| **SpriteKit + `SpriteView`** | Purpose-built 2D; node hierarchy = puppet rig; atlases; particles; physics joints for floppiness; real render loop; first-party, zero deps | Imperative, older-feeling API; a SwiftUI↔SpriteKit boundary to manage; mature rather than actively evolving | ✅ **Recommended** |
| **Pure SwiftUI** (`Image` layers + `rotationEffect(_:anchor:)`) | One paradigm everywhere; superb DX; free accessibility and theming; trivially previewable | No sprite atlases, no particle system, no physics; complex multi-channel timelines get unwieldy; frame-accurate live audio drive is awkward; perf risk with many layers + blurs | Viable fallback — see below |
| **Rive** | Best-in-class interactive character animation; designer-owned state machines; tiny runtime | Third-party dependency + paid design tool; couples the art pipeline to a vendor; conflicts with the "minimal dependencies" direction | ❌ Not now. Revisit only if art iteration becomes the bottleneck |
| **Lottie** | Designers author in After Effects; great for scripted motion | Built for *playback*, not for live interactive drive; awkward to map a live mic signal onto; third-party | ❌ Wrong shape for this product |
| **SceneKit / RealityKit (3D)** | Real lighting, depth, true 3D puppets | Far more art cost; heavier; kills the flat, warm, hand-made feel we want | ❌ Overkill |
| **Core Animation directly** | Very fast, fine-grained | Lowest-level, most code, no game-loop conveniences | ❌ No advantage over SpriteKit here |

### How the recommendation stays reversible

Because `PuppetPose` is a pure value type and the renderer sits behind:

```swift
@MainActor
public protocol PuppetRenderer: AnyObject {
    func load(character: CharacterDescriptor)
    func setBackdrop(_ backdrop: Backdrop)
    func apply(pose: PuppetPose)
    func fire(effect: PuppetEffect)
}
```

Note what is *not* here: sound. Audio is emitted once per performance through
`PuppetEngine.onSound`, not per renderer — two stages must not double every noise.

…switching to pure SwiftUI (or Rive) later means writing one new conformance. The
engine, the controls, the character JSON, the action tracks, and the tests all
survive unchanged. **Phase 0 should build a throwaway of both SpriteKit and pure
SwiftUI against the same pose model and pick with evidence, not with taste.** The
cost of doing so is roughly two days.

---

## 8. Repository structure

As built. `(planned)` marks files described above that do not exist yet — see
[docs/PROTOTYPE.md](docs/PROTOTYPE.md).

```
PuppetMaster/
├── README.md · PRD.md · ARCHITECTURE.md · ROADMAP.md · .gitignore
├── .github/workflows/ci.yml          # build + test + Core purity (never run yet)
├── scripts/check-core-purity.sh      # fails the build if Core/ imports a framework
├── docs/
│   ├── PROTOTYPE.md                  # what works, what is verified, what is not
│   ├── CHARACTERS.md                 # how to add a cast member
│   ├── OPEN-QUESTIONS.md · ASSETS.md
├── Config/Info.plist                 # scene manifest: app + external-display roles
├── PuppetMaster.xcodeproj
│
├── PuppetMaster/
│   ├── App/
│   │   ├── AppDelegate.swift               # UIKit lifecycle — needed for scene roles
│   │   ├── MainSceneDelegate.swift         # the phone
│   │   ├── ExternalDisplaySceneDelegate.swift  # an audience-facing display
│   │   ├── AppEnvironment.swift            # composition root; one engine, one clock
│   │   ├── RootView.swift                  # layout per mode + AudienceStageView
│   │   └── DuoRehearsalView.swift          # both surfaces, one phone
│   │
│   ├── Core/                          # pure Swift. No UIKit/SpriteKit/AVFoundation.
│   │   ├── Model/
│   │   │   ├── PuppetPose.swift            # the frame, as a value (21 channels)
│   │   │   ├── CharacterDescriptor.swift   # a character, as nine groups of numbers
│   │   │   ├── PuppetIntent.swift          # what a control surface can ask for
│   │   │   ├── PuppetRenderer.swift        # load / apply / fire
│   │   │   └── Expression.swift · PuppetAction.swift · Easing.swift
│   │   ├── Content/
│   │   │   ├── CharacterLibrary.swift      # the cast of four
│   │   │   └── Backdrop.swift              # four backdrops, independent of the cast
│   │   └── Engine/
│   │       ├── PuppetEngine.swift          # @MainActor @Observable, source of truth
│   │       ├── PoseBlender.swift           # idle + expression + actions + live
│   │       ├── IdleDriver.swift            # breathing, blinking, sway — per personality
│   │       ├── ExpressionLayer.swift       # eases between held faces
│   │       ├── ActionScheduler.swift       # overlapping one-shots
│   │       └── ActionLibrary.swift         # the 12 authored performances
│   │
│   ├── Stage/
│   │   ├── StageView.swift                 # SwiftUI shell + SpriteView + aim drag
│   │   ├── PuppetScene.swift               # SKScene conforming to PuppetRenderer
│   │   ├── PuppetRig.swift                 # one node hierarchy, any character
│   │   ├── ParticleTextures.swift          # generated; SF Symbols as particles
│   │   └── ColorSpec+UIKit.swift           # the only place Core colours meet UIKit
│   │
│   ├── Controls/
│   │   ├── ControlsView.swift · AimPad.swift · TalkButton.swift
│   │   ├── CastSheet.swift                 # who performs
│   │   └── StageSheet.swift                # surfaces + backdrops
│   │
│   ├── Audio/
│   │   ├── VoiceInput.swift                # picks mic or fallback
│   │   ├── MicAmplitudeSource.swift        # tap → RMS → jaw
│   │   ├── AmplitudeBox.swift              # lock-free audio→main hand-off
│   │   ├── SillyVoiceDriver.swift          # procedural babble
│   │   └── VoiceFXChain.swift · SoundBank.swift   (planned)
│   │
│   ├── Display/
│   │   ├── DisplayRole.swift               # roles and presentation modes
│   │   ├── StageRouter.swift               # the ONLY file that knows about surfaces
│   │   ├── DuoCapability.swift             # the entire vendor seam
│   │   └── PeerDevicePresenter.swift       (planned — two-devices mode)
│   │
│   ├── Store/                              (planned — StoreKit 2)
│   ├── Support/
│   │   ├── EngineClock.swift               # CADisplayLink → engine.tick(delta:)
│   │   └── Haptics.swift · Theme.swift
│   └── Resources/Assets.xcassets
│
└── PuppetMasterTests/
    ├── PoseBlenderTests.swift        # layering, settling, clamping, stalled frames
    ├── ActionTrackTests.swift        # sampling, library sanity, cues, cast, backdrops
    └── VoiceAndDisplayTests.swift    # smoothing, babble, routing, engine fan-out
```

**Why this shape:** `Core/` has no framework imports, so the fun part of the product —
how the puppet moves — is testable in milliseconds with no simulator, screen or
microphone. `Core/Content/` is where cast and staging live as data. `Display/` is a
single quarantined directory for the Duo question, and `DuoCapability.swift` is the only
file a vendor SDK would touch.

## 9. Testing and quality

| Layer | Approach |
|---|---|
| Engine, blender, easing, idle driver | Plain unit tests (Swift Testing). Fast, deterministic, no simulator. |
| Character JSON | Decode-every-bundled-character test — a malformed pack fails CI, not a user's device. |
| Amplitude smoothing | Feed recorded buffers, assert on the jaw curve shape. |
| Renderer | Snapshot a handful of canonical poses. Not exhaustive — art changes constantly. |
| Controls | A few UI tests on the critical path: launch → tap action → puppet moves. |
| Performance | Instruments pass per phase on the oldest supported device. Budget: sustained 60 fps with mic live and particles on screen. |

CI on every PR: build, unit tests, and a check that `Core/` imports no UI frameworks
(a one-line `grep` guard is enough and catches the architectural regression that
actually matters).

---

## 10. Things this architecture deliberately does not have

- **No backend, no accounts, no analytics service** in v1. If we later want usage
  data and we are not in the Kids Category, add a first-party, privacy-preserving,
  opt-in counter — nothing more.
- **No dependency manager entries.** Zero third-party packages at v1. Every addition
  needs an ADR in `docs/decisions/`.
- **No plugin system, no scripting layer, no character editor.** Characters are JSON
  + art. That is the extensibility story, and it is enough.
- **No Duo code.** Only a Duo-shaped hole.

## 11. Two puppets

A puppet is a *performance*: its own pose, its own idle rhythm, its own boredom clock.
So a second puppet is a second `PuppetEngine`, not a flag on the first one. That choice
is why the duet added no animation code at all — every layer, action and driver was
already written against one engine.

```
Troupe
├── engines: [PuppetEngine]     one per puppet
├── focusIndex                  whose thumbs are on which
└── onSound ──────────────────▶ one SoundBank (sound is per performance, not per puppet)

PuppetScene                     the stage: sky, floor, stars
└── performers: [StagePerformer]  ← the PuppetRenderer the engine actually talks to
```

`PuppetScene` used to be the renderer and to own a rig. Splitting `StagePerformer` out
of it is what lets two puppets share one sky instead of sitting in two boxes with a seam
down the middle. The scene lays performers out in slots; each performer owns its own
world node, so a landing shakes *that* puppet rather than the stage — two bodies, not
one.

**Focus is staging, not UI.** The puppet being driven stands downstage: slightly larger
and at full brightness. That answers "which one am I playing" for the performer without
showing the audience a selection highlight.

Two is the ceiling on purpose. A third puppet on a phone is too small to read, and the
controls stop being obvious within seconds — which is the entire product.

## 12. Audio on real hardware

The audio session and both engines are dynamic, not static. Phone calls, Siri,
headphones and this app's own session upgrade all reconfigure the hardware underneath a
running `AVAudioEngine`, and an engine that is not told about it aborts the process the
next time it is used — via an Objective-C exception that Swift cannot catch.

Both `SoundBank` and `MicAmplitudeSource` therefore observe
`configurationChangeNotification`, `interruptionNotification` and
`mediaServicesWereResetNotification`, and rebuild. The microphone reinstalls its tap on
every start against a freshly-read format, validated first by `TapFormatCheck` — a pure,
unit-tested restatement of the precondition AVFAudio asserts on. `docs/MIC-CRASH.md` has
the full account; it is worth reading before touching this layer.

The lesson worth keeping: `isInputUsable` returns false in the Simulator, so **the entire
microphone path is device-only**. Nothing in it can be caught by a Simulator test run.
