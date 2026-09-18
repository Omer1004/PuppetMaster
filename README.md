# Puppet Master

An iPhone app that turns the phone into a small digital puppet stage. One person
drives an original animated character; someone else watches it perform.

**Status: working prototype.** The app builds and runs on iOS, with an animated
character, layered expressions and actions, voice-driven lip sync, and two independent
display surfaces. 23 tests pass. The art is placeholder and several paths are still
unverified — [docs/PROTOTYPE.md](docs/PROTOTYPE.md) is explicit about which.

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
- **Character:** *Moppet* — an original shaggy sock-creature with mismatched button
  eyes and a mouth that moves with your voice. Working name, not yet cleared.
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
