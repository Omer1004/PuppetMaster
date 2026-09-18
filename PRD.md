# Puppet Master — Product Requirements

**Status:** Draft v0.1 · Pre-implementation
**Owner:** Omer
**Last updated:** 2026-09-18

---

## 1. Vision

Puppet Master turns an iPhone into a small digital puppet stage.

One person — the **puppeteer** — drives an original animated character from a control
surface. The character performs on a **stage** that someone else watches. The puppeteer
talks, and the puppet's mouth moves with their voice. They tap, and it waves, laughs,
or falls over.

The product succeeds if a stranger picks up the phone and makes someone else laugh
within fifteen seconds, without being told how it works.

**What it is:** a live performance toy. Immediate, expressive, physical-feeling.
**What it is not:** an animation editor, a timeline tool, a social network, or a
character-creator sandbox. Those are adjacent products with much worse first-run
experiences.

### The core bet
The magic comes from **separating the performer from the audience**. On today's
iPhone we approximate that with an on-screen split, an external display, or a second
device. On a future dual-screen iPhone the separation becomes literal: controls in
the performer's hand, stage facing the audience. The architecture is built for that
separation from day one — see [ARCHITECTURE.md](ARCHITECTURE.md) §6.

---

## 2. Target users

| Segment | Who | Why they use it | Session |
|---|---|---|---|
| **Primary — the entertainer** | Parent, older sibling, grandparent, babysitter, teacher | Make a young child laugh, distract them in a waiting room, tell a bedtime story | 2–10 min, repeated |
| **Secondary — the kid** | Roughly ages 4–10 | Plays it themselves, performs for a parent or a friend | 5–20 min |
| **Tertiary — the goof** | Teens/adults at a party, on a video call, making short videos | Novelty, reaction content | 1–3 min, bursty |

The **entertainer is who we design for**. They have the phone, they pay, and they
are the one who needs to understand it instantly. The kid is who we delight.

> **Decision required:** whether we formally target the App Store **Kids Category**.
> This is not a marketing choice — it changes the legal and technical requirements
> (parental gate, no third-party analytics or ad SDKs, stricter data rules). See §8
> and [OPEN-QUESTIONS.md](docs/OPEN-QUESTIONS.md) Q1.

---

## 3. Core user experience

### Three things happening at once

1. **The puppet is always alive.** Before any input, it breathes, blinks, shifts
   weight, and looks around. This is the single most important detail in the
   product. A still character reads as a broken app; an idling character reads as
   a creature. Idle life is a P0 feature, not polish.

2. **Voice drives the mouth.** The microphone's amplitude opens and closes the
   puppet's jaw in real time. There is no speech recognition and no transcription —
   just loudness. It costs almost nothing and it is what sells the illusion.

3. **Touch drives everything else.** Expressions (a held state: happy, surprised,
   sad, silly), actions (a one-shot: wave, laugh, jump, spin), and a look/aim pad
   that points the head and eyes. Layered, not exclusive — the puppet can be happy,
   waving, *and* talking simultaneously.

### Stage modes
The same performance renders into one of several surfaces. Mode choice is a
one-tap setting, never a required setup step.

| Mode | How | Availability |
|---|---|---|
| **Solo** (default) | Stage top, controls bottom, one iPhone | MVP |
| **Big Screen** | Stage on a TV/monitor via AirPlay or cable; phone keeps the controls | MVP target — needs a technical spike first, see ARCHITECTURE §6.3 |
| **Two Devices** | Second iPhone/iPad is the stage; peer-to-peer over local network, no backend | Post-MVP — high value as the rehearsal for Duo |
| **Duo** | Inner screen = controls, outer screen = stage | Gated on hardware + SDK |

### What we deliberately leave out of v1
No accounts. No cloud. No sharing feed. No character creator. No multi-character
scenes. No recording in the first release (see Nice-to-have in
[ROADMAP.md](ROADMAP.md)). Every one of these adds a screen between the user and
the puppet.

