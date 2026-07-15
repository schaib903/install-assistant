#Requires -Version 5.1
# Setup Assistant - Windows Bootstrap
# Bootstrap: winget, Git, GitHub CLI (sign in + clone install-assistant),
# Claude Code CLI. Moving user folders (Pictures/Downloads/Documents) is a
# separate script: move-user-folders-windows.ps1

$ProgressPreference    = "SilentlyContinue"
$ErrorActionPreference = "Continue"

$GitHubRepoName  = "install-assistant"
$OkCodes         = @(0, -1978335189, -1978335106, 3010)

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
    $ausgabe = winget install --id $ID --exact --silent `
        --accept-package-agreements --accept-source-agreements 2>&1
    if ($OkCodes -notcontains $LASTEXITCODE) {
        Write-Host "  winget output:" -ForegroundColor DarkGray
        $ausgabe | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    }
    return $LASTEXITCODE
}

function Aktualisiere-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function Installiere-Winget {
    Write-Host "  Trying to register winget ..." -ForegroundColor Cyan
    try {
        Add-AppxPackage -RegisterByFamilyName `
            -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction Stop
    } catch { }

    Aktualisiere-Path
    if (Get-Command winget -ErrorAction SilentlyContinue) { return $true }

    Write-Host "  Downloading App Installer (winget) from GitHub ..." -ForegroundColor Cyan
    $tmp    = Join-Path $env:TEMP "winget-setup"
    $bundle = Join-Path $tmp "DesktopAppInstaller.msixbundle"
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null

    try {
        Invoke-WebRequest -UseBasicParsing `
            -Uri "https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle" `
            -OutFile $bundle
        Add-AppxPackage -Path $bundle -ErrorAction Stop
    } catch {
        Write-Host "  [!!] Automatic winget installation failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "       Possible cause: missing dependency (Microsoft.VCLibs / Microsoft.UI.Xaml)." -ForegroundColor Yellow
        Write-Host "       Please install manually: https://aka.ms/getwinget" -ForegroundColor Yellow
        return $false
    } finally {
        Remove-Item -Path $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }

    Aktualisiere-Path
    if (Get-Command winget -ErrorAction SilentlyContinue) { return $true }

    Write-Host "  [!!] winget was installed but isn't available in this session yet." -ForegroundColor Yellow
    Write-Host "       Please restart the terminal and re-run the script." -ForegroundColor Yellow
    return $false
}

function Hole-Repo([string]$ZielVerzeichnis) {
    if (Test-Path $ZielVerzeichnis) {
        Write-Host "  [OK] Repo folder already exists: $ZielVerzeichnis" -ForegroundColor Green
        return $true
    }

    gh auth status *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  GitHub sign-in required - follow the instructions in the terminal/browser ..." -ForegroundColor Cyan
        gh auth login
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  [!!] GitHub sign-in failed or was cancelled" -ForegroundColor Red
            return $false
        }
    }

    $besitzer = gh api user --jq ".login" 2>&1
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($besitzer)) {
        Write-Host "  [!!] Could not determine the GitHub username" -ForegroundColor Red
        return $false
    }

    gh repo clone "$besitzer/$GitHubRepoName" $ZielVerzeichnis
    return ($LASTEXITCODE -eq 0)
}

# ─── Prerequisites ──────────────────────────────────────────────────────────

if ($env:OS -ne "Windows_NT") {
    Write-Host "ERROR: This script is Windows-only." -ForegroundColor Red
    exit 1
}

# ─── Header ──────────────────────────────────────────────────────────────────

Clear-Host
Write-Host ""
Write-Host "  +------------------------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |      Setup Assistant  -  Windows Bootstrap                 |" -ForegroundColor Cyan
Write-Host "  +------------------------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Note: for system-wide installations, run as Administrator if needed." -ForegroundColor DarkGray

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

# ─── Bootstrap: check status ────────────────────────────────────────────────

Abschnitt "Bootstrap Status"
Write-Host ""

