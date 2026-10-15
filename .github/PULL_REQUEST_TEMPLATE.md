## What this changes

<!-- One or two sentences. Link the issue it fixes, for example "Fixes #12". -->

## Which parts it touches

- [ ] iOS app
- [ ] Web game
- [ ] Server
- [ ] Word lists or translations
- [ ] Docs only

## How I tested it

<!-- What you ran and what you checked by hand. Screenshots or a short recording help for anything visual. Hide the daily answer if it shows. -->

## Checklist

- [ ] `npm run typecheck`, `npm test` and `npm run build` pass in every Node folder I changed (`wick-api`, `wick-web`)
- [ ] If I changed Swift, the app builds and the Hunch tests pass in Xcode
- [ ] New logic comes with a test
- [ ] The answer can never reach a player before the round is solved (routes, socket messages, share links, replays, logs, error messages)
- [ ] If I changed scoring bands, the daily pool, a reference vocabulary or the race messages, I changed both iOS and the server or web to match
- [ ] If anything new leaves the device, I updated `PRIVACY.md`, the website privacy page and `PrivacyInfo.xcprivacy`
- [ ] No new dependency, or I explain why it is needed and its license works with MPL 2.0
- [ ] New source files start with the MPL license header; outside data is listed in `THIRD_PARTY_NOTICES.md`
- [ ] No keys, tokens or personal Apple team details are committed

By opening this pull request I agree that my contribution is shared under the [Mozilla Public License 2.0](../LICENSE).
