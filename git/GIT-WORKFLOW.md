# STRATUM-Desktop — Git Workflow

This repo follows a **feature-branch + semantic-version-tag** model. One feature
lives on one branch; shipping it produces one version. The architecture is a set
of decisions encoded in three scripts under `git/`.

## The model

```
main ──●────────────────●────────────────●──────────►   (always buildable)
        \              / \              /
         ● ● ● feature/A   ● ● ● feature/B
        feat commits       feat commits
              │                  │
            v0.2.0             v0.3.0          ← annotated tag = the version + its note
```

- **`main`** — integration branch. Always in a buildable state. Never commit features directly to it.
- **`feature/<name>`** — one branch per feature. Commit freely here.
- **`vX.Y.Z` tag** — created when a feature merges to `main`. The tag's annotation is the per-version comment.
- **GitHub Release** (optional) — a published, human-visible version with auto-generated notes.

`qgroundcontrol/` is a **submodule** pinned to a specific upstream commit. Your repo
stores only a pointer, not QGC's source. Cloning fresh requires `--recurse-submodules`.

## Prerequisites (one time)

1. **Git for Windows** (provides Git Bash, where these scripts run).
2. **GitHub CLI**: install from https://cli.github.com, then authenticate:
   ```bash
   gh auth login
   ```
   Choose GitHub.com → HTTPS → authenticate in browser.

## 1. Create the repo (run once)

In **Git Bash**:

```bash
cd /c/Users/Anas-NX/OneDrive/NEXAM/10_Systems_Engineering/Systems_Engineering/STRATUM-Desktop
bash git/00-bootstrap-repo.sh
```

This initializes git, converts `qgroundcontrol/` into a pinned submodule, makes the
initial commit, creates a **private** GitHub repo named `STRATUM-Desktop`, pushes,
and tags the baseline `v0.1.0`. (To use a different name/visibility, edit the
config block at the top of the script first.)

## 2. Develop a feature

```bash
bash git/new-feature.sh override-surface-map      # -> branch feature/override-surface-map
# ... edit code ...
git add -A
git commit -m "feat: add surface-map override toggle in FlyView"
git commit -m "test: cover override edge cases"
```

Commit as often as you like; these become the feature's history.

## 3. Ship it as a version

From the feature branch:

```bash
bash git/finish-feature.sh minor "Surface map override view"
```

This merges the feature into `main` (`--no-ff`, so the feature stays visible as one
unit), bumps the version (`v0.1.0 → v0.2.0`), creates an **annotated tag** carrying
your note (the per-version comment), and pushes `main` plus the tag. Add `--release`
to also publish a GitHub Release:

```bash
bash git/finish-feature.sh minor "Surface map override view" --release
```

### Version bump rules (semver)

| Arg     | Use when…                                  | Example         |
|---------|--------------------------------------------|-----------------|
| `major` | breaking change / incompatible behavior    | `1.4.2 → 2.0.0` |
| `minor` | new feature, backward-compatible (default) | `1.4.2 → 1.5.0` |
| `patch` | bug fix only                               | `1.4.2 → 1.4.3` |

## Reviewing history

```bash
git tag -l 'v*' --sort=-v:refname     # all versions, newest first
git show v0.2.0                       # the version's note + diff
git log --oneline --graph --decorate  # branch/merge/tag topology
```

## Cloning this repo elsewhere (with the submodule)

```bash
gh repo clone STRATUM-Desktop -- --recurse-submodules
# or, after a plain clone:
git submodule update --init --recursive
```

## Recovery notes

- **Bootstrap re-run** refuses if `.git` already exists — by design; it is a one-time op.
- **Submodule shows as modified** after a build: QGC build artifacts changed its tree.
  Reset with `git -C qgroundcontrol checkout .` — your superproject only cares about the pinned commit.
- **Pushed wrong tag**: `git push origin :refs/tags/vX.Y.Z` deletes it remotely, then re-tag.

---

*Branch isolates risk. Tags make versions auditable. Decisions dictate destiny.*
