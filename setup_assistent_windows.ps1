#Requires -Version 5.1
# Setup-Assistent - Windows Grundsetup
# Grundsetup: winget, Git, Claude Code CLI (fuer Repo-Zugriff/Download)
# Zusatzfunktion: Verschiebung von Bilder/Downloads/Dokumente auf eine andere Partition

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

function Get-BekannterOrdnerPfad([string]$ShellName) {
    try {
        $shell = New-Object -ComObject Shell.Application
        $ns    = $shell.Namespace("shell:$ShellName")
        if ($null -eq $ns) { return $null }
        return $ns.Self.Path
    } catch {
        return $null
    }
}

function Get-Ordnergroesse([string]$Pfad) {
    if (-not (Test-Path $Pfad)) { return 0 }
    $summe = (Get-ChildItem -Path $Pfad -Recurse -Force -ErrorAction SilentlyContinue |
              Measure-Object -Property Length -Sum).Sum
    if ($null -eq $summe) { return 0 }
    return $summe
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

Write-Host ""
Write-Host "  Laufwerke:" -ForegroundColor White
try {
    Get-Volume | Where-Object { $_.DriveLetter } | Sort-Object DriveLetter | ForEach-Object {
        $freiGB    = [math]::Round($_.SizeRemaining / 1GB, 1)
        $groesseGB = [math]::Round($_.Size / 1GB, 1)
        Write-Host ("    {0}:\  {1,7} GB frei  /  {2,7} GB gesamt   {3}" -f `
            $_.DriveLetter, $freiGB, $groesseGB, $_.FileSystemLabel)
    }
} catch {
    Write-Host "  Laufwerksinfo nicht verfuegbar." -ForegroundColor DarkYellow
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

# ─── Verschiebung der Benutzerordner: Planung ───────────────────────────────

Abschnitt "Verschiebung der Benutzerordner"
Write-Host ""

$OrdnerDefinitionen = @(
    @{ Label = "Bilder";    ShellName = "My Pictures"; RegName = "My Pictures" }
    @{ Label = "Downloads"; ShellName = "Downloads";   RegName = "{374DE290-123F-4565-9164-39C4925E467B}" }
    @{ Label = "Dokumente"; ShellName = "Personal";     RegName = "Personal" }
)

$OrdnerPlan = [System.Collections.ArrayList]::new()
$antwortOrdner = Read-Host "  Bilder, Downloads und Dokumente auf eine andere Partition verschieben? (J/N)"

if ($antwortOrdner -match "^[jJyY]$") {
    Write-Host ""
    $zielEingabe = (Read-Host "  Zielordner (z.B. D:\Benutzer)").Trim().TrimEnd('\')

    if ($zielEingabe.Length -lt 2 -or $zielEingabe[1] -ne ':') {
        Write-Host "  Ungueltiger Pfad, Verschiebung wird uebersprungen." -ForegroundColor Red
    } else {
        $laufwerk = $zielEingabe.Substring(0, 2)

        if (-not (Test-Path "$laufwerk\")) {
            Write-Host "  Laufwerk $laufwerk existiert nicht, Verschiebung wird uebersprungen." -ForegroundColor Red
        } else {
            $GesamtGroesse = 0

            foreach ($def in $OrdnerDefinitionen) {
                $alterPfad = Get-BekannterOrdnerPfad $def.ShellName

                if ([string]::IsNullOrWhiteSpace($alterPfad) -or -not (Test-Path $alterPfad)) {
                    Write-Host "  [!!] $($def.Label): aktueller Pfad nicht ermittelbar, wird uebersprungen." -ForegroundColor Yellow
                    continue
                }

                $leafName  = Split-Path -Leaf $alterPfad
                $neuerPfad = Join-Path $zielEingabe $leafName

                if ($neuerPfad -eq $alterPfad) {
                    Write-Host "  [OK] $($def.Label) ist bereits am Zielort." -ForegroundColor Green
                    continue
                }

                # OneDrive verwaltet diese Ordner ggf. selbst - manuelles Verschieben
                # kann mit der Synchronisierung kollidieren.
                if ($alterPfad -like "*OneDrive*") {
                    Write-Host "  [!!] $($def.Label) wird aktuell ueber OneDrive gesichert:" -ForegroundColor Yellow
                    Write-Host "       $alterPfad" -ForegroundColor Yellow
                    Write-Host "       Verschieben kann mit der OneDrive-Synchronisierung kollidieren." -ForegroundColor Yellow
                    Write-Host "       Empfehlung: OneDrive-Ordnersicherung vorher deaktivieren." -ForegroundColor Yellow
                    $weiterOneDrive = Read-Host "  '$($def.Label)' trotzdem verschieben? (j/N)"
                    if ($weiterOneDrive -notmatch "^[jJyY]$") {
                        Write-Host "  $($def.Label) wird uebersprungen." -ForegroundColor DarkGray
                        Write-Host ""
                        continue
                    }
                    Write-Host ""
                }

                $groesse = Get-Ordnergroesse $alterPfad
                $GesamtGroesse += $groesse

                [void]$OrdnerPlan.Add(@{
                    Label     = $def.Label
                    RegName   = $def.RegName
                    AlterPfad = $alterPfad
                    NeuerPfad = $neuerPfad
                    Groesse   = $groesse
                })
            }

            if ($OrdnerPlan.Count -gt 0) {
                $laufwerksBuchstabe = $laufwerk.TrimEnd(':')
                $vol         = Get-Volume -DriveLetter $laufwerksBuchstabe -ErrorAction SilentlyContinue
                $freierPlatz = if ($vol) { $vol.SizeRemaining } else { $null }

                Write-Host ""
                Write-Host "  Geplante Verschiebung:" -ForegroundColor White
                Write-Host ""
                foreach ($eintrag in $OrdnerPlan) {
                    $groesseGB = [math]::Round($eintrag.Groesse / 1GB, 2)
                    Write-Host ("    {0,-10} {1}  ->  {2}   (~{3} GB)" -f `
                        $eintrag.Label, $eintrag.AlterPfad, $eintrag.NeuerPfad, $groesseGB) -ForegroundColor Cyan
                }
                Write-Host ""
                Write-Host ("  Benoetigter Speicherplatz gesamt: ~{0} GB" -f ([math]::Round($GesamtGroesse / 1GB, 2)))

                if ($null -ne $freierPlatz -and ($GesamtGroesse * 1.1) -gt $freierPlatz) {
                    Write-Host ("  [!!] Nicht genug freier Speicherplatz auf {0} (frei: {1} GB). Verschiebung wird uebersprungen." -f `
                        $laufwerk, [math]::Round($freierPlatz / 1GB, 1)) -ForegroundColor Red
                    $OrdnerPlan.Clear()
                }
            } else {
                Write-Host "  Es gibt nichts zu verschieben." -ForegroundColor Yellow
            }
        }
    }
}

# ─── Installationsuebersicht ────────────────────────────────────────────────

Abschnitt "Installationsuebersicht"
Write-Host ""

if ($GrundsetupAusgewaehlt.Count -eq 0 -and $OrdnerPlan.Count -eq 0) {
    Write-Host "  Es wurde nichts zur Ausfuehrung ausgewaehlt." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "  Enter zum Beenden"
    exit 0
}

foreach ($k in $GrundsetupAusgewaehlt) { Write-Host "  *  $($k.Name)" -ForegroundColor Red }
foreach ($eintrag in $OrdnerPlan)      { Write-Host "  *  Ordner verschieben: $($eintrag.Label)" -ForegroundColor Red }

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

# ─── Ausfuehrung: Ordner verschieben ────────────────────────────────────────

if ($OrdnerPlan.Count -gt 0) {
    Abschnitt "Benutzerordner werden verschoben"
    Write-Host ""

    $UserShellFolders = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
    $ShellFolders     = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders"
    $mindEinErfolg    = $false

    foreach ($eintrag in $OrdnerPlan) {
        Write-Host "  Verschiebe $($eintrag.Label) ..." -ForegroundColor Cyan
        New-Item -ItemType Directory -Path $eintrag.NeuerPfad -Force | Out-Null

        robocopy $eintrag.AlterPfad $eintrag.NeuerPfad /E /MOVE /R:1 /W:1 /NFL /NDL /NJH /NJS | Out-Null
        $rcCode = $LASTEXITCODE

        if ($rcCode -lt 8) {
            Set-ItemProperty -Path $UserShellFolders -Name $eintrag.RegName -Value $eintrag.NeuerPfad -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $ShellFolders     -Name $eintrag.RegName -Value $eintrag.NeuerPfad -ErrorAction SilentlyContinue
            Write-Host "  [OK] $($eintrag.Label) erfolgreich verschoben" -ForegroundColor Green
            [void]$Erfolg.Add("Ordner: $($eintrag.Label)")
            $mindEinErfolg = $true
        } else {
            Write-Host "  [!!] $($eintrag.Label) fehlgeschlagen  (robocopy-Code: $rcCode)" -ForegroundColor Red
            [void]$Fehler.Add("Ordner: $($eintrag.Label)")
        }
        Write-Host ""
    }

    if ($mindEinErfolg) {
        Write-Host "  Starte Explorer neu, damit die neuen Pfade uebernommen werden ..." -ForegroundColor DarkGray
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Start-Process explorer.exe
        Write-Host ""
    }
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