---

## 4. MVP scope

Full breakdown with must / nice-to-have / later is in **[ROADMAP.md](ROADMAP.md) §1**.

Summary of the must-have set:

- One finished original character (Moppet, §6) with idle life
- 4 expressions, 6 actions, look/aim control, mic-driven mouth
- Solo mode on a single iPhone, portrait and landscape
- 2 backdrops, a small sound bank, 2–3 voice-FX presets
- Onboarding that is under 15 seconds and skippable
- Accessibility: full no-microphone path, Reduce Motion support, VoiceOver on controls
- Settings, privacy policy, privacy manifest
- Paid unlock scaffolding (StoreKit 2), even if v1 ships everything free

---

## 5. Monetization

**Recommendation: free download, one-time "Full Cast" unlock, plus occasional paid
character packs. No ads. No subscription in v1.**

| Model | Assessment |
|---|---|
| **One-time unlock ($9.99–$14.99)** — ✅ recommended | Parents strongly prefer a single price for a kids' toy. No churn management, no renewal support load, no subscription-cancellation reviews. |
| **Character packs ($2.99 each)** — ✅ recommended, later | Natural expansion, each pack is a marketing beat. Only viable once the art pipeline is proven. |
| **Subscription ($3.99/mo)** — ⚠️ not v1 | Requires a steady content cadence we cannot commit to yet, and draws poor reviews on toy apps. Revisit only if we ship monthly characters. |
| **Ads** — ❌ | Wrong for the audience, and third-party ad SDKs are effectively incompatible with the Kids Category. |
| **Paid up front** — ❌ | Kills the "show a friend in 15 seconds" loop that is our whole distribution strategy. |

**Free tier must be genuinely good.** One complete character with every action
unlocked. We sell *more cast*, never *more function* — a paywall in front of the
laugh button destroys the product.

*All prices above are proposals, not researched figures. Validate against comparable
App Store titles before committing.*

---

## 6. The cast

Four characters ship in the prototype. All are original designs; all use the same rig
and the same repertoire, and differ in proportion and — far more importantly — in
**timing**. Pip breathes twice as fast as Bramble and blinks four times as often, which
does more for the character than any amount of silhouette work.

| | Reads as | Distinguishing trait |
|---|---|---|
| **Moppet** | Steady, warm, unbothered | Mismatched button eyes; orange tuft |
| **Pip** | Excitable, never settles | Huge eyes, bobbing antenna, 2.1s breath |
| **Bramble** | Slow, deadpan | Heavy lids that never fully open; long swinging ears |
| **Thistle** | Fidgety, up to something | Very wide mouth; spiky crest; constant sway |

See [docs/CHARACTERS.md](docs/CHARACTERS.md) for how to add the next one.

### Moppet — the lead

A shaggy, lopsided sock-creature. Deep teal fur with a lighter belly patch.
Mismatched button eyes — one large, one small — which makes every expression read
as slightly surprised and gives the face a free dose of personality. A wide, floppy,
felt-lined mouth that takes up a third of the head. Two stubby arms with no hands.
No legs: the body tapers into a soft base so it can bob, lean, and topple without
ever needing a walk cycle. A single tuft of orange hair that lags behind head
movement — cheap secondary animation, huge charm payoff.

**Why this design:** strong silhouette at thumbnail size, mouth big enough for
amplitude-driven lip-sync to read from across a room, no legs means no locomotion
rig, and the whole character is buildable as ~10 flat cut-out parts.

> **Name clearance is required.** "Moppet" is a proposed working name only. Before
> any public use it needs a trademark search and an App Store name-availability
> check. Same applies to "Puppet Master" itself, which is a common phrase and may
> already be taken in the App Store. Treat both as unresolved — see
> [OPEN-QUESTIONS.md](docs/OPEN-QUESTIONS.md) Q7.

