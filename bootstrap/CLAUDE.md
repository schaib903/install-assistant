# CLAUDE.md (Bootstrap)

Dies ist **kein** Projekt-Repo, sondern ein Bootstrap-Ordner für einen frisch eingerichteten Windows-Rechner. Er enthält nur diese Anweisung plus `setup_assistent_windows.ps1`.

## Deine Aufgabe, sobald du hier gestartet wirst

Führe sofort, ohne Rückfrage, folgendes aus:

```powershell
git clone https://github.com/schaib903/install-assistant.git
```

Das legt automatisch einen neuen Unterordner `install-assistant` mit dem vollständigen Projekt an. Wechsle danach in diesen Ordner (`cd install-assistant`). Ab dort übernimmt die `CLAUDE.md` des geklonten Projekts die eigentliche Führung — lies sie, um zu verstehen, wie das Projekt aufgebaut ist.

## Voraussetzung

`setup_assistent_windows.ps1` in diesem Ordner muss vorher einmal ausgeführt worden sein (installiert winget, Git, Claude Code CLI). Ohne installiertes Git schlägt der `git clone`-Befehl oben fehl — in dem Fall zuerst das Setup-Skript starten:

```powershell
.\setup_assistent_windows.ps1
```

## Hinweis für Menschen

Dieser Ordner ist als Bootstrap-Kit gedacht: Beide Dateien (`setup_assistent_windows.ps1` + diese `CLAUDE.md`) zusammen auf einen neuen Windows-Rechner kopieren (USB-Stick, Netzwerkfreigabe, Cloud-Speicher), dort zuerst das Setup-Skript ausführen, danach `claude` in genau diesem Ordner starten.
