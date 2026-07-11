#Requires -Version 5.1
# Freeware Installationsassistent - Windows
# Benoetigt: winget (Windows Package Manager)

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

# ─── Voraussetzungen ────────────────────────────────────────────────────────

if ($env:OS -ne "Windows_NT") {
    Write-Host "FEHLER: Dieses Skript ist nur fuer Windows." -ForegroundColor Red
    exit 1
}
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "  FEHLER: winget nicht gefunden." -ForegroundColor Red
    Write-Host "  Bitte installieren: https://aka.ms/getwinget" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

# ─── Kopfzeile ──────────────────────────────────────────────────────────────

Clear-Host
Write-Host ""
Write-Host "  +------------------------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |      Freeware Installationsassistent  -  Windows           |" -ForegroundColor Cyan
Write-Host "  +------------------------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Plattform: " -NoNewline
Write-Host "Windows  (winget)" -ForegroundColor Green

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

# ─── Programme ──────────────────────────────────────────────────────────────

$Programme = @(
    @{
        Name  = "Firefox"
        ID    = "Mozilla.Firefox"
        Pfade = @(
            "$env:ProgramFiles\Mozilla Firefox\firefox.exe",
            "${env:ProgramFiles(x86)}\Mozilla Firefox\firefox.exe"
        )
    }
    @{
        Name  = "Google Chrome"
        ID    = "Google.Chrome"
        Pfade = @(
            "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
            "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
        )
    }
    @{
        Name  = "Brave Browser"
        ID    = "Brave.Brave"
        Pfade = @(
            "$env:ProgramFiles\BraveSoftware\Brave-Browser\Application\brave.exe",
            "${env:ProgramFiles(x86)}\BraveSoftware\Brave-Browser\Application\brave.exe",
            "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\Application\brave.exe"
        )
    }
    @{
        Name  = "Notepad++"
        ID    = "Notepad++.Notepad++"
        Pfade = @(
            "$env:ProgramFiles\Notepad++\notepad++.exe",
            "${env:ProgramFiles(x86)}\Notepad++\notepad++.exe"
        )
    }
    @{
        Name  = "VLC"
        ID    = "VideoLAN.VLC"
        Pfade = @(
            "$env:ProgramFiles\VideoLAN\VLC\vlc.exe",
            "${env:ProgramFiles(x86)}\VideoLAN\VLC\vlc.exe"
        )
    }
    @{
        Name  = "7-Zip"
        ID    = "7zip.7zip"
        Pfade = @(
            "$env:ProgramFiles\7-Zip\7z.exe",
            "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
        )
    }
    @{
        Name  = "Adobe Acrobat Reader"
        ID    = "Adobe.Acrobat.Reader.64-bit"
        Pfade = @(
            "$env:ProgramFiles\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe",
            "${env:ProgramFiles(x86)}\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe"
        )
    }
    @{
        Name  = "VS Code"
        ID    = "Microsoft.VisualStudioCode"
        Pfade = @(
            "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
            "$env:ProgramFiles\Microsoft VS Code\Code.exe"
        )
    }
    @{
        Name  = "Git"
        ID    = "Git.Git"
        Pfade = @(
            "$env:ProgramFiles\Git\bin\git.exe",
            "${env:ProgramFiles(x86)}\Git\bin\git.exe"
        )
    }
)

$PythonVersionen = @("3.10", "3.11", "3.12", "3.13")
$PythonIDs = @{
    "3.10" = "Python.Python.3.10"
    "3.11" = "Python.Python.3.11"
    "3.12" = "Python.Python.3.12"
    "3.13" = "Python.Python.3.13"
}

# ─── Installationsstatus pruefen ────────────────────────────────────────────

Abschnitt "Installationsstatus"
Write-Host ""

$Fehlend = [System.Collections.ArrayList]::new()

foreach ($p in $Programme) {
    Write-Host "  Pruefe $($p.Name) ..." -NoNewline -ForegroundColor DarkGray
    $ok = (Pruefe-Pfade $p.Pfade) -or (Pruefe-Winget $p.ID)
    if ($ok) {
        Write-Host "`r  [OK] $($p.Name.PadRight(24)) installiert          " -ForegroundColor Green
    } else {
        Write-Host "`r  [--] $($p.Name.PadRight(24)) nicht installiert     " -ForegroundColor Red
        [void]$Fehlend.Add($p)
    }
}

# Python-Versionen pruefen
Write-Host ""
Write-Host "  Python-Versionen:" -ForegroundColor White
Write-Host ""

$PyOk    = [System.Collections.ArrayList]::new()
$PyFehlt = [System.Collections.ArrayList]::new()

