# Game feel and engagement design

How Puppet Master tries to be satisfying — and, just as deliberately, what it refuses
to do to keep you.

---

## The position

There are two very different things that get called "engagement".

**Satisfaction** is making the thing itself good: responsive controls, motion with
weight, sound that lands on the beat, a character that reacts to you. It rewards the
user in the moment and costs them nothing.

**Compulsion** is making it expensive to stop: streaks, daily-login rewards,
variable-ratio reward schedules, countdown timers, notification nagging, artificial
scarcity. It works, and it works best on exactly the people this app is for.

**This app builds the first and refuses the second.** Not as a moral flourish — a
puppet toy for young children, plausibly in the App Store Kids Category (see
[OPEN-QUESTIONS.md](OPEN-QUESTIONS.md) Q1), is the worst possible place to install a
compulsion loop. The engagement plan is: *make it feel so good that people come back,
and let them leave whenever they want.*

Specifically, this app will not ship: streaks or "don't break your chain" mechanics,
daily login rewards, engagement push notifications, energy or cooldown timers,
loot boxes or randomised paid rewards, FOMO ("3 hours left!"), or anything that
measures and displays time spent to encourage more of it.

---

## What actually makes it feel good

### 1. Nothing waits

Every control fires on touch-down, not touch-up. The microphone has ~20ms attack.
There is no confirmation step anywhere. The single most important input latency in the
app — your voice to the puppet's jaw — is a lock-free atomic read, not a queue.

### 2. Anticipation, then follow-through

Every action winds up before it acts and overshoots before it settles. A jump squashes
before it launches. The sneeze's whole joke is a 0.52s wind-up against a 0.1s snap. This
is standard animation practice and it is most of why the moves read as alive rather
than as clips being played.

### 3. Weight you can feel and hear

A landing does four things at once: dust, a shrinking shadow snapping back, a screen
shake, and a low thud with a noise transient. Remove any one and it reads lighter.
Haptics fire on the **animation beat**, not on the button press — you feel the landing
when it lands, not when you asked for it.

### 4. The character has a voice

Every sound is synthesised at runtime, which means it can be pitched per character.
Pip squeaks at 1.42×, Bramble rumbles at 0.66×, out of the same bank. A new character
gets a voice for free — one number.

### 5. It reacts to *you*

- **Poke it.** A quick tap on the stage startles the puppet: it flinches, squeaks, and
  looks straight at your finger. Nothing tells you this is possible, which is exactly
  why finding it out is a reward.
- **Look where you point.** Eyes lead, head follows — the ordering that makes a glance
  read as intentional.
- **Talk and it talks.** Loudness, not words, so it works in any language and for a
  four-year-old making a noise that isn't one.

### 6. It is alive when you are not

The idle layer never switches off: breathing, irregular blinking with occasional
doubles, weight shift, gaze wander — all on non-harmonic periods so the loop never
shows.

And if you put the phone down, **the puppet gets bored**. After 14 seconds it yawns.
Eleven seconds later it hides and peeks to see whether that got your attention. Fifteen
seconds after that it gives up and dances for itself.

This is the app's entire engagement design, and it is the honest kind: a reason to pick
the phone back up that costs nothing if you don't, disappears the instant you touch
anything, and never leaves the device to find you. Compare with a push notification
that says "Moppet misses you!" — same intent, completely different ethics. We do the
first and not the second.

---

## What is deliberately absent (for now)

- **No score, no progress bar, no unlock tree.** A puppet stage is an instrument, not a
  game with a win condition. Adding progression would change what the product *is*.
- **No combo escalation yet.** Repeating an action could make it grow sillier. It is
  genuinely fun and it is not a dark pattern — it just isn't built.
- **No "collect all the characters" framing.** Characters will be sold, but as more
  cast to perform with, never as a set to complete.

---

## The one metric worth watching

Not session length. Not retention. **Whether a child laughs in the first fifteen
seconds.** That is the Phase 0 exit gate in [ROADMAP.md](../ROADMAP.md), and it is the
only number that tells you whether any of the above worked.
