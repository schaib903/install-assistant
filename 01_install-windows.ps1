#Requires -Version 5.1
# Freeware Install Assistant - Windows
# Requires: winget (Windows Package Manager)
# Self-elevates once at startup (single UAC prompt) so individual package
# installs that need Administrator rights don't each trigger their own
# confirmation dialog. If elevation is declined, the script continues
# without it - some installs may then show extra prompts of their own.

$ProgressPreference    = "SilentlyContinue"
$ErrorActionPreference = "Continue"

# ─── Helper functions ───────────────────────────────────────────────────────

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

# ─── Prerequisites ──────────────────────────────────────────────────────────

if ($env:OS -ne "Windows_NT") {
    Write-Host "ERROR: This script is Windows-only." -ForegroundColor Red
    exit 1
}
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "  ERROR: winget not found." -ForegroundColor Red
    Write-Host "  Please install: https://aka.ms/getwinget" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

$IstElevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $IstElevated) {
    Write-Host ""
    Write-Host "  Requesting Administrator rights (one prompt) so installs don't each ask separately ..." -ForegroundColor Cyan
    try {
        Start-Process -FilePath "powershell.exe" `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
            -Verb RunAs -ErrorAction Stop
        exit 0
    } catch {
        Write-Host "  [!!] Elevation was cancelled or failed - continuing without Administrator rights." -ForegroundColor Yellow
        Write-Host "       Some installs may show additional confirmation prompts." -ForegroundColor Yellow
    }
}

# ─── Header ──────────────────────────────────────────────────────────────────

Clear-Host
Write-Host ""
Write-Host "  +------------------------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |      Freeware Install Assistant  -  Windows                |" -ForegroundColor Cyan
Write-Host "  +------------------------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Platform: " -NoNewline
Write-Host "Windows  (winget)" -ForegroundColor Green

# ─── System information ─────────────────────────────────────────────────────

Abschnitt "System Information"
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
    Write-Host "  System info not available." -ForegroundColor DarkYellow
}

# ─── Programs ────────────────────────────────────────────────────────────────

# Firefox's default winget package (Mozilla.Firefox) is hardcoded to the
# en-US build; Mozilla publishes separate per-locale IDs (e.g.
# Mozilla.Firefox.de) instead of a runtime language switch. Every other
# catalog entry uses a language-neutral/MUI installer that already follows
# the Windows display language automatically, so only Firefox needs this.
$FirefoxID = if ((Get-UICulture).TwoLetterISOLanguageName -eq "de") { "Mozilla.Firefox.de" } else { "Mozilla.Firefox" }

$Programme = @(
    @{
        Name  = "Firefox"
        ID    = $FirefoxID
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

# ─── Check installation status ──────────────────────────────────────────────

Abschnitt "Installation Status"
Write-Host ""

$Fehlend = [System.Collections.ArrayList]::new()

foreach ($p in $Programme) {
    Write-Host "  Checking $($p.Name) ..." -NoNewline -ForegroundColor DarkGray
    $ok = (Pruefe-Pfade $p.Pfade) -or (Pruefe-Winget $p.ID)
    if ($ok) {
        Write-Host "`r  [OK] $($p.Name.PadRight(24)) installed             " -ForegroundColor Green
    } else {
        Write-Host "`r  [--] $($p.Name.PadRight(24)) not installed         " -ForegroundColor Red
        [void]$Fehlend.Add($p)
    }
}

# Check Python versions
Write-Host ""
Write-Host "  Python versions:" -ForegroundColor White
Write-Host ""

$PyOk    = [System.Collections.ArrayList]::new()
$PyFehlt = [System.Collections.ArrayList]::new()