$GrundsetupKandidaten = @(
    @{ Name = "winget (Windows Package Manager)";           Key = "winget" }
    @{ Name = "Git";                                        Key = "git" }
    @{ Name = "GitHub CLI (gh)";                            Key = "gh" }
    @{ Name = "install-assistant repo (sign-in + clone)";   Key = "repo" }
    @{ Name = "Claude Code CLI";                            Key = "claude" }
)

$GrundsetupFehlend = [System.Collections.ArrayList]::new()

foreach ($k in $GrundsetupKandidaten) {
    Write-Host "  Checking $($k.Name) ..." -NoNewline -ForegroundColor DarkGray

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
        "gh"     {
            [bool](Get-Command gh -ErrorAction SilentlyContinue) -or
            ((Get-Command winget -ErrorAction SilentlyContinue) -and (Pruefe-Winget "GitHub.cli"))
        }
        "repo"   {
            (Test-Path (Join-Path $PSScriptRoot "install-windows.ps1")) -or
            (Test-Path (Join-Path $PSScriptRoot $GitHubRepoName))
        }
        "claude" {
            [bool](Get-Command claude -ErrorAction SilentlyContinue) -or
            ((Get-Command winget -ErrorAction SilentlyContinue) -and (Pruefe-Winget "Anthropic.ClaudeCode"))
        }
    }

    if ($ok) {
        Write-Host "`r  [OK] $($k.Name.PadRight(32)) installed             " -ForegroundColor Green
    } else {
        Write-Host "`r  [--] $($k.Name.PadRight(32)) not installed         " -ForegroundColor Red
        [void]$GrundsetupFehlend.Add($k)
    }
}

# ─── Bootstrap: selection ───────────────────────────────────────────────────

$GrundsetupAusgewaehlt = [System.Collections.ArrayList]::new()

if ($GrundsetupFehlend.Count -gt 0) {
    Abschnitt "Select Bootstrap Items"
    Write-Host ""
    Write-Host "  The following components are not yet installed:" -ForegroundColor White
    Write-Host ""
    for ($i = 0; $i -lt $GrundsetupFehlend.Count; $i++) {
        Write-Host ("    [{0}]  {1}" -f ($i + 1), $GrundsetupFehlend[$i].Name) -ForegroundColor Cyan
    }
    Write-Host ""
    Write-Host "  Input: comma-separated numbers (e.g. 1,3), 'all' or 'none'" -ForegroundColor DarkGray
    Write-Host ""

    :grundsetupauswahl while ($true) {
        $eingabe = (Read-Host "  Selection").Trim()

        if ($eingabe -eq "" -or $eingabe -match "^(none|no|n)$") {
            break grundsetupauswahl
        }
        if ($eingabe -match "^(all|a)$") {
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
                Write-Host "  Invalid input: '$n'" -ForegroundColor Red
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
    Write-Host "  Bootstrap is already fully installed." -ForegroundColor Green
}

$AusgewaehlteKeys = $GrundsetupAusgewaehlt | ForEach-Object { $_.Key }

# ─── Installation overview ──────────────────────────────────────────────────

Abschnitt "Installation Overview"
Write-Host ""

if ($GrundsetupAusgewaehlt.Count -eq 0) {
    Write-Host "  Nothing was selected to run." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "  Enter to exit"
    exit 0
}

foreach ($k in $GrundsetupAusgewaehlt) { Write-Host "  *  $($k.Name)" -ForegroundColor Red }

Write-Host ""
$antwort = Read-Host "  Run this now? (Y/N)"

if ($antwort -notmatch "^[yY]$") {
    Write-Host ""
    Write-Host "  Cancelled." -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

# ─── Execution: bootstrap ───────────────────────────────────────────────────

Abschnitt "Setting Up Bootstrap"
Write-Host ""

$Erfolg  = [System.Collections.ArrayList]::new()
$Fehler  = [System.Collections.ArrayList]::new()

if ($AusgewaehlteKeys -contains "winget") {
    Write-Host "  Installing winget ..." -ForegroundColor Cyan
    if (Installiere-Winget) {
        Write-Host "  [OK] winget set up successfully" -ForegroundColor Green
        [void]$Erfolg.Add("winget")
    } else {
        Write-Host "  [!!] winget setup failed" -ForegroundColor Red
        [void]$Fehler.Add("winget")
    }
    Write-Host ""
}

if ($AusgewaehlteKeys -contains "git") {
    Write-Host "  Installing Git ..." -ForegroundColor Cyan
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "  [!!] Git failed: winget not available" -ForegroundColor Red
        [void]$Fehler.Add("Git")
    } else {
        $code = Winget-Installiere "Git.Git"
        if ($OkCodes -contains $code) {
            Write-Host "  [OK] Git installed successfully" -ForegroundColor Green
            [void]$Erfolg.Add("Git")
            Aktualisiere-Path
        } else {
            Write-Host "  [!!] Git failed  (code: $code)" -ForegroundColor Red
            [void]$Fehler.Add("Git")
        }
    }
    Write-Host ""
}

if ($AusgewaehlteKeys -contains "gh") {
    Write-Host "  Installing GitHub CLI ..." -ForegroundColor Cyan
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "  [!!] GitHub CLI failed: winget not available" -ForegroundColor Red
        [void]$Fehler.Add("GitHub CLI")
    } else {
        $code = Winget-Installiere "GitHub.cli"
        if ($OkCodes -contains $code) {
            Write-Host "  [OK] GitHub CLI installed successfully" -ForegroundColor Green
            [void]$Erfolg.Add("GitHub CLI")
            Aktualisiere-Path
        } else {
            Write-Host "  [!!] GitHub CLI failed  (code: $code)" -ForegroundColor Red
            [void]$Fehler.Add("GitHub CLI")
        }
    }
    Write-Host ""
}

if ($AusgewaehlteKeys -contains "repo") {
    Write-Host "  Signing in to GitHub and cloning install-assistant ..." -ForegroundColor Cyan
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Host "  [!!] Repo clone failed: gh (GitHub CLI) not available" -ForegroundColor Red
        [void]$Fehler.Add("install-assistant repo")
    } else {
        $ziel = Join-Path $PSScriptRoot $GitHubRepoName
        if (Hole-Repo $ziel) {
            Write-Host "  [OK] Repo available at $ziel" -ForegroundColor Green
            [void]$Erfolg.Add("install-assistant repo")
        } else {
            Write-Host "  [!!] Repo clone failed" -ForegroundColor Red
            [void]$Fehler.Add("install-assistant repo")
        }
    }
    Write-Host ""
}

