# Puppet Master — Asset Requirements

Everything that must be created, commissioned, or licensed. **Art is the long pole
of this project** — start commissioning at the beginning of Phase 1, not the end.

> **IP discipline.** Every character, sound, and piece of artwork must be original or
> properly licensed. Any contractor brief must explicitly forbid resemblance to
> existing characters or properties. Keep a signed work-for-hire agreement and a
> provenance record for every asset in `docs/art/`.

---

## 1. Character art — Moppet

The character is delivered as a **cut-out rig**: separate flat layers, each with a
defined pivot, exported at @1x/@2x/@3x into a texture atlas.

| Asset | Notes |
|---|---|
| Body (base) | Tapered base, no legs. Must survive squash/stretch |
| Belly patch | Separate layer for subtle independent motion |
| Head | Separate from body so it can tilt and turn |
| Upper jaw / lower jaw | **Split at the mouth line** — this is what the mic drives |
| Mouth interior | Dark inner mouth revealed when the jaw opens |
| Tongue | For the Silly expression |
| Eye L / Eye R (whites) | Mismatched sizes — large left, small right |
| Pupil L / Pupil R | Separate layers; translate for gaze |
| Eyelid L / Eyelid R | For blinking |
| Brow L / Brow R | Biggest single contributor to readable emotion |
| Arm L / Arm R | Two segments each if physics joints are used |
| Hair tuft | Orange; separate layer for lag/secondary motion |
| Shadow / contact blob | Sells weight; separate so it can scale on jumps |

**Also needed**
- Turnaround / model sheet (front, 3/4, expression grid) — the reference document
- Expression reference sheet: Neutral, Happy, Surprised, Silly
- Thumbnail portrait for the character picker and store listing
- Character brief document → `docs/art/moppet-brief.md`

**Format:** layered source (PSD/Procreate/Figma) **plus** exported transparent PNGs,
consistent canvas, pivots marked. Keep the layered source in the repo or in a linked
asset store — re-exports will be needed many times.

---

## 2. UI and app art

| Asset | Notes |
|---|---|
| App icon | All required sizes. **Ship a 1024×1024 master.** Must read at 60 px — a single Moppet face, not a scene |
| Control iconography | Expressions, actions, talk, sound, settings. One consistent style |
| Backdrops ×2 (MVP) | Simple, low-contrast, must never compete with the puppet. Parallax-capable layers are a bonus |
| Onboarding coach card | Single illustration + short copy |
| Paywall art | Cast lineup shot, for later |
| Empty/error states | Mic denied, peer disconnected, display lost |
| Launch screen | Static, plain, matches the first frame of the stage |

---

## 3. Animation assets

Mostly authored as **JSON action tracks** rather than drawn frames, but each needs
motion direction from the illustrator (timing charts or a reference GIF):

- Idle loop: breathe, blink, sway
- 4 expression transitions
- 6 action tracks: wave, laugh, jump, spin, nod/shake, topple
- Particle effects: dust puff (jump/topple), sparkle (happy), confetti (celebration)
- Talk mouth shapes: at minimum closed / mid / wide, blended by amplitude

---

## 4. Audio

| Asset | Notes |
|---|---|
| Action SFX ×6 | Wave whoosh, laugh, jump boing, spin whirr, nod tick, topple thud |
| UI SFX ×3 | Tap, unlock, toggle |
| Ambient beds ×2 | One per backdrop. Very quiet, loopable, optional |
| Voice-FX presets ×3 | Squeaky / Rumbly / Robot — built from AVFoundation units, tuned by ear, no asset needed |

**Licensing:** commission original, or use a clearly-licensed library with commercial
rights suitable for a paid app. Record the licence for every file. Avoid anything
with attribution-in-app requirements.

---

## 5. App Store assets

| Asset | Notes |
|---|---|
| Screenshots | Required device sizes. Show the *performance*, not the UI — a kid laughing at the phone communicates more than a feature list |
| App Preview video | 15–30s. This is the single highest-leverage marketing asset for a toy app. Budget for it properly |
| Description + subtitle + keywords | Keyword research needed |
| Promotional text | Updatable without review — use it for new characters |
| Age rating questionnaire answers | Depends on the Kids Category decision |
| Privacy nutrition label | Must match `PrivacyInfo.xcprivacy` exactly |

---

## 6. Marketing and legal

- Privacy policy page (public URL — required by App Store Connect)
- Support page / contact email (required)
- Terms of use, if IAP ships
- Landing page (optional for v1)
- Social clips: 5–10 short vertical videos of real performances
- Press kit: icon, character art, 3 screenshots, one-paragraph description
- **Trademark search** for "Puppet Master" and "Moppet" *(blocking — OPEN-QUESTIONS Q7)*
- Work-for-hire agreements with every contributor

---

## 7. Recommended ordering

1. **Character brief** → written before anyone is hired
2. **Moppet model sheet + expression sheet** → approve before any rigging
3. **Cut-out layers + atlas export** → unblocks all animation work
4. **App icon** → needed early for TestFlight builds
5. **Sound bank** → can run in parallel with rigging
6. **Backdrops**
7. **Screenshots + preview video** → last, and only with final art
