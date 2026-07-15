# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Standalone, dependency-free installer/setup scripts, each a single self-contained file with no shared library, build system, package manifest, or test suite:

| File | Platform | Purpose |
|---|---|---|
| `install-windows.ps1` | Windows 10/11 | Detects & installs a fixed catalog of freeware via winget |
| `install-linux.sh` | Debian / Ubuntu / Mint / Pop!_OS | Same catalog via apt |
| `setup-windows.ps1` | Windows 10/11 | New-machine bootstrap: winget/Git/GitHub CLI/repo clone/Claude Code CLI |
| `update-windows.ps1` | Windows 10/11 | Standalone: runs `winget upgrade` for the catalog programs from `install-windows.ps1`; can self-register as a weekly Scheduled Task |
| `move-user-folders-windows.ps1` | Windows 10/11 | Standalone: moves Pictures/Downloads/Documents to another drive |
| `bootstrap/` | Windows 10/11 | Standalone kit for a fresh machine: a copy of `setup-windows.ps1` + a bootstrap `CLAUDE.md` that clones this repo |

`freeware-install-spec.md` is the original spec (originally written in German, translated to English — see git history for the original German text) the two `install-*` scripts were generated from; treat it as the source of truth for their intended behavior if the scripts and docs ever disagree. `setup-windows.ps1`, `update-windows.ps1`, and `move-user-folders-windows.ps1` are a separate concern (initial machine setup / update maintenance / data relocation, not freeware installation) and have no corresponding spec file — their behavior is defined by the scripts themselves and by `README.md`.

This repo lives at `https://github.com/schaib903/install-assistant` (public).

### The `bootstrap/` folder is a special case — read before touching it

`bootstrap/CLAUDE.md` is **not** this file. It's a separate, minimal `CLAUDE.md` meant to be copied (together with `bootstrap/setup-windows.ps1`) onto a brand-new Windows machine that has neither Git nor this repo yet. When a user starts `claude` inside that bootstrap folder, Claude Code reads *that* file instead of this one, and its only job is to `git clone` this repo. Do not merge the two files or delete `bootstrap/CLAUDE.md` thinking it's a duplicate — it is intentionally separate because a directory can only have one auto-loaded `CLAUDE.md`, and this repo's root and the bootstrap kit are different directories with different jobs.