foreach ($ver in $PythonVersionen) {
    $gefunden = $false

    # Schnell-Check via Python-Launcher (py.exe)
    if (-not $gefunden -and (Get-Command py -ErrorAction SilentlyContinue)) {
        $pyOut = (& py --list 2>&1) -join " "
        if ($pyOut -match $ver) { $gefunden = $true }
    }

    # Fallback: winget-Liste
    if (-not $gefunden) {
        $gefunden = Pruefe-Winget $PythonIDs[$ver]
    }

    if ($gefunden) {
        [void]$PyOk.Add($ver)
        Write-Host "  [OK] Python $ver" -ForegroundColor Green
    } else {
        [void]$PyFehlt.Add($ver)
        Write-Host "  [--] Python $ver" -ForegroundColor Red
    }
}

# ─── Auswahl der zu installierenden Programme ──────────────────────────────

$AusgewaehlteProgramme = [System.Collections.ArrayList]::new()

if ($Fehlend.Count -gt 0) {
    Abschnitt "Auswahl der Programme"
    Write-Host ""
    Write-Host "  Folgende Programme sind noch nicht installiert:" -ForegroundColor White
    Write-Host ""
    for ($i = 0; $i -lt $Fehlend.Count; $i++) {
        Write-Host ("    [{0}]  {1}" -f ($i + 1), $Fehlend[$i].Name) -ForegroundColor Cyan
    }
    Write-Host ""
    Write-Host "  Eingabe: Nummern durch Komma getrennt (z.B. 1,3), 'alle' oder 'keine'" -ForegroundColor DarkGray
    Write-Host ""

    :programmauswahl while ($true) {
        $eingabe = (Read-Host "  Auswahl").Trim()

        if ($eingabe -eq "" -or $eingabe -match "^(keine|nein|n)$") {
            break programmauswahl
        }
        if ($eingabe -match "^(alle|a)$") {
            $AusgewaehlteProgramme.AddRange($Fehlend)
            break programmauswahl
        }

        $nummern = $eingabe -split "," | ForEach-Object { $_.Trim() }
        $auswahl = [System.Collections.ArrayList]::new()
        $gueltig = $true

        foreach ($n in $nummern) {
            if ($n -match "^\d+$" -and [int]$n -ge 1 -and [int]$n -le $Fehlend.Count) {
                [void]$auswahl.Add($Fehlend[[int]$n - 1])
            } else {
                Write-Host "  Ungueltige Eingabe: '$n'" -ForegroundColor Red
                $gueltig = $false
                break
            }
        }

        if ($gueltig) {
            $AusgewaehlteProgramme.AddRange($auswahl)
            break programmauswahl
        }
    }
} else {
    Write-Host ""
    Write-Host "  Alle Programme aus der Liste sind bereits installiert." -ForegroundColor Green
}

# Python-Auswahl
$GewuenshtePython = $null
Write-Host ""

if ($PyFehlt.Count -gt 0) {
    Write-Host "  Zur Installation verfuegbar:" -ForegroundColor White
    for ($i = 0; $i -lt $PythonVersionen.Count; $i++) {
        $v = $PythonVersionen[$i]
        if ($PyFehlt -contains $v) {
            Write-Host "    [$($i + 1)]  Python $v" -ForegroundColor Cyan
        }
    }
    Write-Host "    [0]  Kein Python installieren" -ForegroundColor DarkGray
    Write-Host ""

    :pythonauswahl while ($true) {
        $eingabe = Read-Host "  Auswahl (Nummer eingeben)"
        if ($eingabe -eq "0" -or $eingabe -eq "") { break pythonauswahl }

        if ($eingabe -match "^\d+$") {
            $idx = [int]$eingabe - 1
            if ($idx -ge 0 -and $idx -lt $PythonVersionen.Count) {
                $v = $PythonVersionen[$idx]
                if ($PyFehlt -contains $v) {
                    $GewuenshtePython = $v
                    break pythonauswahl
                } elseif ($PyOk -contains $v) {
                    Write-Host "  Python $v ist bereits installiert." -ForegroundColor Yellow
                } else {
                    Write-Host "  Ungueltige Auswahl." -ForegroundColor Red
                }
            } else {
                Write-Host "  Ungueltige Nummer." -ForegroundColor Red
            }
        } else {
            Write-Host "  Bitte eine Zahl eingeben." -ForegroundColor Red
        }
    }
} else {
    Write-Host "  Alle Python-Versionen sind bereits installiert." -ForegroundColor Green
}

# ─── Zusaetzliche Freeware ──────────────────────────────────────────────────

Abschnitt "Zusaetzliche Freeware"
Write-Host ""

$ZusatzProgramme = [System.Collections.ArrayList]::new()
$antwortZusatz = Read-Host "  Weitere Freeware installieren, die nicht in der Liste steht? (J/N)"