### Expressions (held states — one active at a time)
| | Description |
|---|---|
| **Neutral** | Default. Soft mouth, relaxed eyes. |
| **Happy** | Eyes curve up, mouth corners lift, crest perks. |
| **Whoa** | Brows up, mouth rounds, body pulls back. |
| **Silly** | Brow cocked, tongue out the side, head tilts. |
| **Sad** | Inner brows up, gaze down, body sinks. The droop matters more than the frown. |
| **Grumpy** | Brows down and angled in, mouth set, head turned away. |
| **Sleepy** | Heavy lids, slow gaze, head tipped. Layers with a blink to close fully. |

### Actions (one-shot, layered over the current expression)
| | Feel |
|---|---|
| **Wave** | Arm sweeps, body counter-leans. The universal "hello". |
| **Laugh** | Whole body bounces, head tips back, mouth opens rhythmically. |
| **Jump** | Squash, launch, squash. With a small dust puff. |
| **Spin** | Fast horizontal whirl, ends with a dizzy wobble. |
| **Yes / No** | Nod and shake. Essential for the puppet to *converse*. |
| **Topple** | Falls over sideways, pauses, springs back up. Reliably funny. |
| **Dance** | Weight shifts side to side, arms trading places, music notes. |
| **Cheer** | Arms up, two bounces, confetti. |
| **Sneeze** | Long wind-up, very short snap. All the comedy is in that ratio. |
| **Peek** | Hides behind its arms, waits a beat too long, pops out. |
| **Yawn** | Slow open, slow close, then a small shiver. Contagious if timed right. |

### Continuous drivers (always available, always layered)
- **Talk** — microphone amplitude opens the jaw
- **Look** — drag anywhere on the stage to aim head and eyes
- **Idle** — breathing, blinking, micro-sway; never fully off

Four expressions × six actions × two live drivers is enough to hold a two-minute
improvised conversation with a child. That is the bar for "enough to demonstrate
the product."

---

## 7. UX flow — launch to performing

```
COLD LAUNCH
    │
    ├─ Splash (≤1s, no logo animation)
    │
    ▼
PUPPETEER SCREEN  ◄── the app opens directly here; no menu, no character picker
    │
    │   Moppet is already on stage, breathing, and waves once
    │   unprompted. Controls are visible and unlabeled-but-obvious.
    │
    ├─ First run only: a single translucent coach card over the controls —
    │   "Tap to make Moppet move. Hold 🎤 to give it your voice."
    │   Dismissed by any tap. Never shown again.
    │
    ▼
USER TAPS AN ACTION ──────────► puppet performs immediately  ──┐
    │                                                          │
    ├─ USER DRAGS ON STAGE ───► head and eyes follow ──────────┤
    │                                                          │
    ├─ USER HOLDS 🎤                                            │
    │     └─ first time only: a plain-language reason screen,   │
    │        then the system mic prompt.                        │
    │        Declined? The button becomes "Silly Voice" and     │
    │        drives the jaw from a canned rhythm instead.       │  LOOP
    │     └─ mouth follows their voice ─────────────────────────┤
    │                                                          │
    └─ ⋯ (secondary, behind one button each)                    │
          ├─ Stage mode: Solo / Big Screen / Two Devices       │
          ├─ Backdrop picker                                    │
          ├─ Voice FX preset                                    │
          └─ Settings ────────────────────────────────────────┘
```

**Rules this flow encodes**
- Zero mandatory setup. No permission is requested before the user has seen value.
- Microphone denial is a supported, non-degraded path — not an error state.
- Every secondary feature is exactly one tap off the main screen and returns to it.
- The app never shows an empty or static stage.

---

## 8. Future: the Duo experience

**We are designing for it, not building on it.** No Duo-specific API is assumed,
referenced, or stubbed against a guessed signature. Everything below is a product
intention to be validated once hardware and an SDK exist.

The intended experience:

