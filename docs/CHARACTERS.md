# Adding a character

Characters are **data**. Adding one to the cast means adding one value to
[`CharacterLibrary.swift`](../PuppetMaster/Core/Content/CharacterLibrary.swift) — no new
views, no new actions, no renderer changes, no asset pipeline. This document exists to
prove that claim and to make the next one take twenty minutes.

---

## The shape of a character

A `CharacterDescriptor` is nine groups of numbers:

| Group | What it controls |
|---|---|
| `palette` | Fur, belly, accent, eyes, mouth, tongue. The outline is **derived** from the fur, so it can never drift. |
| `body` | Silhouette, measured from the floor up: height, waist, shoulders, base, belly patch. |
| `head` | Half-width, half-height, and how high it sits. |
| `eyes` | Radii (deliberately mismatched on some), centres, pupil size, and `lidRest`. |
| `mouth` | Half-width, how far the jaw drops, where it sits, lip weight. |
| `brows` | Widths, thickness, height. The single biggest contributor to readable emotion. |
| `arms` | Shoulder position (mirrored), length, thickness. |
| `crest` | `tuft`, `ears`, `antenna`, `spikes` or `none`, plus size and how much it swings. |
| `personality` | Breath period and depth, blink interval and speed, sway, gaze wander, head tilt. |

Every character drives the same twelve actions and seven expressions. Nothing is
per-character except these numbers.

---

## Timing does more than shape

This is the part that is easy to get wrong. If you give a new character interesting
proportions and leave `personality` at its defaults, it will look different and *feel*
identical — which reads as a reskin, and players notice.

The existing four differ most in their timing:

| | Breath period | Blink interval | Sway | Reads as |
|---|---|---|---|---|
| **Moppet** | 3.4s | 2.0–6.5s | 1.0 | Steady, warm |
| **Pip** | 2.1s | 0.9–2.8s | 1.5 | Excitable, never settles |
| **Bramble** | 5.6s | 5.0–11.0s | 0.55 | Slow, deadpan |
| **Thistle** | 2.8s | 1.4–4.2s | 1.8 | Fidgety, up to something |

Bramble also has `lidRest: 0.40`, so its eyes never fully open. That one number does more
for the character than its entire silhouette.

**Pick the temperament first, then the shape.**

---

## Recipe

1. Add a `static let` to `CharacterLibrary` and put it in `all`.
2. Choose a `personality` that is genuinely distinct — the test suite fails if two
   characters share a breath period, deliberately.
3. Sketch proportions. Rules the tests enforce:
   - `head.centerY` must be above half the body height, or the head visibly detaches.
   - `arms.shoulder.y` must not exceed `body.height`.
   - Nothing may be zero or negative.
4. Run the tests. `CharacterLibraryTests` checks the geometry, uniqueness, and that the
   descriptor survives a JSON round trip.
5. Look at it. `CastSheet` picks it up automatically.

---

## Proportion notes

- **The mouth must be big.** It carries the lip sync, and it has to read from across a
  room. `mouth.halfWidth` below ~45 disappears at a distance.
- **The head does the acting.** When in doubt make it larger, not smaller.
- **Mismatched eyes are free personality.** Different radii make every expression read
  as slightly off-balance without any extra work.
- **No legs.** The body tapers to a rounded base so the puppet can bob, lean and topple
  without a walk cycle. Do not add legs; nothing in the action library drives them.
- **Crest is the species marker.** It is the cheapest way to stop two characters built
  from one rig reading as the same creature in different colours.

---

## Where this goes next

`CharacterDescriptor` is `Codable` all the way down, and a test asserts the round trip.
That is deliberate: moving the cast to per-character JSON in the bundle — and from there
to downloadable character packs — is a loading change, not a runtime one. Nothing in the
engine, the rig or the action library needs to know where a character came from.

The remaining work for real character packs is a loader, a manifest, and StoreKit
entitlements. None of it touches what is described above.
