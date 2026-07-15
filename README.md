# Freeware Install Assistant

Cross-platform install assistant for common freeware.
Automatically detects the operating system and installs missing programs via the respective package manager.

Repo: [github.com/schaib903/install-assistant](https://github.com/schaib903/install-assistant) (public)

---

## Files

| File | Platform | Package manager |
|---|---|---|
| `install-windows.ps1` | Windows 10/11 | winget |
| `install-linux.sh` | Debian / Ubuntu / Mint | apt |
| `setup-windows.ps1` | Windows 10/11 | winget |
| `update-windows.ps1` | Windows 10/11 | winget |
| `move-user-folders-windows.ps1` | Windows 10/11 | – |

---

## Setup Assistant (Windows Bootstrap)

`setup-windows.ps1` is a standalone script for bootstrapping a new Windows machine – independent of the freeware installer. It checks and, if needed, installs the **bootstrap set**:
- **winget** (Windows Package Manager) – automatically registered or downloaded from GitHub if missing
- **Git** (via winget)
- **GitHub CLI** (`gh`, via winget) – needed for signing in to GitHub and cloning the repo
- **install-assistant repo** – signs in to GitHub via `gh auth login` (if not already signed in), determines the owner dynamically (`gh api user`), and clones this repo via `gh repo clone` into a subfolder next to the script
- **Claude Code CLI** (via winget)

These components enable access to/download of repositories. As with the freeware installer, it first checks what's already installed – only the missing components are offered for selection (individually, "all", or "none").

Usage:
```powershell
.\setup-windows.ps1
```

> **Note:** If PowerShell refuses to run with an execution policy error, see [Execution Policy](#prerequisites) under Prerequisites.

## Updating Programs

`update-windows.ps1` keeps only the **catalog programs** from `install-windows.ps1` up to date (via `winget upgrade`) – not every winget package on the machine. Programs that aren't installed are skipped; winget itself decides whether an update is needed (already-current programs are reported as "already up to date", not an error).

Usage:
```powershell
.\update-windows.ps1
```

At the end of a manual run, the script asks (if not already set up) whether it should run automatically **every week** (every Monday, 9:00 AM) via the Windows Task Scheduler. Alternatively, use the parameters directly:

```powershell
.\update-windows.ps1 -Register     # sets up the weekly task without asking
.\update-windows.ps1 -Unregister   # removes the scheduled task again
.\update-windows.ps1 -Silent       # unattended run without prompts (used by the scheduled task)
```

> **Note:** For reliable unattended updates of programs that require elevation, the scheduled task runs with the highest privileges. Setting up the task (`-Register` or the prompt at the end) therefore only works reliably if PowerShell was started as Administrator for that step.

> **Note:** If PowerShell refuses to run with an execution policy error, see [Execution Policy](#prerequisites) under Prerequisites.

## Moving User Folders

`move-user-folders-windows.ps1` is a standalone script for moving Pictures, Downloads, and Documents to another partition – separate from the bootstrap set, since it touches real user data and can be needed/run independently of it. It first shows the available drives with free space, checks whether there's enough space at the target, and warns if a folder is currently backed up via OneDrive (which could otherwise conflict with its synchronization).

Usage:
```powershell
.\move-user-folders-windows.ps1
```

> **Important:** Moving user folders touches real user data. Before the actual move, the script shows the full plan (old path → new path, required disk space) and requires explicit confirmation.

> **Note:** If PowerShell refuses to run with an execution policy error, see [Execution Policy](#prerequisites) under Prerequisites.

---

## Bootstrap Kit for a New Machine

A fresh Windows install doesn't have Git yet, so the repo can't be cloned there. For exactly this case there's the `bootstrap/` folder with two files that travel together to the new machine (USB drive, network share, cloud storage):

| File | Purpose |
|---|---|
| `bootstrap/setup-windows.ps1` | Runs the bootstrap set (winget, Git, GitHub CLI, repo clone, Claude Code CLI) |
| `bootstrap/CLAUDE.md` | Automatically read when `claude` is started in this folder, and instructs Claude Code to fetch this repo via `git clone` |

**Flow on the new machine:**
1. Copy both files from `bootstrap/` into an empty folder
2. Run `.\setup-windows.ps1` (installs winget, Git, GitHub CLI, Claude Code CLI, and clones this repo, among other things) – on a fresh Windows install the PowerShell execution policy is usually not yet unlocked, see [Execution Policy](#prerequisites) under Prerequisites
3. Start `claude` in the same folder – it automatically reads the `CLAUDE.md` there and clones this repo into a new subfolder (unless step 2 already cloned it)

> **Maintenance note:** `bootstrap/setup-windows.ps1` is a plain copy of the file in the root directory (no symlink, no build step). When you change the main script, update the copy in the `bootstrap/` folder too.

---

## Included Programs

| Program | Windows | Linux |
|---|---|---|
| Firefox | ✅ | ✅ |
| Google Chrome | ✅ | ✅ |
| Brave Browser | ✅ | ✅ (own apt repo) |
| Notepad++ | ✅ | ❌ (Windows only) |
| VLC | ✅ | ✅ |
| 7-Zip | ✅ | ✅ (p7zip-full) |
| Adobe Acrobat Reader | ✅ | ❌ (no official Linux reader anymore) |
| VS Code | ✅ | ✅ (Microsoft repo) |
| Git | ✅ | ✅ |
| Python 3.10–3.13 | ✅ | ✅ (deadsnakes PPA) |

---

## Prerequisites

### Windows

- **Windows 10 (1709+) or Windows 11**
- **PowerShell 5.1 or newer** — preinstalled by default
- **winget (Windows Package Manager)** — preinstalled from Windows 11 onward;
  for Windows 10, install manually:
  → [https://aka.ms/getwinget](https://aka.ms/getwinget)
  Or via the Microsoft Store: update *App Installer*
- **Execution Policy** — unlock once if needed:
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

### Linux

- **Debian, Ubuntu, Linux Mint, or Pop!_OS** (or a compatible derivative)
- **bash** — present by default
- **apt / apt-get** — present by default
- **sudo** — the user must have sudo privileges
- **wget or curl** — for the Chrome download (usually present)
- **gpg** — for the VS Code repository (usually present)

---

## Usage

### Windows

Open a terminal (PowerShell) as a normal user and run:

```powershell
.\install-windows.ps1
```

> **Tip:** For system-wide installations, start the terminal as Administrator.

### Linux

Make the script executable and run it:

```bash
chmod +x install-linux.sh
./install-linux.sh
```

> **Important (transfer from Windows):** If the file was created on Windows and
> transferred to Linux via USB/FTP, the line endings need to be converted:
> ```bash
> sed -i 's/\r//' install-linux.sh
> # or alternatively:
> dos2unix install-linux.sh
> ```

---

## Flow

```
1. Platform and package manager are detected
2. System information is shown (hostname, OS, RAM, CPU)
3. Each program is checked for installation  →  ✅ / ❌
4. Selection: which of the missing programs should be installed?
   (individual numbers, "all", or "none")
5. Python version overview  →  select the desired version (or none)
6. Prompt: install additional freeware that isn't on the
   list? (name + winget ID or apt package name)
7. Summary of all selected programs  →  single confirmation (Y/N)
8. All selected programs are installed
9. Final report: what was installed, what failed
```

---

## Updating with Claude Code

The scripts are structured so that Claude Code can easily read,
understand, and extend them in a targeted way.

### Prerequisite

[Claude Code](https://claude.ai/code) installed and started in the project folder:

```bash
cd /path/to/folder
claude
```

### Recommended Prompts for Updates

#### Adding programs

```
Add the program "Thunderbird" to both scripts.
Windows: winget ID Mozilla.Thunderbird, path: C:\Program Files\Mozilla Thunderbird\thunderbird.exe
Linux: apt package thunderbird, command thunderbird
```

```
Add the following programs to the program list in both scripts:
- LibreOffice (winget: TheDocumentFoundation.LibreOffice / apt: libreoffice)
- GIMP (winget: GIMP.GIMP / apt: gimp)
- KeePassXC (winget: KeePassXCTeam.KeePassXC / apt: keepassxc)
Check installation status for each and install if needed.
```

#### Removing programs

```
Remove Google Chrome from both scripts. The user only wants Firefox offered.
```

#### Updating Python versions

```
Update the Python version list in both scripts.
Remove Python 3.10 (end of life) and add Python 3.14.
winget ID: Python.Python.3.14
apt package: python3.14 (via deadsnakes PPA)
```

#### New feature: program updates

```
Add an optional update feature to both scripts after installation.
Windows: winget upgrade --all --silent
Linux: sudo apt-get upgrade -y
The user should be asked beforehand whether to run updates (Y/N).
```

#### New feature: uninstall

```
Based on install-windows.ps1, create a new script
uninstall-windows.ps1 that can uninstall all listed programs.
The user should be able to individually select which programs to remove.
winget command: winget uninstall --id <ID> --silent
```

#### Adjust language

```
Create a German version of both scripts. All output, prompts, and
messages should be in German. Filenames: install-windows-de.ps1
and install-linux-de.sh. Content and logic stay identical.
```

#### Add logging

```
Add a logging feature to both scripts.
After installation, a log file should be created:
- Windows: install_log_<date>.txt in the same folder
- Linux:   install_log_<date>.txt in the same folder
Content: date/time, hostname, OS, what was installed, what failed.
```

#### Look up a winget ID

```
Look up the correct winget ID for the program "Obsidian" and add it
to the program list in install-windows.ps1.
Also check whether an apt package exists for Ubuntu and add it to install-linux.sh.
```

#### Improve error handling

```
Improve error handling in install-windows.ps1:
if winget fails for a package, automatically start a second
attempt without the --silent flag, so the user can operate the
installer window manually.
```

#### Test the script (dry run)

```
Add a --dry-run parameter to both scripts.
When the script is started with the parameter (e.g. .\install-windows.ps1 --dry-run),
only the installation status should be shown, without installing anything.
```

---

## Structure Notes (for Claude Code)

The scripts are deliberately structured linearly so that changes are easy to make:

- **Programs** are defined as an array/list at the start of the script → easy to add/remove
- **Special cases** (Chrome, Brave, VS Code, Python) have their own functions → easy to swap out
- **All visible output** (messages, prompts, comments) is in English and directly in the code → easy to translate. Internal function/variable names (e.g. `Pruefe-Winget`, `$Fehler`, Bash's `ROT`/`GRUEN`) are intentionally still German — a historical carryover from the original scripts, left as-is when the output was translated to keep the diff small. Don't "fix" this without being asked; it's not an oversight.
- **Colors** are defined as variables at the top (Bash) or passed as parameters (PowerShell)
- **Selection instead of all-or-nothing**: the user specifically chooses which of the
  missing programs to install (numbered selection, "all", or
  "none") – matching the existing Python version selection
- **Additional freeware**: at the end, the user is asked whether to install further
  programs that aren't on the fixed list (free-form
  entry of name + winget ID or apt package name)
- Adobe Acrobat Reader is only included in the Windows script, since Adobe no longer
  offers an official reader for Linux

---

## License

Free to use for personal and commercial purposes.
