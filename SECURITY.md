# Security policy

## Supported versions

| Part | Supported |
|---|---|
| iOS app | The latest version on the App Store |
| Web game and server | What is running at [guesswick.com](https://guesswick.com), which is built from `main` |
| Older app versions and forks | Not supported |

## Reporting a problem

**Please report privately. Do not open a public issue.**

Use either of these:

1. **GitHub private reporting (preferred).** Go to the
   [Security tab](https://github.com/jasonepage/Wick/security) and choose
   "Report a vulnerability". Only the maintainer can see it.
2. **Email** support@guesswick.com with "Security" in the subject line.

Please include:

- what part is affected (iOS app, web game, or server)
- the steps to reproduce it, or a small proof of concept
- what an attacker could do with it
- whether you would like to be credited, and under what name

Wick is maintained by one person. You can expect a first reply within about a
week. Fixes for serious problems come first; we will keep you posted and agree
on a date before anything is made public.

## What counts

In Wick, the most important thing to protect is the answer. These are all in
scope:

- **Learning the secret word without guessing it**, from any route, socket
  message, share link, preview card, replay video, Keeper reply, error
  message, or timing difference
- **Changing the result of a live race** you did not win, or scoring a guess
  the server did not score
- **Using the server to burn its Gemini quota** faster than the rate limits
  are meant to allow
- **Cross-site scripting or injection** on guesswick.com
- **Anything typed by a player leaving the device** in a way that
  [PRIVACY.md](PRIVACY.md) does not describe
- **Exposed keys or secrets** in this repository or on the live service

## Out of scope

- Volume based denial of service against guesswick.com. If you want to measure
  load, run your own copy of the server; `debug/loadtest.mjs` exists for that.
- The `/debug/*` routes on a server where you set `WICK_DEBUG_TOKEN` yourself.
  They reveal the answer by design and are off in production.
- Problems that need a jailbroken device, a rooted phone, or physical access
  to someone else's unlocked device.
- Social engineering, spam, or reports from automated scanners with no working
  example.

## Known limits

These are documented trade-offs, not secrets:

- **Live race identity is not yet cryptographically verified.** Each player is
  identified by a random per-install id. Today the server protects itself with
  per-IP rate limits and an allow list of browser origins. Apple App Attest
  (and a signed session for the web) is planned as the next layer; the seam
  for it is in `wick-api/src/hub.ts`.
- **The server keeps no database.** Match rooms and counters live in memory
  and are cleared on restart.

## Safe harbor

If you act in good faith, stay within this policy, do not access or change
other players' data, do not degrade the live service, and give us reasonable
time to fix the problem before you share it, we will not pursue or support
any action against you for your research.
