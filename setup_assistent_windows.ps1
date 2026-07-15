#Requires -Version 5.1
# Setup-Assistent - Windows Grundsetup
# Grundsetup: winget, Git, Claude Code CLI (fuer Repo-Zugriff/Download)
# Verschiebung von Benutzerordnern (Bilder/Downloads/Dokumente) ist ein eigenes
# Skript: verschiebe_benutzerordner_windows.ps1

$ProgressPreference    = "SilentlyContinue"
$ErrorActionPreference = "Continue"

# ─── Hilfsfunktionen ────────────────────────────────────────────────────────

function Abschnitt([string]$Titel) {
    Write-Host ""
    Write-Host "  >> $Titel" -ForegroundColor Yellow
    Write-Host ("  " + ("-" * 54)) -ForegroundColor DarkGray
}

function Pruefe-Pfade([string[]]$Pfade) {
    foreach ($p in $Pfade) { if (Test-Path $p) { return $true } }
    return $false
}

function Pruefe-Winget([string]$ID) {
    $out  = winget list --id $ID --exact --accept-source-agreements 2>&1
    $text = ($out -join " ")
    return ($text -notmatch "(No installed|Kein installiertes)") -and ($text -match [regex]::Escape($ID))
}

function Winget-Installiere([string]$ID) {
    winget install --id $ID --exact --silent `
        --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
    return $LASTEXITCODE
}

function Aktualisiere-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function Installiere-Winget {
    Write-Host "  Versuche winget zu registrieren ..." -ForegroundColor Cyan
    try {
        Add-AppxPackage -RegisterByFamilyName `
            -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction Stop
    } catch { }

    Aktualisiere-Path
    if (Get-Command winget -ErrorAction SilentlyContinue) { return $true }

    Write-Host "  Lade App Installer (winget) von GitHub herunter ..." -ForegroundColor Cyan
    $tmp    = Join-Path $env:TEMP "winget-setup"
    $bundle = Join-Path $tmp "DesktopAppInstaller.msixbundle"
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null

    try {
        Invoke-WebRequest -UseBasicParsing `
            -Uri "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" `
            -OutFile $bundle
        Add-AppxPackage -Path $bundle -ErrorAction Stop
    } catch {
        Write-Host "  [!!] Automatische winget-Installation fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "       Moegliche Ursache: fehlende Abhaengigkeit (Microsoft.VCLibs / Microsoft.UI.Xaml)." -ForegroundColor Yellow
        Write-Host "       Bitte manuell installieren: https://aka.ms/getwinget" -ForegroundColor Yellow
        return $false
    } finally {
        Remove-Item -Path $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }

    Aktualisiere-Path
    if (Get-Command winget -ErrorAction SilentlyContinue) { return $true }

    Write-Host "  [!!] winget wurde installiert, ist in dieser Sitzung aber noch nicht verfuegbar." -ForegroundColor Yellow
    Write-Host "       Bitte Terminal neu starten und Skript erneut ausfuehren." -ForegroundColor Yellow
    return $false
}

