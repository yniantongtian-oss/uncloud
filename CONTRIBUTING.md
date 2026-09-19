# Contributing to Uncloud

First off — thank you. Uncloud's promise ("No cloud. No account. No server.") only holds if the code stays small, readable, and trustworthy, and that takes a community.

## Ways to contribute

- 🐛 **Bug reports** — use the [bug report form](.github/ISSUE_TEMPLATE/bug_report.yml); device, OS, and version details matter a lot for LAN software.
- ✨ **Feature ideas** — use the [feature request form](.github/ISSUE_TEMPLATE/feature_request.yml); check [docs/roadmap.md](docs/roadmap.md) first.
- 🔀 **Code** — engine (`core/`), app (`app/`), protocol, tests.
- 📝 **Docs & translations** — keep `README.md` and `README.zh-CN.md` in sync; new languages for the app UI are welcome.
- 🔍 **Protocol review** — [docs/protocol.md](docs/protocol.md) is the spec; holes and edge cases found by reading it are first-class contributions.

Look for issues labeled **`good first issue`** — they're scoped, explained, and a maintainer will happily pair you to the finish line.

## Development setup

**Prerequisites:** Node.js **≥ 20** (24 LTS recommended), Flutter stable.

```bash
git clone https://github.com/yniantongtian-oss/uncloud.git
cd uncloud

# Core engine — zero dependencies, nothing to install
cd core
npm test                       # node:test suite
node bin/uncloud.js demo       # full protocol walkthrough

# App
cd ../app
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter run
```

The core engine has **no npm dependencies by design** — please don't add one without a very good reason discussed in an issue first.

## Branch & PR rules

- Branch from `main`: `feat/<slug>`, `fix/<slug>`, `docs/<slug>`, or `chore/<slug>`.
- One concern per PR; small PRs get reviewed fast.
- Fill in the PR template — especially the test plan.
- CI must pass: `npm test` for `core/`, `flutter analyze --no-fatal-infos` + `flutter test` for `app/`.
- Changes to behavior must update `docs/` and, where user-facing, **both** READMEs (English + 中文).
- By contributing you agree your work is licensed under [Apache-2.0](LICENSE).

## Commit style

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(core): resume interrupted transfers from byte offset
fix(app): correct zh-CN plural forms in backup banner
docs(protocol): clarify peer expiry wording
chore(ci): cache flutter pub dependencies
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`. Scope is usually `core`, `app`, `protocol`, or `docs`. Keep the subject under 72 characters, imperative mood.

## Code of conduct

This project follows the [Contributor Covenant v2.1](CODE_OF_CONDUCT.md). Be kind; we're all here because we want our photos back.