if ($antwortZusatz -match "^[jJyY]$") {
    Write-Host ""
    Write-Host "  Winget-ID vorher mit 'winget search <Name>' ermitteln." -ForegroundColor DarkGray
    Write-Host "  Leere Eingabe beim Programmnamen beendet die Erfassung." -ForegroundColor DarkGray
    Write-Host ""
    while ($true) {
        $zName = Read-Host "  Programmname"
        if ([string]::IsNullOrWhiteSpace($zName)) { break }

        $zID = Read-Host "  Winget-ID fuer '$zName'"
        if ([string]::IsNullOrWhiteSpace($zID)) {
            Write-Host "  Keine ID angegeben, '$zName' wird uebersprungen." -ForegroundColor Yellow
            Write-Host ""
            continue
        }

        [void]$ZusatzProgramme.Add(@{ Name = $zName; ID = $zID })
        Write-Host "  [+] '$zName' ($zID) wird zur Installation vorgemerkt" -ForegroundColor Green
        Write-Host ""
    }
}

# ─── Installationsuebersicht ────────────────────────────────────────────────

Abschnitt "Installationsuebersicht"
Write-Host ""

if ($AusgewaehlteProgramme.Count -eq 0 -and $null -eq $GewuenshtePython -and $ZusatzProgramme.Count -eq 0) {
    Write-Host "  Es wurde nichts zur Installation ausgewaehlt." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "  Enter zum Beenden"
    exit 0
}

foreach ($p in $AusgewaehlteProgramme) { Write-Host "  *  $($p.Name)" -ForegroundColor Red }
if ($null -ne $GewuenshtePython)       { Write-Host "  *  Python $GewuenshtePython" -ForegroundColor Red }
foreach ($z in $ZusatzProgramme)       { Write-Host "  *  $($z.Name)  (zusaetzlich)" -ForegroundColor Red }

Write-Host ""
$antwort = Read-Host "  Diese Programme jetzt installieren? (J/N)"

if ($antwort -notmatch "^[jJyY]$") {
    Write-Host ""
    Write-Host "  Installation abgebrochen." -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

# ─── Installation ───────────────────────────────────────────────────────────

Abschnitt "Installation laeuft"
Write-Host ""

$Erfolg  = [System.Collections.ArrayList]::new()
$Fehler  = [System.Collections.ArrayList]::new()
$OkCodes = @(0, -1978335189, -1978335106, 3010)

foreach ($p in $AusgewaehlteProgramme) {
    Write-Host "  Installiere $($p.Name) ..." -ForegroundColor Cyan
    $code = Winget-Installiere $p.ID
    if ($OkCodes -contains $code) {
        Write-Host "  [OK] $($p.Name) erfolgreich installiert" -ForegroundColor Green
        [void]$Erfolg.Add($p.Name)
    } else {
        Write-Host "  [!!] $($p.Name) fehlgeschlagen  (Code: $code)" -ForegroundColor Red
        [void]$Fehler.Add($p.Name)
    }
    Write-Host ""
}

if ($null -ne $GewuenshtePython) {
    $pyID = $PythonIDs[$GewuenshtePython]
    Write-Host "  Installiere Python $GewuenshtePython ..." -ForegroundColor Cyan
    $code = Winget-Installiere $pyID
    if ($OkCodes -contains $code) {
        Write-Host "  [OK] Python $GewuenshtePython erfolgreich installiert" -ForegroundColor Green
        [void]$Erfolg.Add("Python $GewuenshtePython")
    } else {
        Write-Host "  [!!] Python $GewuenshtePython fehlgeschlagen  (Code: $code)" -ForegroundColor Red
        [void]$Fehler.Add("Python $GewuenshtePython")
    }
    Write-Host ""
}

foreach ($z in $ZusatzProgramme) {
    Write-Host "  Installiere $($z.Name) ..." -ForegroundColor Cyan
    $code = Winget-Installiere $z.ID
    if ($OkCodes -contains $code) {
        Write-Host "  [OK] $($z.Name) erfolgreich installiert" -ForegroundColor Green
        [void]$Erfolg.Add($z.Name)
    } else {
        Write-Host "  [!!] $($z.Name) fehlgeschlagen  (Code: $code)" -ForegroundColor Red
        [void]$Fehler.Add($z.Name)
    }
    Write-Host ""
}

# ─── Abschlussbericht ───────────────────────────────────────────────────────

Abschnitt "Abschlussbericht"
Write-Host ""

if ($Erfolg.Count -gt 0) {
    Write-Host "  Erfolgreich installiert:" -ForegroundColor Green
    foreach ($n in $Erfolg) { Write-Host "    [OK] $n" -ForegroundColor Green }
    Write-Host ""
}

if ($Fehler.Count -gt 0) {
    Write-Host "  Fehlgeschlagen:" -ForegroundColor Red
    foreach ($n in $Fehler) { Write-Host "    [!!] $n" -ForegroundColor Red }
    Write-Host ""
    Write-Host "  Tipp: Skript als Administrator ausfuehren oder" -ForegroundColor Yellow
    Write-Host "        Internetverbindung pruefen." -ForegroundColor Yellow
    Write-Host ""
}

if ($Fehler.Count -eq 0) {
    Write-Host "  Alle Installationen erfolgreich abgeschlossen!" -ForegroundColor Green
}

Write-Host ""
Write-Host ("  " + ("-" * 56)) -ForegroundColor DarkGray
Write-Host ""
Read-Host "  Enter zum Beenden"