`bootstrap/setup-windows.ps1` is a **plain copy** of the root script, not a symlink or generated artifact (there's no build step in this repo to regenerate it). When you change `setup-windows.ps1` at the repo root, copy the change into `bootstrap/setup-windows.ps1` too, or the bootstrap kit silently goes stale.

## Running / testing changes

There is no automated test harness. Verify changes by executing the script directly:

```powershell
.\install-windows.ps1
```

```bash
chmod +x install-linux.sh
./install-linux.sh
```

If a `.sh` file was edited or created on Windows, it will have CRLF line endings and fail on Linux with `bad interpreter`. Convert before testing/committing:
```bash
sed -i 's/\r//' install-linux.sh
```

Both scripts are interactive (they prompt with `Y/N` and a Python-version number choice) and mutate real system state (they install software via winget/apt), so a dry run or careful narration of what would happen is preferable to blindly executing them in an agent context. If a `--dry-run` flag has been added (see prompt catalog below), prefer testing with that.

`move-user-folders-windows.ps1` is higher-stakes to test than the other scripts: it moves real user data (Pictures/Downloads/Documents) via `robocopy /MOVE`, which deletes the source after copying. Always verify changes with declined answers first (`N` at every prompt) before ever answering `Y` to the folder-move question on a real machine — a syntax check (`[System.Management.Automation.Language.Parser]::ParseFile(...)`) plus a declined-answers dry run is the safe verification loop; there is no safe way to test the actual move without touching real files.

## Architecture — both scripts share one linear flow

Both scripts implement the identical pipeline described in `freeware-install-spec.md`, just in PowerShell vs. Bash idiom. When adding a program or feature, **mirror the change in both files** — they are meant to stay behaviorally identical (Windows uses winget IDs, Linux uses apt package names).

1. **Platform guard** — abort with an error if run on the wrong OS or if the required package manager (`winget` / `apt-get`) is missing.
2. **Header + system info** — hostname, OS, RAM, CPU.
3. **Program table** — a flat list of `{Name, ID/package, detection paths/command}` checked in order. This is the primary place to add/remove software.
4. **Installed check** — each program is checked by binary/file-path presence first, then by package-manager query as a fallback (`Pruefe-Winget` in PS, `ist_installiert`/`paket_installiert` in Bash).
5. **Program selection** — the *missing* programs are shown as a numbered list and the user picks which ones to install (comma-separated numbers, `all`/`a`, or `none`/empty to select none). This is **not** "install everything missing" — the user opts in per item. Selection state lives in `$AusgewaehlteProgramme` (PS) / `AUSGEWAEHLT_NAMEN`+`AUSGEWAEHLT_PAKETE`+`AUSGEWAEHLT_SONDER` (Bash), built by filtering the missing-items list/arrays by chosen index.
6. **Python version matrix** — a separate parallel array (`$PythonVersionen` / `PYTHON_VERSIONEN`) of supported versions, checked independently, with the user prompted to pick one missing version to install (or skip). Reuses the same numbered-choice pattern as step 5, but single-select since only one Python version installs per run.
7. **Additional freeware prompt** — always asked (even if the whole catalog is already installed or nothing was selected in step 5), regardless of catalog status: "install something not on the list?" On yes, loops collecting free-text `Name` + `winget-ID` (PS) / `apt-Paketname` (Bash) pairs until the user submits an empty name. These go through the generic install path only — no bespoke function, since the ID/package is arbitrary user input.
8. **Installation overview + single Y/N confirmation** — summarizes the selected catalog programs + chosen Python version + custom entries together; nothing installs until this one combined confirmation. If literally nothing was selected/entered, the script reports that and exits before this prompt.
9. **Installation loop** — most programs install via a generic package-manager call; a few have bespoke functions for non-trivial installs (`installiere_chrome`, `installiere_brave`, `installiere_vscode`, `installiere_python` in Bash; the Windows script has no bespoke install functions at all — winget handles every catalog entry, including Brave and Adobe Reader, via the same generic `Winget-Installiere`). Custom/additional entries from step 7 always use the generic path.
10. **Final report** — lists what succeeded/failed (catalog + Python + custom, uniformly), with a hint (check permissions/internet) if anything failed.

### Conventions to preserve when editing

- **All visible output (messages, prompts, comments) is English**, hardcoded inline (not externalized to a resource file), for simplicity and easy in-place editing. **Internal function and variable names are intentionally still German** (`Pruefe-Winget`, `Installiere-Winget`, `$Fehler`, `$Erfolg`, `$Programme`, Bash's `abschnitt`, `ist_installiert`, `ROT`/`GRUEN`/`GELB`/`CYAN`/`WEISS`/`GRAU`/`RESET`, etc.) — the scripts were originally written entirely in German (output and code alike) and only the visible output was translated to English later, deliberately leaving identifiers untouched to keep that change small and low-risk. This is not an oversight — don't "fix" the German identifiers to be English unless explicitly asked to.
- **Colors/formatting are declared once at the top** — PowerShell uses `-ForegroundColor` params inline; Bash defines ANSI color variables (`ROT`, `GRUEN`, `GELB`, `CYAN`, `WEISS`, `GRAU`, `RESET`) at the top of the file.
- **Special-case programs get their own function** rather than being folded into the generic install loop — follow this pattern (e.g. `installiere_chrome`, `installiere_brave`) rather than adding conditionals to the main loop when a program needs a non-standard install path (custom repo/key, download-and-`dpkg -i`, etc). The Windows side needs this far less often, since winget's package IDs cover most of the catalog generically.
- Windows install status is double-checked: a known install-path (`Pfade`) check, then a `winget list` check — keep both, since some installs (e.g. portable/manual) won't register with winget.
- PowerShell winget exit codes are treated leniently: `$OkCodes = @(0, -1978335189, -1978335106, 3010)` covers "already installed"/"reboot required" cases as success — extend this list rather than treating any non-zero exit as failure.
- **Platform-only catalog entries are allowed and expected** — not every program needs to exist on both sides. Notepad++ is Windows-only; Adobe Acrobat Reader is Windows-only too (Adobe dropped official Linux support years ago) — when a program genuinely has no equivalent on one platform, just omit it from that script's arrays rather than forcing a workaround.
- **winget/gh output-parsing regexes stay bilingual** — e.g. `Pruefe-Winget`'s `"(No installed|Kein installiertes)"` parses winget's *own* CLI output, which is locale-dependent based on the end user's Windows language, not our script's UI language. Do not "clean up" the German half of these regexes; it's unrelated to the English-translation convention above.

## Adding or removing a program

Update both scripts' program tables in lockstep (unless the program is genuinely platform-only, see above):
- Windows: add an entry to the `$Programme` array (`Name`, winget `ID`, candidate `Pfade`).
- Linux: add to the four parallel arrays `PROG_NAMEN` / `PROG_CMDS` / `PROG_PAKETE` / `PROG_SONDER` (same index across all four; `PROG_SONDER` is `""` unless the program needs a bespoke install function like `chrome`/`brave`/`vscode`).

New catalog entries automatically get picked up by the selection-prompt and install-loop logic in both scripts — no separate wiring needed beyond the table/arrays and, if required, a bespoke install function referenced from the `case`/`switch` dispatch.

**Also update `update-windows.ps1`'s `$Programme` array** (Name + winget `ID` only, no `Pfade` needed there — see its architecture section below for why). It's a third copy of the same catalog kept in lockstep by hand, same as the Windows/Linux pair above; nothing wires it automatically.

`README.md` has a full catalog of ready-to-paste example prompts (add/remove programs, update Python versions, add logging, add `--dry-run`, add an uninstall script, adjust language, etc.) under "Updating with Claude Code" — check there before designing a new feature from scratch, since the maintainer already has a preferred approach for several common requests.

## Architecture — `setup-windows.ps1`

A separate flow from the freeware installers, built the same way (status check → selection → single confirmation → execution → report), but for a different job: turning a fresh Windows install into one that can clone/use this repo. Folder relocation is a separate script, see below.

1. **System info** — hostname/OS/RAM/CPU.
2. **Bootstrap status check** — winget, Git, GitHub CLI (`gh`), the install-assistant repo itself, and Claude Code CLI, each checked via `Get-Command` (plus path/winget-list fallbacks, matching the freeware script's convention). The repo item's check is special: it's considered "present" either if the script is already running from inside the full repo (a sibling `install-windows.ps1` exists next to it) or if an `install-assistant` folder already sits next to the script — so it never re-offers a clone once one exists.
3. **Bootstrap selection** — identical numbered-choice UX as the freeware script's program selection (comma list / `all` / `none`), scoped to whichever of the five are missing.
4. **Overview + single confirmation** — same pattern as the freeware script: show everything planned, one Y/N gate before anything executes.
5. **Execution** — runs in a fixed dependency order (winget → Git → GitHub CLI → repo clone → Claude), not selection order, since each step depends on the previous one being available (Git/GitHub CLI/Claude all install via winget; the repo clone needs `gh` on PATH and shells out to `gh auth login` interactively before `gh repo clone` if not already authenticated); `$env:Path` is refreshed from the registry after each install attempt since a new process/App Execution Alias registration won't otherwise be visible in the running session.
6. **Final report** — success/failure list across bootstrap items.

Notable implementation choices, in case they need revisiting:
- **winget bootstrap** tries `Add-AppxPackage -RegisterByFamilyName` first (fixes the common "present but not registered" case), then falls back to downloading the latest `.msixbundle` from the `microsoft/winget-cli` GitHub releases. It does *not* try to pin/install the `Microsoft.VCLibs`/`Microsoft.UI.Xaml` framework dependencies — if those are missing, `Add-AppxPackage` fails with a dependency error and the script surfaces that + a link to `https://aka.ms/getwinget`, rather than guessing a pinned dependency version that could go stale.
- **GitHub CLI, Claude Code CLI, and Git** all install via winget (`GitHub.cli`, `Anthropic.ClaudeCode`, `Git.Git` — all official, publisher-verified packages) through the same generic `Winget-Installiere`/`$OkCodes` path, rather than each having its own bespoke installer (e.g. `irm https://claude.ai/install.ps1 | iex` for Claude, or a manual `git clone` for the repo) — kept consistent with the script's "check winget first, install via winget" flow.
- **Repo clone** (`Hole-Repo` function) installs `gh`, runs `gh auth login` (interactive; opens a browser/device-code flow, cannot be made silent) if not already authenticated, then resolves the owner dynamically via `gh api user --jq ".login"` before `gh repo clone <owner>/install-assistant` — the owner is intentionally **not** hardcoded in the script, so the maintainer's GitHub username isn't baked into automation code. (The repo itself is public now, so this deliberately doesn't rely on that: it works the same regardless of visibility, and still requires an authenticated `gh` since it needs the login to determine the owner.) Clone target is always `<script-folder>\install-assistant`, mirroring what a human manually following `bootstrap/CLAUDE.md`'s `git clone` instruction would produce — so the automated path and the Claude-driven bootstrap fallback land in the same place. Note `bootstrap/CLAUDE.md` itself still has to hardcode the full clone URL (owner included), since at that point in the flow nothing is authenticated yet and Claude needs a literal URL to run `git clone` against.
- The script does **not** hard-require Administrator — Appx registration and `HKCU` registry edits are per-user, and winget/its installers prompt for elevation themselves when a specific package needs it.

## Architecture — `update-windows.ps1`

A separate flow, standalone (no dependency on the bootstrap having run), for a different job than either freeware installer or bootstrap: keeping the already-installed catalog programs from `install-windows.ps1` current via `winget upgrade`. It deliberately does **not** run `winget upgrade --all` — that would touch every winget-tracked package on the machine, not just this repo's catalog.

1. **Catalog loop** — for each catalog entry, `winget upgrade --id <ID> --exact --silent ...` is called unconditionally (no separate installed-check via `Pfade`/`Pruefe-Winget` first, unlike the install scripts) — winget's own exit code distinguishes the three outcomes cleanly, so a separate pre-check would be redundant:
   - `0` → upgraded.
   - `-1978335189` (already in `$OkCodes`, same code winget also returns for "already installed" during a plain install) → no update was available, already current.
   - `-1978335106` / `3010` (also already in `$OkCodes`) → upgraded, reboot required.
   - `-1978335212` (`$NichtInstalliertCode`) → not installed, skipped (not treated as a failure).
   - anything else → genuine failure, reported with the raw winget output (same pattern as `Winget-Installiere` in the other scripts).
2. **Report** — four buckets (`$Aktualisiert` / `$BereitsAktuell` / `$Uebersprungen` / `$Fehler`, all still-German variable names per the identifier convention above), not the two used elsewhere, since "already current" and "not installed" are both non-failures but mean different things to the person reading the report.
3. **Weekly self-registration** — after a manual run, if no Scheduled Task named `"install-assistant - Weekly Program Update"` exists yet, it asks once (Y/N) whether to register one; `-Register` does the same non-interactively, `-Unregister` unregisters it. The registered task calls the same script file (`$PSCommandPath`) with `-Silent`, which suppresses the `Read-Host` calls (final pause + the registration question itself) so the unattended run never blocks on missing input. Unlike the internal function/variable names, these parameter names are part of the script's CLI interface (something a user actually types), so they were translated to English along with the rest of the visible surface.
4. **`-RunLevel Highest`** on the scheduled task's principal — several catalog installers (e.g. Git) install at machine scope and need elevation; without `Highest`, a silent unattended upgrade for those would fail outright since there's no user to click a UAC prompt. This does mean `-Register` (and the interactive registration question) needs an elevated PowerShell session to succeed — `Registriere-Aufgabe` catches the resulting `Register-ScheduledTask` failure and tells the user to re-run as Administrator rather than surfacing a raw exception.

## Architecture — `move-user-folders-windows.ps1`

A separate flow from the bootstrap script, standalone (no dependency on the bootstrap having run), for relocating Pictures/Downloads/Documents to another drive. Built the same way (status/plan → single confirmation → execution → report).

1. **Drive overview** — all drive letters with free/total space (`Get-Volume`) — direct context for the target-drive decision that follows, not just cosmetic.
2. **Folder-move planning** — always asked (Y/N). If yes: prompts for a target base folder, resolves the *current* path of each known folder dynamically via `shell:Personal` / `shell:My Pictures` / `shell:Downloads` (COM `Shell.Application`, not hardcoded paths — this is locale-proof, since Documents/Pictures are localized on non-English Windows but Downloads never is), computes folder sizes, checks free space on the target drive (with a 10% margin) before adding anything to the plan, and flags any folder currently living under a path containing `OneDrive` — moving a OneDrive-managed folder via registry edit can fight with OneDrive's own Known Folder Move feature, so the script warns and asks per-folder before proceeding. Note that `ShellName`/`RegName` values (`"My Pictures"`, `"Personal"`, `"Downloads"`) are fixed Windows API identifiers, not translatable UI text — only the `Label` values (shown to the user) are in English.
3. **Overview + single confirmation** — show everything planned (old→new paths and total size), one Y/N gate before anything executes.
4. **Execution** — `robocopy <old> <new> /E /MOVE` (exit codes 0–7 are success, matching robocopy's own convention — not "0 means success"), then updates both `HKCU:\...\Explorer\User Shell Folders` and the legacy `HKCU:\...\Explorer\Shell Folders` keys, then restarts `explorer.exe` once at the end if at least one move succeeded.
5. **Final report** — success/failure list across folder moves.

## Other repo contents

`.github/agents/*.agent.md` are GitHub Copilot custom-agent definitions (Debian expert, DevOps expert, doc generator, etc.) unrelated to Claude Code's own behavior — they don't apply to this session and don't need to be kept in sync with anything here.
