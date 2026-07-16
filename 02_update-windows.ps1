#Requires -Version 5.1
# Program Update - Windows
# Updates only the catalog programs from 01_install-windows.ps1 (via winget
# upgrade), not every winget package installed on the machine.
# Can be run manually or register itself as a weekly task in the Windows
# Task Scheduler (-Register), which then runs unattended via -Silent.
# -Register copies this file to a stable per-user location first (see
# $StabilesSkript below), so the scheduled task keeps working even if the
# cloned repo folder it was originally run from gets deleted or moved.
# -Status shows whether the weekly task is registered and its last/next run.
# -Unregister removes the task and the stable copy again.

param(
    [switch]$Silent,
    [switch]$Register,
    [switch]$Unregister,
    [switch]$Status
)

$ProgressPreference    = "SilentlyContinue"
$ErrorActionPreference = "Continue"

$AufgabenName   = "install-assistant - Weekly Program Update"
$StabileAblage  = Join-Path $env:LOCALAPPDATA "install-assistant"
$StabilesSkript = Join-Path $StabileAblage "02_update-windows.ps1"

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

$OkCodes             = @(0, -1978335189, -1978335106, 3010)
$NeustartCodes       = @(-1978335106, 3010)
$NichtInstalliertCode = -1978335212

function Winget-Aktualisiere([string]$ID) {
    $ausgabe = winget upgrade --id $ID --exact --silent `
        --accept-package-agreements --accept-source-agreements 2>&1
    if (($OkCodes -notcontains $LASTEXITCODE) -and ($LASTEXITCODE -ne $NichtInstalliertCode)) {
        Write-Host "  winget output:" -ForegroundColor DarkGray
        $ausgabe | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    }
    return $LASTEXITCODE
}

function Registriere-Aufgabe {
    try {
        New-Item -ItemType Directory -Path $StabileAblage -Force -ErrorAction Stop | Out-Null
        if ($PSCommandPath -ne $StabilesSkript) {
            Copy-Item -Path $PSCommandPath -Destination $StabilesSkript -Force -ErrorAction Stop
        }
    } catch {
        Write-Host "  [!!] Could not copy the script to $StabileAblage`: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }

    $aktion    = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$StabilesSkript`" -Silent"
    $trigger   = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 9am
    $settings  = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest

    try {
        Register-ScheduledTask -TaskName $AufgabenName -Action $aktion -Trigger $trigger `
            -Settings $settings -Principal $principal -Force -ErrorAction Stop | Out-Null
        return $true
    } catch {
        Write-Host "  [!!] Could not set up the task: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "       Please run this script as Administrator once." -ForegroundColor Yellow
        return $false
    }
}

# ─── Prerequisites ──────────────────────────────────────────────────────────

if ($env:OS -ne "Windows_NT") {
    Write-Host "ERROR: This script is Windows-only." -ForegroundColor Red
    exit 1
}

if ($Unregister) {
    if (Get-ScheduledTask -TaskName $AufgabenName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $AufgabenName -Confirm:$false
        Write-Host "  [OK] Weekly task removed." -ForegroundColor Green
    } else {
        Write-Host "  No weekly task found." -ForegroundColor Yellow
    }
    if (Test-Path $StabilesSkript) {
        Remove-Item -Path $StabilesSkript -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Removed the stable copy at $StabilesSkript" -ForegroundColor Green
    }
    exit 0
}

