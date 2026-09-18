# Open Product Questions

Decisions needed from Omer **before implementation starts**. Roughly ordered by how
expensive each is to change later.

---

### Q1 — Do we target the App Store Kids Category? 🔴 *decide first*
The most consequential question here. Choosing Kids means: a parental gate in front
of IAP and any external link, **no third-party analytics or ad SDKs at all**, stricter
data handling, and extra App Review scrutiny. It also means placement in a browsable,
less crowded category.
**Why it must come first:** it constrains the dependency list, the paywall flow, and
the privacy work — all expensive to retrofit.
*Recommendation: yes, target Kids, and design for zero third-party SDKs anyway.*

### Q2 — Who is the primary buyer: the parent or the kid? 🔴
Both use the app; only one pays. Parent-first means calmer visual design, a visible
"made for grown-ups to perform" framing, and simpler pricing. Kid-first means louder
art and a much stricter Kids-Category posture.
*Recommendation: parent-first. They hold the phone, they laugh first, and they pay.*

### Q3 — Is Solo mode (one screen, stage + controls) actually the product, or a
compromise? 🔴
If the real experience needs two surfaces, then Big Screen or Two Devices is a
must-have, not a nice-to-have — and the MVP is meaningfully larger. Phase 0 user
testing should answer this, but your instinct matters now because it changes the
scope estimate.

### Q4 — Free with a one-time unlock, or something else? 🟠
See [PRD §5](../PRD.md#5-monetization). Affects the paywall, the store setup, and
what ships free in v1. Also decide whether v1 ships *entirely* free (buy nothing) with
the store wired but dormant — which is a good way to learn what people value before
pricing it.

### Q5 — What is the oldest iPhone we support? 🟠
Drives the performance budget and therefore how many layers, particles, and blurs the
art can use. Cannot be decided late — the art direction depends on it.

### Q6 — How many characters at launch: one polished, or two? 🟠
One lets us perfect the pipeline and the character. Two proves the pipeline is
repeatable and makes the character-pack model credible. It roughly doubles the art
cost and adds a picker screen to the flow.
*Recommendation: one at launch, second character as the first update — it gives us a
reason to re-engage users and press.*

### Q7 — Name clearance for "Puppet Master" and "Moppet". 🟠 *blocking for release*
Both are working names. "Puppet Master" is a common phrase and may already exist on
the App Store; "Moppet" is a common noun. **Neither has been checked.** Needs a real
trademark search and an App Store name-availability check before any store listing or
final artwork. Who runs this, and by when?

### Q8 — Deployment target: iOS 26, or iOS 25 and earlier? 🟡
Machine has the iOS 27 SDK. Targeting iOS 26 (one version back) gives modern APIs and
broad reach. Going further back widens the audience but costs compatibility work.
*Recommendation: iOS 26.0, revisited against real adoption numbers at Phase 1 start.*

### Q9 — Does v1 include recording and export? 🟡
A recorded performance is the app's best marketing asset and its most shareable
output. It is also extra scope, a Photos permission, and a content-moderation-adjacent
question if sharing ever becomes social.
*Recommendation: not in v1. First update.*

### Q10 — Do we build Two Devices mode before Duo hardware exists? 🟡
It costs real time and few users will have two iPhones handy. But it is the only way
to prove the stage/controls separation on hardware that exists today, and it makes the
eventual Duo work small instead of speculative.
*Recommendation: yes, in Phase 2 — treat the cost as insurance on the Duo bet rather
than as a feature.*

---

### Not questions — stated constraints, flagged so they are not silently dropped
- No Duo-specific code is written until a public SDK exists.
- All characters are original creations; no third-party IP, ever.
- No backend, no accounts, no third-party dependencies in v1.