function Installiere-Claude {
    Write-Host "  Fuehre aus: irm https://claude.ai/install.ps1 | iex" -ForegroundColor DarkGray
    try {
        Invoke-Expression (Invoke-RestMethod -Uri "https://claude.ai/install.ps1" -UseBasicParsing)
    } catch {
        Write-Host "  [!!] Claude Code Installation fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    Aktualisiere-Path
    return [bool](Get-Command claude -ErrorAction SilentlyContinue)
}

# ─── Voraussetzungen ────────────────────────────────────────────────────────

if ($env:OS -ne "Windows_NT") {
    Write-Host "FEHLER: Dieses Skript ist nur fuer Windows." -ForegroundColor Red
    exit 1
}

# ─── Kopfzeile ──────────────────────────────────────────────────────────────

Clear-Host
Write-Host ""
Write-Host "  +------------------------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |      Setup-Assistent  -  Windows Grundsetup                |" -ForegroundColor Cyan
Write-Host "  +------------------------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Hinweis: fuer systemweite Installationen ggf. als Administrator ausfuehren." -ForegroundColor DarkGray

# ─── Systeminformationen ────────────────────────────────────────────────────

Abschnitt "Systeminformationen"
Write-Host ""
try {
    $os  = Get-CimInstance Win32_OperatingSystem
    $cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name.Trim()
    $ram = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    Write-Host ("  {0,-12} {1}" -f "Hostname:",  $env:COMPUTERNAME)
    Write-Host ("  {0,-12} {1}" -f "System:",    $os.Caption)
    Write-Host ("  {0,-12} {1} GB" -f "RAM:",    $ram)
    Write-Host ("  {0,-12} {1}" -f "CPU:",       $cpu)
} catch {
    Write-Host "  Systeminfo nicht verfuegbar." -ForegroundColor DarkYellow
}

# ─── Grundsetup: Status pruefen ─────────────────────────────────────────────

Abschnitt "Grundsetup-Status"
Write-Host ""

$GrundsetupKandidaten = @(
    @{ Name = "winget (Windows Package Manager)"; Key = "winget" }
    @{ Name = "Git";                              Key = "git" }
    @{ Name = "Claude Code CLI";                  Key = "claude" }
)

$GrundsetupFehlend = [System.Collections.ArrayList]::new()

foreach ($k in $GrundsetupKandidaten) {
    Write-Host "  Pruefe $($k.Name) ..." -NoNewline -ForegroundColor DarkGray

    $ok = switch ($k.Key) {
        "winget" { [bool](Get-Command winget -ErrorAction SilentlyContinue) }
        "git"    {
            [bool](Get-Command git -ErrorAction SilentlyContinue) -or
            (Pruefe-Pfade @(
                "$env:ProgramFiles\Git\bin\git.exe",
                "${env:ProgramFiles(x86)}\Git\bin\git.exe"
            )) -or
            ((Get-Command winget -ErrorAction SilentlyContinue) -and (Pruefe-Winget "Git.Git"))
        }
        "claude" { [bool](Get-Command claude -ErrorAction SilentlyContinue) }
    }

    if ($ok) {
        Write-Host "`r  [OK] $($k.Name.PadRight(32)) installiert          " -ForegroundColor Green
    } else {
        Write-Host "`r  [--] $($k.Name.PadRight(32)) nicht installiert     " -ForegroundColor Red
        [void]$GrundsetupFehlend.Add($k)
    }
}

# ─── Grundsetup: Auswahl ────────────────────────────────────────────────────

$GrundsetupAusgewaehlt = [System.Collections.ArrayList]::new()

if ($GrundsetupFehlend.Count -gt 0) {
    Abschnitt "Auswahl Grundsetup"
    Write-Host ""
    Write-Host "  Folgende Komponenten sind noch nicht installiert:" -ForegroundColor White
    Write-Host ""
    for ($i = 0; $i -lt $GrundsetupFehlend.Count; $i++) {
        Write-Host ("    [{0}]  {1}" -f ($i + 1), $GrundsetupFehlend[$i].Name) -ForegroundColor Cyan
    }
    Write-Host ""
    Write-Host "  Eingabe: Nummern durch Komma getrennt (z.B. 1,3), 'alle' oder 'keine'" -ForegroundColor DarkGray
    Write-Host ""

    :grundsetupauswahl while ($true) {
        $eingabe = (Read-Host "  Auswahl").Trim()

        if ($eingabe -eq "" -or $eingabe -match "^(keine|nein|n)$") {
            break grundsetupauswahl
        }
        if ($eingabe -match "^(alle|a)$") {
            $GrundsetupAusgewaehlt.AddRange($GrundsetupFehlend)
            break grundsetupauswahl
        }

        $nummern = $eingabe -split "," | ForEach-Object { $_.Trim() }
        $auswahl = [System.Collections.ArrayList]::new()
        $gueltig = $true

        foreach ($n in $nummern) {
            if ($n -match "^\d+$" -and [int]$n -ge 1 -and [int]$n -le $GrundsetupFehlend.Count) {
                [void]$auswahl.Add($GrundsetupFehlend[[int]$n - 1])
            } else {
                Write-Host "  Ungueltige Eingabe: '$n'" -ForegroundColor Red
                $gueltig = $false
                break
            }
        }

        if ($gueltig) {
            $GrundsetupAusgewaehlt.AddRange($auswahl)
            break grundsetupauswahl
        }
    }
} else {
    Write-Host ""
    Write-Host "  Grundsetup ist bereits vollstaendig installiert." -ForegroundColor Green
}

$AusgewaehlteKeys = $GrundsetupAusgewaehlt | ForEach-Object { $_.Key }

# ─── Installationsuebersicht ────────────────────────────────────────────────

Abschnitt "Installationsuebersicht"
Write-Host ""

if ($GrundsetupAusgewaehlt.Count -eq 0) {
    Write-Host "  Es wurde nichts zur Ausfuehrung ausgewaehlt." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "  Enter zum Beenden"
    exit 0
}

foreach ($k in $GrundsetupAusgewaehlt) { Write-Host "  *  $($k.Name)" -ForegroundColor Red }

Write-Host ""
$antwort = Read-Host "  Jetzt ausfuehren? (J/N)"

if ($antwort -notmatch "^[jJyY]$") {
    Write-Host ""
    Write-Host "  Abgebrochen." -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

# ─── Ausfuehrung: Grundsetup ────────────────────────────────────────────────

Abschnitt "Grundsetup wird eingerichtet"
Write-Host ""

$Erfolg  = [System.Collections.ArrayList]::new()
$Fehler  = [System.Collections.ArrayList]::new()
$OkCodes = @(0, -1978335189, -1978335106, 3010)

if ($AusgewaehlteKeys -contains "winget") {
    Write-Host "  Installiere winget ..." -ForegroundColor Cyan
    if (Installiere-Winget) {
        Write-Host "  [OK] winget erfolgreich eingerichtet" -ForegroundColor Green
        [void]$Erfolg.Add("winget")
    } else {
        Write-Host "  [!!] winget-Einrichtung fehlgeschlagen" -ForegroundColor Red
        [void]$Fehler.Add("winget")
    }
    Write-Host ""
}

if ($AusgewaehlteKeys -contains "git") {
    Write-Host "  Installiere Git ..." -ForegroundColor Cyan
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "  [!!] Git fehlgeschlagen: winget nicht verfuegbar" -ForegroundColor Red
        [void]$Fehler.Add("Git")
    } else {
        $code = Winget-Installiere "Git.Git"
        if ($OkCodes -contains $code) {
            Write-Host "  [OK] Git erfolgreich installiert" -ForegroundColor Green
            [void]$Erfolg.Add("Git")
            Aktualisiere-Path
        } else {
            Write-Host "  [!!] Git fehlgeschlagen  (Code: $code)" -ForegroundColor Red
            [void]$Fehler.Add("Git")
        }
    }
    Write-Host ""
}

if ($AusgewaehlteKeys -contains "claude") {
    Write-Host "  Installiere Claude Code CLI ..." -ForegroundColor Cyan
    if (Installiere-Claude) {
        Write-Host "  [OK] Claude Code CLI erfolgreich installiert" -ForegroundColor Green
        [void]$Erfolg.Add("Claude Code CLI")
    } else {
        Write-Host "  [!!] Claude Code CLI fehlgeschlagen" -ForegroundColor Red
        [void]$Fehler.Add("Claude Code CLI")
    }
    Write-Host ""
}

# ─── Abschlussbericht ───────────────────────────────────────────────────────

Abschnitt "Abschlussbericht"
Write-Host ""

if ($Erfolg.Count -gt 0) {
    Write-Host "  Erfolgreich:" -ForegroundColor Green
    foreach ($n in $Erfolg) { Write-Host "    [OK] $n" -ForegroundColor Green }
    Write-Host ""
}

if ($Fehler.Count -gt 0) {
    Write-Host "  Fehlgeschlagen:" -ForegroundColor Red
    foreach ($n in $Fehler) { Write-Host "    [!!] $n" -ForegroundColor Red }
    Write-Host ""
    Write-Host "  Tipp: Terminal neu starten (PATH-Aktualisierung), Administratorrechte" -ForegroundColor Yellow
    Write-Host "        oder Internetverbindung pruefen." -ForegroundColor Yellow
    Write-Host ""
}

if ($Fehler.Count -eq 0) {
    Write-Host "  Alles erfolgreich abgeschlossen!" -ForegroundColor Green
}

Write-Host ""
Write-Host ("  " + ("-" * 56)) -ForegroundColor DarkGray
Write-Host ""
Read-Host "  Enter zum Beenden"
