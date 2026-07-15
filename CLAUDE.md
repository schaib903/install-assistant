# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Standalone, dependency-free installer/setup scripts, each a single self-contained file with no shared library, build system, package manifest, or test suite:

| File | Platform | Purpose |
|---|---|---|
| `install_assist_windows.ps1` | Windows 10/11 | Detects & installs a fixed catalog of freeware via winget |
| `install_assist_linux.sh` | Debian / Ubuntu / Mint / Pop!_OS | Same catalog via apt |
| `setup_assistent_windows.ps1` | Windows 10/11 | New-machine bootstrap: winget/Git/Claude Code CLI |
| `verschiebe_benutzerordner_windows.ps1` | Windows 10/11 | Standalone: moves Pictures/Downloads/Documents to another drive |
| `bootstrap/` | Windows 10/11 | Standalone kit for a fresh machine: a copy of `setup_assistent_windows.ps1` + a bootstrap `CLAUDE.md` that clones this repo |

`instructions_freeware_installation_assist.md` is the original German spec the two `install_assist_*` scripts were generated from; treat it as the source of truth for their intended behavior if the scripts and docs ever disagree. `setup_assistent_windows.ps1` and `verschiebe_benutzerordner_windows.ps1` are a separate concern (initial machine setup / data relocation, not freeware installation) and have no corresponding spec file — their behavior is defined by the scripts themselves and by `README.md`.

This repo lives at `https://github.com/schaib903/install-assistant` (private).

### The `bootstrap/` folder is a special case — read before touching it

`bootstrap/CLAUDE.md` is **not** this file. It's a separate, minimal `CLAUDE.md` meant to be copied (together with `bootstrap/setup_assistent_windows.ps1`) onto a brand-new Windows machine that has neither Git nor this repo yet. When a user starts `claude` inside that bootstrap folder, Claude Code reads *that* file instead of this one, and its only job is to `git clone` this repo. Do not merge the two files or delete `bootstrap/CLAUDE.md` thinking it's a duplicate — it is intentionally separate because a directory can only have one auto-loaded `CLAUDE.md`, and this repo's root and the bootstrap kit are different directories with different jobs.

