# Puppet Master

An iPhone app that turns the phone into a small digital puppet stage. One person
drives an original animated character; someone else watches it perform.

**Status: planning.** No application code yet — this repository currently contains
the product and technical plan.

---

## Documents

| Document | Contents |
|---|---|
| **[PRD.md](PRD.md)** | Vision · target users · core experience · MVP scope · monetization · first character · UX flow · future Duo experience · risks |
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | App architecture · character/animation system · input system · audio · display abstraction · animation-tech recommendation · repo structure · testing |
| **[ROADMAP.md](ROADMAP.md)** | Must-have / nice-to-have / later · staged plan from prototype to release |
| **[docs/ASSETS.md](docs/ASSETS.md)** | Every asset to be created or commissioned |
| **[docs/OPEN-QUESTIONS.md](docs/OPEN-QUESTIONS.md)** | Ten decisions needed before implementation |

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
- **Duo:** the app is split into an independent *stage* and *controls* over one shared
  engine from day one. **No Duo-specific API is assumed or written** until an SDK
  exists. Two-devices mode on ordinary iPhones is how we prove the split early.
- **Next step:** answer [the open questions](docs/OPEN-QUESTIONS.md), then run Phase 0
  — a throwaway prototype that answers one thing: *is this fun?*

## Toolchain

Xcode 27.0 · Swift 6.4 · iOS 27.0 SDK · proposed deployment target iOS 26.0
