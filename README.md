# Puppet Master

An iPhone app that turns the phone into a small digital puppet stage. One person
drives an original animated character; someone else watches it perform.

**Status: working prototype.** The app builds and runs on iOS with a cast of four
characters, seven expressions, twelve actions, four backdrops, voice-driven lip sync,
and two independent display surfaces. 31 tests pass. The art is placeholder and several
paths are still unverified — [docs/PROTOTYPE.md](docs/PROTOTYPE.md) is explicit about
which.

```bash
open PuppetMaster.xcodeproj
```

---

## Documents

| Document | Contents |
|---|---|
| **[PRD.md](PRD.md)** | Vision · target users · core experience · MVP scope · monetization · first character · UX flow · future Duo experience · risks |
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | App architecture · character/animation system · input system · audio · display abstraction · animation-tech recommendation · repo structure · testing |
| **[ROADMAP.md](ROADMAP.md)** | Must-have / nice-to-have / later · staged plan from prototype to release |
| **[docs/ASSETS.md](docs/ASSETS.md)** | Every asset to be created or commissioned |
| **[docs/OPEN-QUESTIONS.md](docs/OPEN-QUESTIONS.md)** | Ten decisions needed before implementation |
| **[docs/PROTOTYPE.md](docs/PROTOTYPE.md)** | What the prototype does, what is verified, and what is not |
| **[docs/CHARACTERS.md](docs/CHARACTERS.md)** | How to add a character — and why timing matters more than shape |
| **[docs/FEEL.md](docs/FEEL.md)** | Game feel and engagement design — and the compulsion mechanics this app refuses |

### Where each requested deliverable lives

| # | Deliverable | Location |
|---|---|---|
| 1 | PRD | [PRD.md](PRD.md) |
| 2 | Architecture | [ARCHITECTURE.md](ARCHITECTURE.md) |
| 3 | Repository structure | [ARCHITECTURE.md §8](ARCHITECTURE.md#8-proposed-repository-structure) |
| 4 | MVP feature list (must / nice / later) | [ROADMAP.md §1](ROADMAP.md#1-feature-list) |
| 5 | First character and its expressions/actions | [PRD.md §6](PRD.md#6-first-character) |
| 6 | UX flow, launch → performing | [PRD.md §7](PRD.md#7-ux-flow--launch-to-performing) |
| 7 | Animation approach recommendation | [ARCHITECTURE.md §7](ARCHITECTURE.md#7-animation-approach--recommendation) |
| 8 | Asset list | [docs/ASSETS.md](docs/ASSETS.md) |
| 9 | Staged implementation plan | [ROADMAP.md §2](ROADMAP.md#2-staged-implementation-plan) |
| 10 | Open product questions | [docs/OPEN-QUESTIONS.md](docs/OPEN-QUESTIONS.md) |

---

## The short version

- **Product:** a live performance toy, not an animation editor. Immediate, expressive,
  understandable in seconds.
- **Cast:** four original creatures — *Moppet* (steady), *Pip* (excitable), *Bramble*
  (deadpan) and *Thistle* (trouble). One rig, one set of moves; what differs is the
  proportions and, mostly, the timing. Working names, not yet cleared.
- **Characters are data.** Adding one is a value in a library file — no views, no
  actions, no renderer work. See [docs/CHARACTERS.md](docs/CHARACTERS.md).
- **Feel:** synthesised sound pitched per character, screen shake on impact, haptics on
  the animation beat, and a puppet you can poke. If you put the phone down it gets
  bored and yawns. No streaks, no timers, no notifications —
  [docs/FEEL.md](docs/FEEL.md) says why.
- **Tech:** Swift · SwiftUI · SpriteKit for the stage · AVFoundation for voice ·
  **zero third-party dependencies** · no backend.
- **Duo:** stage and controls are genuinely independent surfaces driven by one engine.
  **Duo Rehearsal runs both at once today**, on the same code path a two-screen device
  would use, and an external display already gets a chrome-free stage through the
  standard scene role. **No Duo-specific API is assumed or written** — the vendor seam
  is one protocol with one honest "not available yet" implementation.
- **Next step:** run it on a real device and test the microphone (the Simulator cannot),
  then put it in front of children. Phase 0's exit gate is whether they laugh.

## Toolchain

Xcode 27.0 · Swift 6.4 · iOS 27.0 SDK · proposed deployment target iOS 26.0

## Recent work

| Change | Where |
|---|---|
| Device microphone crash — root cause and fix | [docs/MIC-CRASH.md](docs/MIC-CRASH.md) |
| Two puppets side by side | `PuppetMaster/App/Troupe.swift`, `PuppetMaster/Stage/StagePerformer.swift`, ARCHITECTURE §11 |
| Redrawn cast (felt material, lit forms, faces) | `PuppetMaster/Stage/PuppetRig.swift`, `CharacterDescriptor.Surface` |
| Tip jar | `PuppetMaster/Support/TipJar.swift`, `Config/PuppetMaster.storekit` |
| What is and is not verified | [docs/PROTOTYPE.md](docs/PROTOTYPE.md) |

> ⚠️ The tip jar and the Kids Category need a decision together before submission —
> see Q1 in [docs/OPEN-QUESTIONS.md](docs/OPEN-QUESTIONS.md).
