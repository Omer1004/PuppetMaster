# Puppet Master — Scope and Roadmap

**Status:** Proposal v0.1

---

## 1. Feature list

### 1.1 Must have — MVP ships without exception

**Character and animation**
- One finished, original character with production art *(prototype has four, in
  placeholder art)*
- Idle life: breathing, blinking, micro-sway — always running, never off ✅
- 4 expressions minimum *(prototype has seven)* ✅
- 6 actions minimum *(prototype has twelve)* ✅
- Layered pose blending so expression + action + talk coexist
- Look/aim: drag on the stage to point head and eyes

**Voice**
- Live microphone amplitude drives the jaw
- Permission requested only on first Talk press, with a plain-language reason screen
- **Full no-microphone path** — Talk becomes "Silly Voice", procedurally driven

**Stage**
- Solo mode: stage + controls on one iPhone
- Portrait and landscape
- 2 backdrops
- Sound bank of ~8 one-shot effects
- 2–3 voice-FX presets (Squeaky, Rumbly, Robot)

**App**
- Cold launch to a living puppet in under 2 seconds, with no menu in between
- One-card, skippable, never-repeated onboarding
- Settings: sound, haptics, mic, backdrop, reset
- Accessibility: VoiceOver labels on all controls, Reduce Motion honored, Dynamic
  Type in all text, adequate contrast
- Privacy policy, `PrivacyInfo.xcprivacy`, App Store metadata
- StoreKit 2 unlock scaffolding wired end to end (even if v1 ships free)
- Haptics on action fire
- Sustained 60 fps on the oldest supported device with mic live

### 1.2 Nice to have — in MVP if the schedule allows, cut without regret

- **Big Screen mode** (stage on an external display / AirPlay) — *high product value,
  but gated on the Phase 0 spike; do not commit it to scope before that spike lands*
- **Two Devices mode** (MultipeerConnectivity) — *high architectural value: it is the
  only way to prove the stage/controls split before Duo hardware exists*
- Record a 30-second performance and export to Photos (ReplayKit)
- 2 more backdrops, seasonal sound pack
- "Puppet repeats you": buffer the held-talk audio and replay it pitch-shifted
- Custom sound buttons
- Localization beyond English (Hebrew RTL is the obvious first addition)
- iPad layout

### 1.3 Later — explicitly out of MVP

- Duo dual-screen mode (blocked on hardware + SDK)
- Character packs as IAP, with a repeatable art pipeline behind them
- Multiple puppets on stage at once
- Two-player: each person drives a puppet on their own device
- Scenes, props, costumes
- Performance sharing, or any social layer
- Character creator / customization
- Mac or Vision Pro versions
- Any backend, account system, or cloud sync

---

## 2. Staged implementation plan

Effort figures are **rough estimates for one developer plus a part-time illustrator**,
not commitments. They exist to size the shape of the work, and should be replaced with
real estimates once Phase 0 tells us what we are actually building.

### Phase 0 — Prototype *(~1–2 weeks)* — **mostly built**
**Question it answers: is this actually fun? — still unanswered.**

The app exists and runs ([docs/PROTOTYPE.md](docs/PROTOTYPE.md)), now with a cast of
four, seven expressions, twelve actions and four backdrops. Characters are data, which
was a Phase 1 goal pulled forward because it made adding the cast almost free.

What is still owed from this phase: the renderer bake-off, the external-display spike
against real hardware, the microphone tested on a device, and — the actual gate —
putting it in front of children.

- Throwaway placeholder art — deliberately ugly, so nobody falls in love with it
- `PuppetPose` + `PuppetEngine` + `PoseBlender` + idle driver, for real (this code survives)
- Mic tap → smoothed jaw
- 3 actions, 2 expressions, aim
- **Bake-off:** the same pose model rendered twice — once in SpriteKit, once in pure
  SwiftUI. Pick with evidence (ARCHITECTURE §7)
- **Spike:** external display via scene roles. Time-boxed. Answer is yes-or-no
- Put it in front of 3–5 real kids and their adults

**Exit gate.** Do children laugh? Does the adult understand it unprompted? Which
renderer won? Is Big Screen feasible? A "no" on fun is a stop, not a replan — and
Phase 0 is cheap precisely so that stopping is cheap.

### Phase 1 — MVP *(~4–6 weeks after the gate)*
**Goal: a complete, shippable, single-character product.**

- Commission and integrate final Moppet art (start this on day one of the phase —
  art is the long pole, not code)
- Full expression and action set, tuned
- Voice FX, sound bank, haptics
- Solo mode polished in both orientations
- Onboarding, settings, accessibility, localization scaffold
- StoreKit 2 wiring, privacy manifest, privacy policy
- CI: build + unit tests + the `Core/` purity check on every PR
- TestFlight with 10–20 external families

### Phase 2 — Separation *(~2–3 weeks, can overlap Phase 1 polish)*
**Goal: prove the stage/controls split on hardware that exists today.**

- Whichever of Big Screen / Two Devices the Phase 0 spike favored
- Intent transport over MultipeerConnectivity, with reconnection handled gracefully
- Role-specific layouts: stage with zero chrome, controls with room to breathe
- Harden `StageRouter` against the real failure modes (display yanked, peer dropped,
  app backgrounded mid-performance)

This phase is the insurance policy on the Duo bet. If the abstraction is wrong, we
find out here, on shipping hardware, for a fraction of the cost.

### Phase 3 — Duo integration *(blocked — cannot be scheduled)*
**Entry condition: public Duo SDK and a simulator or device.**

- Read the actual SDK. Discard every assumption in this repo that it contradicts
- Implement `DuoPresenter` behind the existing `StagePresenter` protocol
- Design the inner-screen control layout for the real dimensions
- If the abstraction holds, this is small. If it does not, Phase 2 will already have
  told us why

**No work in this phase starts before the SDK is public.**

### Phase 4 — Polish and App Store release *(~2–3 weeks)*
- Performance pass on the oldest supported device; hold 60 fps under load
- Every asset in [docs/ASSETS.md](docs/ASSETS.md) final
- App icon, screenshots, 15–30s App Preview video
- Store listing, keywords, age rating, Kids Category compliance if applicable
- Name and trademark clearance completed *(blocking — see OPEN-QUESTIONS Q7)*
- Full accessibility audit with VoiceOver and Reduce Motion actually enabled
- Beta feedback triaged; crash-free rate verified
- Submit

---

## 3. Sequencing notes

- **Art leads code.** Commission the character on day one of Phase 1. Everything else
  can wait on placeholder rectangles; the art cannot be compressed at the end.
- **Idle life is not polish.** Build it in Phase 0. A static puppet in a user test
  produces a false negative on the whole product.
- **The renderer decision is a one-way-ish door.** Spend the two days in Phase 0 to
  make it with evidence, and record it as an ADR.
- **Kids Category must be decided before Phase 1 starts.** It constrains the SDK list,
  the IAP flow, and the privacy work — all of which are expensive to retrofit.
- **Swift 6 strict concurrency from commit one.** Retrofitting it onto a live audio
  path later is materially harder than starting with it.