foreach ($ver in $PythonVersionen) {
    $gefunden = $false

    # Quick check via the Python launcher (py.exe)
    if (-not $gefunden -and (Get-Command py -ErrorAction SilentlyContinue)) {
        $pyOut = (& py --list 2>&1) -join " "
        if ($pyOut -match $ver) { $gefunden = $true }
    }

    # Fallback: winget list
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

# ─── Select programs to install ─────────────────────────────────────────────

$AusgewaehlteProgramme = [System.Collections.ArrayList]::new()

if ($Fehlend.Count -gt 0) {
    Abschnitt "Select Programs"
    Write-Host ""
    Write-Host "  The following programs are not yet installed:" -ForegroundColor White
    Write-Host ""
    for ($i = 0; $i -lt $Fehlend.Count; $i++) {
        Write-Host ("    [{0}]  {1}" -f ($i + 1), $Fehlend[$i].Name) -ForegroundColor Cyan
    }
    Write-Host ""
    Write-Host "  Input: comma-separated numbers (e.g. 1,3), 'all' or 'none'" -ForegroundColor DarkGray
    Write-Host ""

    :programmauswahl while ($true) {
        $eingabe = (Read-Host "  Selection").Trim()

        if ($eingabe -eq "" -or $eingabe -match "^(none|no|n)$") {
            break programmauswahl
        }
        if ($eingabe -match "^(all|a)$") {
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
                Write-Host "  Invalid input: '$n'" -ForegroundColor Red
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
    Write-Host "  All programs from the list are already installed." -ForegroundColor Green
}

# Python selection
$GewuenshtePython = $null
Write-Host ""

if ($PyFehlt.Count -gt 0) {
    Write-Host "  Available to install:" -ForegroundColor White
    for ($i = 0; $i -lt $PythonVersionen.Count; $i++) {
        $v = $PythonVersionen[$i]
        if ($PyFehlt -contains $v) {
            Write-Host "    [$($i + 1)]  Python $v" -ForegroundColor Cyan
        }
    }
    Write-Host "    [0]  Do not install Python" -ForegroundColor DarkGray
    Write-Host ""

    :pythonauswahl while ($true) {
        $eingabe = Read-Host "  Selection (enter a number)"
        if ($eingabe -eq "0" -or $eingabe -eq "") { break pythonauswahl }

        if ($eingabe -match "^\d+$") {
            $idx = [int]$eingabe - 1
            if ($idx -ge 0 -and $idx -lt $PythonVersionen.Count) {
                $v = $PythonVersionen[$idx]
                if ($PyFehlt -contains $v) {
                    $GewuenshtePython = $v
                    break pythonauswahl
                } elseif ($PyOk -contains $v) {
                    Write-Host "  Python $v is already installed." -ForegroundColor Yellow
                } else {
                    Write-Host "  Invalid selection." -ForegroundColor Red
                }
            } else {
                Write-Host "  Invalid number." -ForegroundColor Red
            }
        } else {
            Write-Host "  Please enter a number." -ForegroundColor Red
        }
    }
} else {
    Write-Host "  All Python versions are already installed." -ForegroundColor Green
}

# ─── Additional freeware ────────────────────────────────────────────────────

Abschnitt "Additional Freeware"
Write-Host ""

$ZusatzProgramme = [System.Collections.ArrayList]::new()
$antwortZusatz = Read-Host "  Install additional freeware that isn't on the list? (Y/N)"

if ($antwortZusatz -match "^[yY]$") {
    Write-Host ""
    Write-Host "  Look up the winget ID first with 'winget search <name>'." -ForegroundColor DarkGray
    Write-Host "  An empty program name ends the entry." -ForegroundColor DarkGray
    Write-Host ""
    while ($true) {
        $zName = Read-Host "  Program name"
        if ([string]::IsNullOrWhiteSpace($zName)) { break }

        $zID = Read-Host "  Winget ID for '$zName'"
        if ([string]::IsNullOrWhiteSpace($zID)) {
            Write-Host "  No ID given, skipping '$zName'." -ForegroundColor Yellow
            Write-Host ""
            continue
        }

        [void]$ZusatzProgramme.Add(@{ Name = $zName; ID = $zID })
        Write-Host "  [+] '$zName' ($zID) queued for installation" -ForegroundColor Green
        Write-Host ""
    }
}

# ─── Installation overview ──────────────────────────────────────────────────

Abschnitt "Installation Overview"
Write-Host ""

if ($AusgewaehlteProgramme.Count -eq 0 -and $null -eq $GewuenshtePython -and $ZusatzProgramme.Count -eq 0) {
    Write-Host "  Nothing was selected for installation." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "  Enter to exit"
    exit 0
}

foreach ($p in $AusgewaehlteProgramme) { Write-Host "  *  $($p.Name)" -ForegroundColor Red }
if ($null -ne $GewuenshtePython)       { Write-Host "  *  Python $GewuenshtePython" -ForegroundColor Red }
foreach ($z in $ZusatzProgramme)       { Write-Host "  *  $($z.Name)  (additional)" -ForegroundColor Red }

Write-Host ""
$antwort = Read-Host "  Install these programs now? (Y/N)"

if ($antwort -notmatch "^[yY]$") {
    Write-Host ""
    Write-Host "  Installation cancelled." -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

# ─── Installation ────────────────────────────────────────────────────────────

Abschnitt "Installation Running"
Write-Host ""

$Erfolg  = [System.Collections.ArrayList]::new()
$Fehler  = [System.Collections.ArrayList]::new()
$OkCodes = @(0, -1978335189, -1978335106, 3010)

foreach ($p in $AusgewaehlteProgramme) {
    Write-Host "  Installing $($p.Name) ..." -ForegroundColor Cyan
    $code = Winget-Installiere $p.ID
    if ($OkCodes -contains $code) {
        Write-Host "  [OK] $($p.Name) installed successfully" -ForegroundColor Green
        [void]$Erfolg.Add($p.Name)
    } else {
        Write-Host "  [!!] $($p.Name) failed  (code: $code)" -ForegroundColor Red
        [void]$Fehler.Add($p.Name)
    }
    Write-Host ""
}

if ($null -ne $GewuenshtePython) {
    $pyID = $PythonIDs[$GewuenshtePython]
    Write-Host "  Installing Python $GewuenshtePython ..." -ForegroundColor Cyan
    $code = Winget-Installiere $pyID
    if ($OkCodes -contains $code) {
        Write-Host "  [OK] Python $GewuenshtePython installed successfully" -ForegroundColor Green
        [void]$Erfolg.Add("Python $GewuenshtePython")
    } else {
        Write-Host "  [!!] Python $GewuenshtePython failed  (code: $code)" -ForegroundColor Red
        [void]$Fehler.Add("Python $GewuenshtePython")
    }
    Write-Host ""
}

foreach ($z in $ZusatzProgramme) {
    Write-Host "  Installing $($z.Name) ..." -ForegroundColor Cyan
    $code = Winget-Installiere $z.ID
    if ($OkCodes -contains $code) {
        Write-Host "  [OK] $($z.Name) installed successfully" -ForegroundColor Green
        [void]$Erfolg.Add($z.Name)
    } else {
        Write-Host "  [!!] $($z.Name) failed  (code: $code)" -ForegroundColor Red
        [void]$Fehler.Add($z.Name)
    }
    Write-Host ""
}

# ─── Final report ────────────────────────────────────────────────────────────

Abschnitt "Final Report"
Write-Host ""

if ($Erfolg.Count -gt 0) {
    Write-Host "  Installed successfully:" -ForegroundColor Green
    foreach ($n in $Erfolg) { Write-Host "    [OK] $n" -ForegroundColor Green }
    Write-Host ""
}

if ($Fehler.Count -gt 0) {
    Write-Host "  Failed:" -ForegroundColor Red
    foreach ($n in $Fehler) { Write-Host "    [!!] $n" -ForegroundColor Red }
    Write-Host ""
    Write-Host "  Tip: run the script as Administrator or" -ForegroundColor Yellow
    Write-Host "       check your internet connection." -ForegroundColor Yellow
    Write-Host ""
}

if ($Fehler.Count -eq 0) {
    Write-Host "  All installations completed successfully!" -ForegroundColor Green
}

Write-Host ""
Write-Host ("  " + ("-" * 56)) -ForegroundColor DarkGray
Write-Host ""
Read-Host "  Enter to exit"