if ($AusgewaehlteKeys -contains "claude") {
    Write-Host "  Installing Claude Code CLI ..." -ForegroundColor Cyan
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "  [!!] Claude Code CLI failed: winget not available" -ForegroundColor Red
        [void]$Fehler.Add("Claude Code CLI")
    } else {
        $code = Winget-Installiere "Anthropic.ClaudeCode"
        if ($OkCodes -contains $code) {
            Write-Host "  [OK] Claude Code CLI installed successfully" -ForegroundColor Green
            [void]$Erfolg.Add("Claude Code CLI")
            Aktualisiere-Path
        } else {
            Write-Host "  [!!] Claude Code CLI failed  (code: $code)" -ForegroundColor Red
            [void]$Fehler.Add("Claude Code CLI")
        }
    }
    Write-Host ""
}

# ─── Final report ────────────────────────────────────────────────────────────

Abschnitt "Final Report"
Write-Host ""

if ($Erfolg.Count -gt 0) {
    Write-Host "  Successful:" -ForegroundColor Green
    foreach ($n in $Erfolg) { Write-Host "    [OK] $n" -ForegroundColor Green }
    Write-Host ""
}

if ($Fehler.Count -gt 0) {
    Write-Host "  Failed:" -ForegroundColor Red
    foreach ($n in $Fehler) { Write-Host "    [!!] $n" -ForegroundColor Red }
    Write-Host ""
    Write-Host "  Tip: restart the terminal (PATH refresh), check Administrator rights," -ForegroundColor Yellow
    Write-Host "       or check your internet connection." -ForegroundColor Yellow
    Write-Host ""
}

if ($Fehler.Count -eq 0) {
    Write-Host "  Everything completed successfully!" -ForegroundColor Green
}

Write-Host ""
Write-Host ("  " + ("-" * 56)) -ForegroundColor DarkGray
Write-Host ""
Read-Host "  Enter to exit"
