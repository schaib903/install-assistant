# CLAUDE.md (Bootstrap)

This is **not** a project repo, but a bootstrap folder for a freshly set up Windows machine. It contains only this instruction plus `00_setup-windows.ps1`.

## Your task as soon as you're started here

Immediately, without asking, run the following:

```powershell
git clone https://github.com/schaib903/install-assistant.git
```

This automatically creates a new subfolder `install-assistant` containing the full project. Then switch into that folder (`cd install-assistant`). From there, the `CLAUDE.md` of the cloned project takes over — read it to understand how the project is structured.

## Prerequisite

`00_setup-windows.ps1` in this folder must have been run once beforehand (it installs winget, Git, GitHub CLI, and Claude Code CLI, and can clone this repo itself). Without Git installed, the `git clone` command above will fail — in that case, run the setup script first:

```powershell
.\00_setup-windows.ps1
```

## Note for humans

This folder is meant as a bootstrap kit: copy both files (`00_setup-windows.ps1` + this `CLAUDE.md`) together onto a new Windows machine (USB drive, network share, cloud storage), run the setup script there first, then start `claude` in this exact folder.