- **Outer screen → the stage.** Full-bleed puppet, no UI chrome, no controls. This
  is what the audience sees, and it should look like a little television.
- **Inner screen → the control booth.** Larger, richer controls than the phone
  version can afford: a full expression grid, an action palette, a proper aim pad,
  sound-effect buttons, maybe a script/prompt strip.
- **The seam is the point.** The performer sees their instrument; the audience sees
  only the performance. That is a genuinely new thing a dual-screen phone enables,
  and it is why this product is worth building for that device specifically.

**How we stay honest about it:** the app is already split into a `Stage` renderer
and a `Controls` renderer over one shared engine, addressed through a `DisplayRole`
abstraction (ARCHITECTURE §6). Shipping **Two Devices** mode on ordinary iPhones
proves that split works under real separation, using only public frameworks. When
a Duo SDK arrives, it should be a new presenter behind the existing protocol — not
a rewrite. If it turns out to require more than that, we will have learned it from
a shipped feature rather than a guess.

---

## 9. Risks and unknowns

### Product
| Risk | Severity | Mitigation |
|---|---|---|
| **It is a novelty, not a habit.** High delight, low retention. | High | Accept it. Monetize on first-session delight (one-time unlock) rather than long-tail engagement. Do not build retention machinery for a toy. |
| **The "two audience" premise is weak in Solo mode.** On one screen the watcher sees the controls, which may break the illusion. | High | This is the core thing Phase 0 must test. If Solo is not fun, Big Screen / Two Devices become must-haves rather than options. |
| **Art quality *is* the product.** Mediocre character art sinks it regardless of engineering. | High | Budget for a professional character designer early. Do not ship placeholder art. |
| **Discovery.** Toy apps live or die on App Store visuals and word of mouth. | Medium | Treat the icon, screenshots, and a 15-second preview video as P0 deliverables, not afterthoughts. |

### Technical
| Risk | Severity | Mitigation |
|---|---|---|
| **Duo hardware, SDK, timing, and capabilities are all unknown.** | High | Build nothing against assumed APIs. Keep the display abstraction thin enough to be cheap if it is wrong. |
| **External-display support in a SwiftUI app.** Modern iOS uses scene-role-based external display attachment; a SwiftUI-only app may need UIKit scene plumbing. Unverified. | Medium | Time-boxed spike in Phase 0 before Big Screen is promised in scope. |
| **Real-time audio → UI thread.** The mic tap runs on an audio thread; naïve bridging causes glitches or dropped frames. | Medium | Lock-free hand-off plus smoothing; documented in ARCHITECTURE §5. |
| **Frame-rate on older devices** with layered animation, particles, and live audio. | Medium | Set a minimum target device early; profile every phase. |
| **Animation tech lock-in.** | Low | Mitigated by renderer-agnostic pose model (ARCHITECTURE §7). |

### Legal / compliance
| Risk | Severity | Mitigation |
|---|---|---|
| **Kids Category obligations** if we target under-13s: parental gate, no third-party analytics/ads, stricter privacy. | High | Decide before implementation (Q1). The decision constrains the SDK list and the IAP flow. |
| **Microphone permission draws App Review scrutiny** and user suspicion. | Medium | Explicit in-app reason screen, on-device processing only, nothing recorded or transmitted, stated plainly in the privacy policy and privacy manifest. |
| **Name and trademark** for both "Puppet Master" and "Moppet" are uncleared. | Medium | Clear before any store listing or artwork finalization. |
| **Original IP discipline.** | Medium | All characters original. Written brief to any contractor forbidding resemblance to existing properties; keep signed asset provenance records. |

### Accessibility
Voice-driven and motion-heavy by nature. A complete no-microphone path, Reduce
Motion honoring, and VoiceOver-labeled controls are must-haves, not later work.

---

## 10. Open questions

See **[docs/OPEN-QUESTIONS.md](docs/OPEN-QUESTIONS.md)** — ten decisions needed
before implementation starts.
