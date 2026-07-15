# Freeware Installationsassistent

Plattformübergreifender Installationsassistent für gängige Freeware.  
Erkennt automatisch das Betriebssystem und installiert fehlende Programme über den jeweiligen Paketmanager.

Repo: [github.com/schaib903/install-assistant](https://github.com/schaib903/install-assistant) (öffentlich)

---

## Dateien

| Datei | Plattform | Paketmanager |
|---|---|---|
| `install_assist_windows.ps1` | Windows 10/11 | winget |
| `install_assist_linux.sh` | Debian / Ubuntu / Mint | apt |
| `setup_assistent_windows.ps1` | Windows 10/11 | winget |
| `verschiebe_benutzerordner_windows.ps1` | Windows 10/11 | – |

---

## Setup-Assistent (Windows Ersteinrichtung)

`setup_assistent_windows.ps1` ist ein eigenständiges Skript für die Ersteinrichtung eines neuen Windows-Rechners – unabhängig vom Freeware-Installer. Es prüft und installiert bei Bedarf das **Grundsetup**:
- **winget** (Windows Package Manager) – wird, falls nicht vorhanden, automatisch registriert bzw. von GitHub nachinstalliert
- **Git** (via winget)
- **GitHub CLI** (`gh`, via winget) – wird für die Anmeldung bei GitHub und das Klonen des Repos benötigt
- **install-assistant Repo** – meldet sich per `gh auth login` bei GitHub an (falls noch nicht angemeldet), ermittelt den Besitzernamen dynamisch (`gh api user`) und klont dieses Repo per `gh repo clone` in einen Unterordner neben dem Skript
- **Claude Code CLI** (via winget)

Diese Komponenten ermöglichen den Zugriff auf/Download von Repositories. Wie beim Freeware-Installer wird zuerst geprüft, was bereits installiert ist – nur die fehlenden Komponenten werden zur Auswahl angeboten (einzeln, "alle" oder "keine").

Verwendung:
```powershell
.\setup_assistent_windows.ps1
```

> **Hinweis:** Falls PowerShell die Ausführung mit einem Fehler zur Ausführungsrichtlinie verweigert, siehe [Ausführungsrichtlinie](#voraussetzungen) unter Voraussetzungen.

## Benutzerordner verschieben

`verschiebe_benutzerordner_windows.ps1` ist ein eigenständiges Skript, um Bilder, Downloads und Dokumente auf eine andere Partition zu verschieben – getrennt vom Grundsetup, da es ein Eingriff in echte Nutzerdaten ist und unabhängig davon benötigt/ausgeführt werden kann. Es zeigt vorher die verfügbaren Laufwerke mit freiem Speicherplatz, prüft ob am Zielort genug Platz vorhanden ist, und warnt, falls ein Ordner aktuell über OneDrive gesichert wird (das kann sonst mit der Synchronisierung kollidieren).

Verwendung:
```powershell
.\verschiebe_benutzerordner_windows.ps1
```

> **Wichtig:** Das Verschieben der Benutzerordner ist ein Eingriff in echte Nutzerdaten. Vor dem eigentlichen Verschieben zeigt das Skript den vollständigen Plan (alter Pfad → neuer Pfad, benötigter Speicherplatz) und verlangt eine explizite Bestätigung.

> **Hinweis:** Falls PowerShell die Ausführung mit einem Fehler zur Ausführungsrichtlinie verweigert, siehe [Ausführungsrichtlinie](#voraussetzungen) unter Voraussetzungen.

---

## Bootstrap-Kit für einen neuen Rechner

Auf einem frischen Windows ist noch kein Git installiert, daher kann man das Repo dort noch nicht klonen. Für genau diesen Fall gibt es den Ordner `bootstrap/` mit zwei Dateien, die zusammen auf den neuen Rechner mitgenommen werden (USB-Stick, Netzwerkfreigabe, Cloud-Speicher):

| Datei | Zweck |
|---|---|
| `bootstrap/setup_assistent_windows.ps1` | Grundsetup ausführen (winget, Git, GitHub CLI, Repo-Klon, Claude Code CLI) |
| `bootstrap/CLAUDE.md` | Wird automatisch gelesen, wenn `claude` in diesem Ordner gestartet wird, und weist Claude Code an, dieses Repo per `git clone` zu holen |

**Ablauf auf dem neuen Rechner:**
1. Beide Dateien aus `bootstrap/` in einen leeren Ordner kopieren
2. `.\setup_assistent_windows.ps1` ausführen (installiert u.a. winget, Git, GitHub CLI, Claude Code CLI und klont dieses Repo) – auf einem frischen Windows ist die PowerShell-Ausführungsrichtlinie meist noch nicht freigeschaltet, siehe [Ausführungsrichtlinie](#voraussetzungen) unter Voraussetzungen
3. Im selben Ordner `claude` starten – liest automatisch die dortige `CLAUDE.md` und klont dieses Repo in einen neuen Unterordner (falls Schritt 2 das Repo noch nicht bereits geklont hat)

> **Wartungshinweis:** `bootstrap/setup_assistent_windows.ps1` ist eine einfache Kopie der Datei im Hauptverzeichnis (kein Symlink, kein Build-Schritt). Bei Änderungen am Hauptskript die Kopie im `bootstrap/`-Ordner mit aktualisieren.

---

## Enthaltene Programme

| Programm | Windows | Linux |
|---|---|---|
| Firefox | ✅ | ✅ |
| Google Chrome | ✅ | ✅ |
| Brave Browser | ✅ | ✅ (eigenes apt-Repo) |
| Notepad++ | ✅ | ❌ (Windows only) |
| VLC | ✅ | ✅ |
| 7-Zip | ✅ | ✅ (p7zip-full) |
| Adobe Acrobat Reader | ✅ | ❌ (kein offizieller Linux-Reader mehr) |
| VS Code | ✅ | ✅ (Microsoft-Repo) |
| Git | ✅ | ✅ |
| Python 3.10–3.13 | ✅ | ✅ (deadsnakes PPA) |

---

## Voraussetzungen

### Windows

- **Windows 10 (1709+) oder Windows 11**
- **PowerShell 5.1 oder neuer** — ist standardmäßig vorinstalliert
- **winget (Windows Package Manager)** — ab Windows 11 vorinstalliert;  
  für Windows 10 manuell installieren:  
  → [https://aka.ms/getwinget](https://aka.ms/getwinget)  
  Oder über den Microsoft Store: *App Installer* aktualisieren
- **Ausführungsrichtlinie** — einmalig freischalten, falls nötig:
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

### Linux

- **Debian, Ubuntu, Linux Mint oder Pop!_OS** (oder kompatibles Derivat)
- **bash** — standardmäßig vorhanden
- **apt / apt-get** — standardmäßig vorhanden
- **sudo** — Benutzer muss sudo-Rechte haben
- **wget oder curl** — für den Chrome-Download (meist vorhanden)
- **gpg** — für das VS-Code-Repository (meist vorhanden)

---

## Verwendung

### Windows

Terminal (PowerShell) als normaler Benutzer öffnen und ausführen:

```powershell
.\install_assist_windows.ps1
```

> **Tipp:** Für systemweite Installationen Terminal als Administrator starten.

### Linux

Skript ausführbar machen und starten:

```bash
chmod +x install_assist_linux.sh
./install_assist_linux.sh
```

> **Wichtig (Transfer von Windows):** Falls die Datei unter Windows erstellt und  
> per USB/FTP auf Linux übertragen wurde, müssen die Zeilenenden konvertiert werden:
> ```bash
> sed -i 's/\r//' install_assist_linux.sh
> # oder alternativ:
> dos2unix install_assist_linux.sh
> ```

---

## Ablauf

```
1. Plattform und Paketmanager werden erkannt
2. Systeminformationen werden angezeigt (Hostname, OS, RAM, CPU)
3. Jedes Programm wird auf Installation geprüft  →  ✅ / ❌
4. Auswahl: welche der fehlenden Programme sollen installiert werden?
   (Nummern einzeln, "alle" oder "keine")
5. Python-Versionsübersicht  →  gewünschte Version auswählen (oder keine)
6. Abfrage: soll zusätzliche Freeware installiert werden, die nicht
   in der Liste steht? (Name + winget-ID bzw. apt-Paketname)
7. Zusammenfassung aller ausgewählten Programme  →  einmalige Bestätigung (J/N)
8. Alle ausgewählten Programme werden installiert
9. Abschlussbericht: was installiert wurde, was fehlgeschlagen ist
```

---

## Mit Claude Code aktualisieren

Die Skripte sind so strukturiert, dass Claude Code sie einfach lesen,  
verstehen und gezielt erweitern kann.

### Voraussetzung

[Claude Code](https://claude.ai/code) installiert und im Projektordner gestartet:

```bash
cd /pfad/zum/ordner
claude
```

### Empfohlene Prompts zur Aktualisierung

#### Programme hinzufügen

```
Füge das Programm "Thunderbird" zu beiden Skripten hinzu.
Windows: winget-ID Mozilla.Thunderbird, Pfad: C:\Program Files\Mozilla Thunderbird\thunderbird.exe
Linux: apt-Paket thunderbird, Befehl thunderbird
```

```
Füge folgende Programme zur Programmliste beider Skripte hinzu:
- LibreOffice (winget: TheDocumentFoundation.LibreOffice / apt: libreoffice)
- GIMP (winget: GIMP.GIMP / apt: gimp)
- KeePassXC (winget: KeePassXCTeam.KeePassXC / apt: keepassxc)
Prüfe jeweils auf Installationsstatus und installiere bei Bedarf.
```

#### Programme entfernen

```
Entferne Google Chrome aus beiden Skripten. Der Nutzer möchte nur Firefox anbieten.
```

#### Python-Versionen aktualisieren

```
Aktualisiere die Python-Versionsliste in beiden Skripten.
Entferne Python 3.10 (End-of-Life) und füge Python 3.14 hinzu.
winget-ID: Python.Python.3.14
apt-Paket: python3.14 (via deadsnakes PPA)
```

#### Neue Funktion: Programmaktualisierung

```
Füge in beiden Skripten nach der Installation eine optionale Update-Funktion hinzu.
Windows: winget upgrade --all --silent
Linux: sudo apt-get upgrade -y
Der Nutzer soll vorher gefragt werden ob Updates durchgeführt werden sollen (J/N).
```

#### Neue Funktion: Deinstallation

```
Erstelle auf Basis von install_assist_windows.ps1 ein neues Skript
uninstall_assist_windows.ps1, das alle gelisteten Programme deinstallieren kann.
Nutzer soll einzeln auswählen können welche Programme entfernt werden.
winget-Befehl: winget uninstall --id <ID> --silent
```

#### Sprache anpassen

```
Erstelle eine englische Version beider Skripte. Alle Ausgaben, Abfragen und
Meldungen sollen auf Englisch sein. Dateinamen: install_assist_windows_en.ps1
und install_assist_linux_en.sh. Inhalt und Logik bleiben identisch.
```

#### Logging hinzufügen

```
Füge in beiden Skripten eine Protokollierungsfunktion hinzu.
Nach der Installation soll eine Logdatei erstellt werden:
- Windows: install_log_<Datum>.txt im selben Ordner
- Linux:   install_log_<Datum>.txt im selben Ordner
Inhalt: Datum/Uhrzeit, Hostname, OS, was installiert wurde, was fehlschlug.
```

#### Winget-ID nachschlagen lassen

```
Suche die korrekte winget-ID für das Programm "Obsidian" und füge es
zur Programmliste in install_assist_windows.ps1 hinzu.
Prüfe auch ob es ein apt-Paket für Ubuntu gibt und ergänze install_assist_linux.sh.
```

#### Fehlerbehandlung verbessern

```
Verbessere die Fehlerbehandlung in install_assist_windows.ps1:
Wenn winget bei einem Paket fehlschlägt, soll automatisch ein zweiter
Versuch ohne --silent Flag gestartet werden, damit der Nutzer das Installationsfenster
manuell bedienen kann.
```

#### Skript testen (Trockenlauf)

```
Füge in beiden Skripten einen --dry-run Parameter hinzu.
Wenn das Skript mit dem Parameter gestartet wird (z.B. .\install_assist_windows.ps1 --dry-run),
soll nur der Installationsstatus angezeigt werden, aber nichts installiert werden.
```

---

## Hinweise zur Struktur (für Claude Code)

Die Skripte sind bewusst linear aufgebaut, damit Anpassungen einfach möglich sind:

- **Programme** sind als Array/Liste am Anfang des Skripts definiert → einfaches Hinzufügen/Entfernen
- **Sonderfälle** (Chrome, Brave, VS Code, Python) haben eigene Funktionen → leicht austauschbar
- **Alle Texte** sind auf Deutsch und direkt im Code → einfach übersetzbar
- **Farben** sind am Anfang als Variablen definiert (Bash) bzw. als Parameter übergeben (PowerShell)
- **Auswahl statt Alles-oder-nichts**: Der Nutzer wählt gezielt aus, welche der
  fehlenden Programme installiert werden sollen (Nummernauswahl, "alle" oder
  "keine") – analog zur bestehenden Python-Versionsauswahl
- **Zusätzliche Freeware**: Am Ende wird gefragt, ob weitere Programme
  installiert werden sollen, die nicht in der festen Liste stehen (freie
  Eingabe von Name + winget-ID bzw. apt-Paketname)
- Adobe Acrobat Reader ist nur im Windows-Skript enthalten, da Adobe keinen
  offiziellen Reader mehr für Linux anbietet

---

## Lizenz

Frei verwendbar für private und gewerbliche Zwecke.