if ($Status) {
    $task = Get-ScheduledTask -TaskName $AufgabenName -ErrorAction SilentlyContinue
    if (-not $task) {
        Write-Host "  No weekly task registered." -ForegroundColor Yellow
        Write-Host "  Set one up with: .\02_update-windows.ps1 -Register" -ForegroundColor DarkGray
        exit 0
    }

    $info       = $task | Get-ScheduledTaskInfo
    $argumente  = $task.Actions | Select-Object -First 1 -ExpandProperty Arguments
    $skriptPfad = $null
    if ($argumente -match '-File\s+"([^"]+)"') { $skriptPfad = $Matches[1] }

    Write-Host "  [OK] Weekly task is registered: $AufgabenName" -ForegroundColor Green
    Write-Host "       State:       $($task.State)"
    Write-Host "       Script path: $skriptPfad"
    if ($skriptPfad -and -not (Test-Path $skriptPfad)) {
        Write-Host "       [!!] This file no longer exists - the task will fail silently until it's restored or removed with -Unregister." -ForegroundColor Red
    }
    Write-Host "       Last run:    $($info.LastRunTime)  (result code: $($info.LastTaskResult))"
    Write-Host "       Next run:    $($info.NextRunTime)"
    exit 0
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "  ERROR: winget not found." -ForegroundColor Red
    Write-Host "  Please install: https://aka.ms/getwinget" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

if ($Register) {
    if (Registriere-Aufgabe) {
        Write-Host "  [OK] Weekly task set up (every Monday, 9:00 AM)." -ForegroundColor Green
        Write-Host "       Running from a stable copy at: $StabilesSkript" -ForegroundColor DarkGray
    }
    exit 0
}

# ─── Header ──────────────────────────────────────────────────────────────────

if (-not $Silent) {
    Clear-Host
    Write-Host ""
    Write-Host "  +------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "  |      Program Update  -  Windows                            |" -ForegroundColor Cyan
    Write-Host "  +------------------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Updates only the catalog programs from 01_install-windows.ps1," -ForegroundColor DarkGray
    Write-Host "  not every winget package on this machine." -ForegroundColor DarkGray
}

# ─── Catalog (must be kept in sync with 01_install-windows.ps1) ───────────────

$Programme = @(
    @{ Name = "Firefox";              ID = "Mozilla.Firefox" }
    @{ Name = "Google Chrome";        ID = "Google.Chrome" }
    @{ Name = "Brave Browser";        ID = "Brave.Brave" }
    @{ Name = "Notepad++";            ID = "Notepad++.Notepad++" }
    @{ Name = "VLC";                  ID = "VideoLAN.VLC" }
    @{ Name = "7-Zip";                ID = "7zip.7zip" }
    @{ Name = "Adobe Acrobat Reader"; ID = "Adobe.Acrobat.Reader.64-bit" }
    @{ Name = "VS Code";              ID = "Microsoft.VisualStudioCode" }
    @{ Name = "Git";                  ID = "Git.Git" }
    @{ Name = "Python 3.10";          ID = "Python.Python.3.10" }
    @{ Name = "Python 3.11";          ID = "Python.Python.3.11" }
    @{ Name = "Python 3.12";          ID = "Python.Python.3.12" }
    @{ Name = "Python 3.13";          ID = "Python.Python.3.13" }
)

# ─── Update ──────────────────────────────────────────────────────────────────

Abschnitt "Update Running"
Write-Host ""

$Aktualisiert   = [System.Collections.ArrayList]::new()
$BereitsAktuell = [System.Collections.ArrayList]::new()
$Uebersprungen  = [System.Collections.ArrayList]::new()
$Fehler         = [System.Collections.ArrayList]::new()

foreach ($p in $Programme) {
    Write-Host "  Checking/updating $($p.Name) ..." -NoNewline -ForegroundColor DarkGray
    $code = Winget-Aktualisiere $p.ID

    if ($code -eq $NichtInstalliertCode) {
        Write-Host "`r  [--] $($p.Name.PadRight(24)) not installed         " -ForegroundColor DarkGray
        [void]$Uebersprungen.Add($p.Name)
    } elseif ($code -eq 0) {
        Write-Host "`r  [OK] $($p.Name.PadRight(24)) updated               " -ForegroundColor Green
        [void]$Aktualisiert.Add($p.Name)
    } elseif ($NeustartCodes -contains $code) {
        Write-Host "`r  [OK] $($p.Name.PadRight(24)) updated (reboot needed)" -ForegroundColor Green
        [void]$Aktualisiert.Add("$($p.Name) (reboot required)")
    } elseif ($OkCodes -contains $code) {
        Write-Host "`r  [OK] $($p.Name.PadRight(24)) already up to date    " -ForegroundColor Green
        [void]$BereitsAktuell.Add($p.Name)
    } else {
        Write-Host "`r  [!!] $($p.Name.PadRight(24)) failed (code: $code)" -ForegroundColor Red
        [void]$Fehler.Add($p.Name)
    }
}

# ─── Final report ────────────────────────────────────────────────────────────

Abschnitt "Final Report"
Write-Host ""

if ($Aktualisiert.Count -gt 0) {
    Write-Host "  Updated:" -ForegroundColor Green
    foreach ($n in $Aktualisiert) { Write-Host "    [OK] $n" -ForegroundColor Green }
    Write-Host ""
}

if ($BereitsAktuell.Count -gt 0) {
    Write-Host "  Already up to date: $($BereitsAktuell -join ', ')" -ForegroundColor DarkGray
    Write-Host ""
}

if ($Uebersprungen.Count -gt 0) {
    Write-Host "  Not installed (skipped): $($Uebersprungen -join ', ')" -ForegroundColor DarkGray
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
    Write-Host "  All updates completed successfully!" -ForegroundColor Green
}

# ─── Offer weekly execution ─────────────────────────────────────────────────

if (-not $Silent) {
    Write-Host ""
    Write-Host ("  " + ("-" * 56)) -ForegroundColor DarkGray

    if (Get-ScheduledTask -TaskName $AufgabenName -ErrorAction SilentlyContinue) {
        Write-Host ""
        Write-Host "  Note: weekly automatic execution is already set up." -ForegroundColor DarkGray
        Write-Host "        Check it with:  .\02_update-windows.ps1 -Status" -ForegroundColor DarkGray
        Write-Host "        Remove it with: .\02_update-windows.ps1 -Unregister" -ForegroundColor DarkGray
    } else {
        Write-Host ""
        $antwort = Read-Host "  Run this update automatically every week from now on? (Y/N)"
        if ($antwort -match "^[yY]$") {
            if (Registriere-Aufgabe) {
                Write-Host "  [OK] Weekly task set up (every Monday, 9:00 AM)." -ForegroundColor Green
                Write-Host "       Running from a stable copy at: $StabilesSkript" -ForegroundColor DarkGray
                Write-Host "       Remove it with: .\02_update-windows.ps1 -Unregister" -ForegroundColor DarkGray
            }
        }
    }

    Write-Host ""
    Read-Host "  Enter to exit"
}
