# Puppet Master — Technical Architecture

**Status:** Proposal v0.1 · Pre-implementation
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
/// A complete description of the puppet for one frame. Pure value type.
struct PuppetPose: Equatable, Sendable {
    var jawOpen: Double          // 0…1   — mic amplitude + action contributions
    var gaze: SIMD2<Double>      // -1…1  — where the eyes point
    var headTilt: Double         // radians
    var bodyLean: Double         // radians
    var bodyOffset: SIMD2<Double>
    var squash: Double           // 1 = neutral; <1 squashed, >1 stretched
    var breath: Double           // 0…1   — idle chest/body scale
    var blink: Double            // 0…1   — 1 = fully closed
    var armLeft: LimbPose
    var armRight: LimbPose
    var brow: BrowPose
    var mouthShape: MouthShape   // a discrete overlay: .neutral .smile .o .tongue
    var accessoryLag: SIMD2<Double>  // hair tuft / secondary motion
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

### 3.3 Character content format

A character is **data**, not code, so new characters ship without an app update
path change and without a code review:

```
Resources/Characters/moppet/
├─ moppet.json          # rig: parts, pivots, z-order, channel→part bindings,
│                       # expression targets, action keyframe tracks
├─ moppet.atlas/        # SKTextureAtlas — cut-out part PNGs @1x/@2x/@3x
└─ thumb.png
```

`CharacterDescriptor` decodes `moppet.json` with `Codable`. The renderer builds the
node hierarchy from the descriptor at load time. Adding "Character #2" is an art +
JSON task, not an engineering task — this matters enormously for the character-pack
monetization model.

### 3.4 Action tracks

An action is a short keyframe track over pose channels, with an optional sound and
particle cue:

```swift
struct ActionTrack: Codable, Sendable {
    let id: PuppetAction
    let duration: TimeInterval
    let channels: [PoseChannel: [Keyframe]]   // time, value, easing
    let sound: SoundID?
    let effect: EffectID?      // e.g. dust puff on landing
    let interruptible: Bool
}
```

Authored as JSON, tuned by editing a file and hot-reloading in the simulator. No
recompile per tweak.

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

### 5.4 Sound bank

Short one-shots (laugh, pop, boing, whoosh, dust) preloaded as `AVAudioPlayerNode`
buffers or `SKAudioNode`. Must duck cleanly against live mic playback. Global mute
honored everywhere, including haptics-off.

---

## 6. Display abstraction — the future-Duo boundary

### 6.1 The contract

```swift
/// Which half of the experience a given surface renders.
enum DisplayRole: Sendable {
    case combined   // one screen: stage + controls stacked
    case stage      // audience-facing only, zero chrome
    case controls   // performer-facing only
}

/// Something that can present one or both roles. Each mode is an implementation.
protocol StagePresenter {
    var availableRoles: Set<DisplayRole> { get }
    func attach(engine: PuppetEngine) async throws
    func detach()
}
```

`StageRouter` picks a presenter at runtime and is the **only** place in the codebase
that knows how many surfaces exist. `StageView` and `ControlsView` are written once
and are never aware of which presenter mounted them.

### 6.2 Planned presenters

| Presenter | Roles | Mechanism | Status |
|---|---|---|---|
| `SingleScreenPresenter` | `.combined` | One SwiftUI scene, stage + controls stacked | MVP |
| `ExternalDisplayPresenter` | `.stage` + `.controls` | Scene-role external display attachment | ⚠️ spike required |
| `PeerDevicePresenter` | `.stage` + `.controls` | MultipeerConnectivity, intents over the wire | Post-MVP |
| `DuoPresenter` | `.stage` + `.controls` | **Unknown. Not written until an SDK exists.** | Blocked |

### 6.3 ⚠️ Spike: external display

Current iOS attaches an external display as a separate window scene with the
`externalDisplayNonInteractive` session role, configured in the app's scene manifest.
How cleanly that composes with a SwiftUI-lifecycle app — and whether we need a UIKit
`UIWindowSceneDelegate` alongside it — is **unverified**. Time-box a spike in Phase 0
before Big Screen mode is committed to MVP scope. If it proves awkward, AirPlay
mirroring with a role-aware layout is the fallback, and `PeerDevicePresenter` becomes
the real answer.

### 6.4 ⚠️ Duo: what we will and will not do

**Will:** keep Stage and Controls independently renderable; ship Two Devices mode so
that separation is exercised by real users on real hardware; keep all presenter
selection in one file.

**Will not:** write a `DuoPresenter` against a guessed API, add Duo-named build
settings, ship dead code paths, or make any product promise that depends on
unannounced hardware.

When an SDK lands, the expected work is one new `StagePresenter` conformance plus a
control layout tuned for a larger inner screen. If it turns out to need more, the
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
protocol PuppetRenderer: AnyObject {
    func load(character: CharacterDescriptor) async throws
    func apply(pose: PuppetPose)
    func fire(effect: EffectID, at: SIMD2<Double>)
}
```

…switching to pure SwiftUI (or Rive) later means writing one new conformance. The
engine, the controls, the character JSON, the action tracks, and the tests all
survive unchanged. **Phase 0 should build a throwaway of both SpriteKit and pure
SwiftUI against the same pose model and pick with evidence, not with taste.** The
cost of doing so is roughly two days.

---

## 8. Proposed repository structure

```
PuppetMaster/
├── README.md
├── PRD.md
├── ARCHITECTURE.md
├── ROADMAP.md
├── LICENSE
├── .gitignore
├── .github/
│   └── workflows/ci.yml            # build + test on PR
│
├── docs/
│   ├── OPEN-QUESTIONS.md
│   ├── ASSETS.md                   # everything we must commission
│   ├── decisions/                  # ADRs — one file per irreversible choice
│   │   └── 0001-spritekit-for-stage.md
│   └── art/
│       └── moppet-brief.md         # character brief handed to the illustrator
│
├── PuppetMaster.xcodeproj
│
├── PuppetMaster/
│   ├── App/
│   │   ├── PuppetMasterApp.swift       # @main; builds AppEnvironment, picks presenter
│   │   ├── AppEnvironment.swift        # composition root — the only wiring file
│   │   └── RootView.swift
│   │
│   ├── Core/                           # pure Swift. No UIKit/SpriteKit/AVFoundation.
│   │   ├── Model/
│   │   │   ├── PuppetPose.swift
│   │   │   ├── PuppetIntent.swift
│   │   │   ├── Expression.swift
│   │   │   ├── PuppetAction.swift
│   │   │   ├── ActionTrack.swift
│   │   │   └── CharacterDescriptor.swift
│   │   └── Engine/
│   │       ├── PuppetEngine.swift      # @MainActor @Observable — source of truth
│   │       ├── PoseBlender.swift
│   │       ├── IdleDriver.swift        # breathing, blinking, sway
│   │       ├── ActionScheduler.swift
│   │       └── Easing.swift
│   │
│   ├── Stage/
│   │   ├── StageView.swift             # SwiftUI shell hosting SpriteView
│   │   ├── PuppetRenderer.swift        # protocol
│   │   ├── SpriteKit/
│   │   │   ├── PuppetScene.swift       # render loop; ticks the engine
│   │   │   ├── PuppetRigNode.swift     # builds node tree from descriptor
│   │   │   ├── SpriteKitPuppetRenderer.swift
│   │   │   └── EffectFactory.swift
│   │   └── Backdrops/
│   │
│   ├── Controls/
│   │   ├── ControlsView.swift
│   │   ├── ExpressionPad.swift
│   │   ├── ActionPad.swift
│   │   ├── AimPad.swift
│   │   ├── TalkButton.swift
│   │   └── SoundPad.swift
│   │
│   ├── Audio/
│   │   ├── AudioSessionManager.swift
│   │   ├── MicAmplitudeSource.swift    # tap → RMS → smoothed jaw signal
│   │   ├── AmplitudeBox.swift          # lock-free audio→main hand-off
│   │   ├── VoiceFXChain.swift
│   │   └── SoundBank.swift
│   │
│   ├── Display/
│   │   ├── DisplayRole.swift
│   │   ├── StagePresenter.swift        # protocol
│   │   ├── StageRouter.swift           # the ONLY file that knows about surfaces
│   │   ├── SingleScreenPresenter.swift
│   │   ├── ExternalDisplayPresenter.swift
│   │   └── PeerDevicePresenter.swift   # post-MVP
│   │
│   ├── Content/
│   │   ├── CharacterCatalog.swift
│   │   └── CharacterLoader.swift
│   │
│   ├── Store/
│   │   ├── UnlockStore.swift           # StoreKit 2 entitlements
│   │   └── PaywallView.swift
│   │
│   ├── DesignSystem/
│   │   ├── Theme.swift
│   │   ├── Typography.swift
│   │   └── Haptics.swift
│   │
│   ├── Support/
│   │   ├── Settings.swift
│   │   └── Logging.swift
│   │
│   └── Resources/
│       ├── Assets.xcassets             # icon, UI art, backdrops
│       ├── Characters/moppet/
│       ├── Sounds/
│       ├── Localizable.xcstrings
│       ├── Info.plist
│       └── PrivacyInfo.xcprivacy
│
├── PuppetMasterTests/                  # engine, blender, easing, JSON decoding,
│   └── …                               # amplitude smoothing — all pure, all fast
└── PuppetMasterUITests/
```

**Why this shape:** `Core/` has no framework imports, so the fun part of the product
(how the puppet moves) is testable in milliseconds without a simulator, a screen, or
a microphone. `Display/` is a single quarantined directory for the Duo question.
`Resources/Characters/` is where an art-only character pack lands.

---

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