`bootstrap/setup_assistent_windows.ps1` is a **plain copy** of the root script, not a symlink or generated artifact (there's no build step in this repo to regenerate it). When you change `setup_assistent_windows.ps1` at the repo root, copy the change into `bootstrap/setup_assistent_windows.ps1` too, or the bootstrap kit silently goes stale.

## Running / testing changes

There is no automated test harness. Verify changes by executing the script directly:

```powershell
.\install_assist_windows.ps1
```

```bash
chmod +x install_assist_linux.sh
./install_assist_linux.sh
```

If a `.sh` file was edited or created on Windows, it will have CRLF line endings and fail on Linux with `bad interpreter`. Convert before testing/committing:
```bash
sed -i 's/\r//' install_assist_linux.sh
```

Both scripts are interactive (they prompt with `J/N` and a Python-version number choice) and mutate real system state (they install software via winget/apt), so a dry run or careful narration of what would happen is preferable to blindly executing them in an agent context. If a `--dry-run` flag has been added (see prompt catalog below), prefer testing with that.

`verschiebe_benutzerordner_windows.ps1` is higher-stakes to test than the other scripts: it moves real user data (Pictures/Downloads/Documents) via `robocopy /MOVE`, which deletes the source after copying. Always verify changes with declined answers first (`N` at every prompt) before ever answering `J` to the folder-move question on a real machine — a syntax check (`[System.Management.Automation.Language.Parser]::ParseFile(...)`) plus a declined-answers dry run is the safe verification loop; there is no safe way to test the actual move without touching real files.

## Architecture — both scripts share one linear flow

Both scripts implement the identical pipeline described in `instructions_freeware_installation_assist.md`, just in PowerShell vs. Bash idiom. When adding a program or feature, **mirror the change in both files** — they are meant to stay behaviorally identical (Windows uses winget IDs, Linux uses apt package names).

1. **Platform guard** — abort with an error if run on the wrong OS or if the required package manager (`winget` / `apt-get`) is missing.
2. **Header + system info** — hostname, OS, RAM, CPU.
3. **Program table** — a flat list of `{Name, ID/package, detection paths/command}` checked in order. This is the primary place to add/remove software.
4. **Installed check** — each program is checked by binary/file-path presence first, then by package-manager query as a fallback (`Pruefe-Winget` in PS, `ist_installiert`/`paket_installiert` in Bash).
5. **Program selection** — the *missing* programs are shown as a numbered list and the user picks which ones to install (comma-separated numbers, `alle`/`a`, or `keine`/empty to select none). This is **not** "install everything missing" — the user opts in per item. Selection state lives in `$AusgewaehlteProgramme` (PS) / `AUSGEWAEHLT_NAMEN`+`AUSGEWAEHLT_PAKETE`+`AUSGEWAEHLT_SONDER` (Bash), built by filtering the missing-items list/arrays by chosen index.
6. **Python version matrix** — a separate parallel array (`$PythonVersionen` / `PYTHON_VERSIONEN`) of supported versions, checked independently, with the user prompted to pick one missing version to install (or skip). Reuses the same numbered-choice pattern as step 5, but single-select since only one Python version installs per run.
7. **Additional freeware prompt** — always asked (even if the whole catalog is already installed or nothing was selected in step 5), regardless of catalog status: "install something not on the list?" On yes, loops collecting free-text `Name` + `winget-ID` (PS) / `apt-Paketname` (Bash) pairs until the user submits an empty name. These go through the generic install path only — no bespoke function, since the ID/package is arbitrary user input.
8. **Installation overview + single J/N confirmation** — summarizes the selected catalog programs + chosen Python version + custom entries together; nothing installs until this one combined confirmation. If literally nothing was selected/entered, the script reports that and exits before this prompt.
9. **Installation loop** — most programs install via a generic package-manager call; a few have bespoke functions for non-trivial installs (`installiere_chrome`, `installiere_brave`, `installiere_vscode`, `installiere_python` in Bash; the Windows script has no bespoke install functions at all — winget handles every catalog entry, including Brave and Adobe Reader, via the same generic `Winget-Installiere`). Custom/additional entries from step 7 always use the generic path.
10. **Final report** — lists what succeeded/failed (catalog + Python + custom, uniformly), with a hint (check permissions/internet) if anything failed.

### Conventions to preserve when editing

- **All user-facing strings are German**, hardcoded inline (not externalized to a resource file) — this is intentional per the project docs, to keep the scripts simple and directly editable/translatable in place.
- **Colors/formatting are declared once at the top** — PowerShell uses `-ForegroundColor` params inline; Bash defines ANSI color variables (`ROT`, `GRUEN`, `GELB`, `CYAN`, `WEISS`, `GRAU`, `RESET`) at the top of the file.
- **Special-case programs get their own function** rather than being folded into the generic install loop — follow this pattern (e.g. `installiere_chrome`, `installiere_brave`) rather than adding conditionals to the main loop when a program needs a non-standard install path (custom repo/key, download-and-`dpkg -i`, etc). The Windows side needs this far less often, since winget's package IDs cover most of the catalog generically.
- Windows install status is double-checked: a known install-path (`Pfade`) check, then a `winget list` check — keep both, since some installs (e.g. portable/manual) won't register with winget.
- PowerShell winget exit codes are treated leniently: `$OkCodes = @(0, -1978335189, -1978335106, 3010)` covers "already installed"/"reboot required" cases as success — extend this list rather than treating any non-zero exit as failure.
- **Platform-only catalog entries are allowed and expected** — not every program needs to exist on both sides. Notepad++ is Windows-only; Adobe Acrobat Reader is Windows-only too (Adobe dropped official Linux support years ago) — when a program genuinely has no equivalent on one platform, just omit it from that script's arrays rather than forcing a workaround.

## Adding or removing a program

Update both scripts' program tables in lockstep (unless the program is genuinely platform-only, see above):
- Windows: add an entry to the `$Programme` array (`Name`, winget `ID`, candidate `Pfade`).
- Linux: add to the four parallel arrays `PROG_NAMEN` / `PROG_CMDS` / `PROG_PAKETE` / `PROG_SONDER` (same index across all four; `PROG_SONDER` is `""` unless the program needs a bespoke install function like `chrome`/`brave`/`vscode`).

New catalog entries automatically get picked up by the selection-prompt and install-loop logic in both scripts — no separate wiring needed beyond the table/arrays and, if required, a bespoke install function referenced from the `case`/`switch` dispatch.

`README.md` has a full catalog of ready-to-paste example prompts (add/remove programs, update Python versions, add logging, add `--dry-run`, add an uninstall script, translate to English, etc.) under "Mit Claude Code aktualisieren" — check there before designing a new feature from scratch, since the maintainer already has a preferred approach for several common requests.

## Architecture — `setup_assistent_windows.ps1`

A separate flow from the freeware installers, built the same way (status check → selection → single confirmation → execution → report), but for a different job: turning a fresh Windows install into one that can clone/use this repo. Folder relocation is a separate script, see below.

1. **System info** — hostname/OS/RAM/CPU.
2. **Grundsetup status check** — winget, Git, Claude Code CLI, each checked via `Get-Command` (plus path/winget-list fallbacks for Git, matching the freeware script's convention).
3. **Grundsetup selection** — identical numbered-choice UX as the freeware script's program selection (comma list / `alle` / `keine`), scoped to whichever of the three are missing.
4. **Overview + single confirmation** — same pattern as the freeware script: show everything planned, one J/N gate before anything executes.
5. **Execution** — runs in a fixed dependency order (winget → Git → Claude), not selection order, because Git installs via `winget install Git.Git` and Claude's native installer needs network access; `$env:Path` is refreshed from the registry after each install attempt since a new process/App Execution Alias registration won't otherwise be visible in the running session.
6. **Final report** — success/failure list across Grundsetup items.

Notable implementation choices, in case they need revisiting:
- **winget bootstrap** tries `Add-AppxPackage -RegisterByFamilyName` first (fixes the common "present but not registered" case), then falls back to downloading the latest `.msixbundle` from the `microsoft/winget-cli` GitHub releases. It does *not* try to pin/install the `Microsoft.VCLibs`/`Microsoft.UI.Xaml` framework dependencies — if those are missing, `Add-AppxPackage` fails with a dependency error and the script surfaces that + a link to `https://aka.ms/getwinget`, rather than guessing a pinned dependency version that could go stale.
- **Claude Code CLI** installs via the officially documented native installer (`irm https://claude.ai/install.ps1 | iex`) — the exact command is echoed to the console before running it, since it fetches and executes a remote script.
- The script does **not** hard-require Administrator — Appx registration and `HKCU` registry edits are per-user, and winget/its installers prompt for elevation themselves when a specific package needs it.

## Architecture — `verschiebe_benutzerordner_windows.ps1`

A separate flow from the Grundsetup script, standalone (no dependency on Grundsetup having run), for relocating Pictures/Downloads/Documents to another drive. Built the same way (status/plan → single confirmation → execution → report).

1. **Drive overview** — all drive letters with free/total space (`Get-Volume`) — direct context for the target-drive decision that follows, not just cosmetic.
2. **Folder-move planning** — always asked (Y/N). If yes: prompts for a target base folder, resolves the *current* path of each known folder dynamically via `shell:Personal` / `shell:My Pictures` / `shell:Downloads` (COM `Shell.Application`, not hardcoded paths — this is locale-proof, since Documents/Pictures are localized on non-English Windows but Downloads never is), computes folder sizes, checks free space on the target drive (with a 10% margin) before adding anything to the plan, and flags any folder currently living under a path containing `OneDrive` — moving a OneDrive-managed folder via registry edit can fight with OneDrive's own Known Folder Move feature, so the script warns and asks per-folder before proceeding.
3. **Overview + single confirmation** — show everything planned (old→new paths and total size), one J/N gate before anything executes.
4. **Execution** — `robocopy <old> <new> /E /MOVE` (exit codes 0–7 are success, matching robocopy's own convention — not "0 means success"), then updates both `HKCU:\...\Explorer\User Shell Folders` and the legacy `HKCU:\...\Explorer\Shell Folders` keys, then restarts `explorer.exe` once at the end if at least one move succeeded.
5. **Final report** — success/failure list across folder moves.

## Other repo contents

`.github/agents/*.agent.md` are GitHub Copilot custom-agent definitions (Debian expert, DevOps expert, doc generator, etc.) unrelated to Claude Code's own behavior — they don't apply to this session and don't need to be kept in sync with anything here.
