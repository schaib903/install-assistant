#Requires -Version 5.1
# Move User Folders - Windows
# Moves Pictures/Downloads/Documents to another partition.
# Standalone script, separate from the bootstrap (setup-windows.ps1).

$ProgressPreference    = "SilentlyContinue"
$ErrorActionPreference = "Continue"

# ─── Helper functions ───────────────────────────────────────────────────────

function Abschnitt([string]$Titel) {
    Write-Host ""
    Write-Host "  >> $Titel" -ForegroundColor Yellow
    Write-Host ("  " + ("-" * 54)) -ForegroundColor DarkGray
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

# ─── Prerequisites ──────────────────────────────────────────────────────────

if ($env:OS -ne "Windows_NT") {
    Write-Host "ERROR: This script is Windows-only." -ForegroundColor Red
    exit 1
}

# ─── Header ──────────────────────────────────────────────────────────────────

Clear-Host
Write-Host ""
Write-Host "  +------------------------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |      Move User Folders  -  Windows                         |" -ForegroundColor Cyan
Write-Host "  +------------------------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Note: moves real user data (Pictures/Downloads/Documents)." -ForegroundColor DarkGray

# ─── Drive overview ──────────────────────────────────────────────────────────

Abschnitt "Drive Overview"
Write-Host ""
try {
    Get-Volume | Where-Object { $_.DriveLetter } | Sort-Object DriveLetter | ForEach-Object {
        $freiGB    = [math]::Round($_.SizeRemaining / 1GB, 1)
        $groesseGB = [math]::Round($_.Size / 1GB, 1)
        Write-Host ("    {0}:\  {1,7} GB free  /  {2,7} GB total   {3}" -f `
            $_.DriveLetter, $freiGB, $groesseGB, $_.FileSystemLabel)
    }
} catch {
    Write-Host "  Drive info not available." -ForegroundColor DarkYellow
}

# ─── Move user folders: planning ────────────────────────────────────────────

Abschnitt "Move User Folders"
Write-Host ""

$OrdnerDefinitionen = @(
    @{ Label = "Pictures";  ShellName = "My Pictures"; RegName = "My Pictures" }
    @{ Label = "Downloads"; ShellName = "Downloads";   RegName = "{374DE290-123F-4565-9164-39C4925E467B}" }
    @{ Label = "Documents"; ShellName = "Personal";     RegName = "Personal" }
)

$OrdnerPlan = [System.Collections.ArrayList]::new()
$antwortOrdner = Read-Host "  Move Pictures, Downloads and Documents to another partition? (Y/N)"

if ($antwortOrdner -match "^[yY]$") {
    Write-Host ""
    $zielEingabe = (Read-Host "  Target folder (e.g. D:\Users)").Trim().TrimEnd('\')

    if ($zielEingabe.Length -lt 2 -or $zielEingabe[1] -ne ':') {
        Write-Host "  Invalid path, skipping the move." -ForegroundColor Red
    } else {
        $laufwerk = $zielEingabe.Substring(0, 2)

        if (-not (Test-Path "$laufwerk\")) {
            Write-Host "  Drive $laufwerk does not exist, skipping the move." -ForegroundColor Red
        } else {
            $GesamtGroesse = 0

            foreach ($def in $OrdnerDefinitionen) {
                $alterPfad = Get-BekannterOrdnerPfad $def.ShellName

                if ([string]::IsNullOrWhiteSpace($alterPfad) -or -not (Test-Path $alterPfad)) {
                    Write-Host "  [!!] $($def.Label): could not determine current path, skipping." -ForegroundColor Yellow
                    continue
                }

                $leafName  = Split-Path -Leaf $alterPfad
                $neuerPfad = Join-Path $zielEingabe $leafName

                if ($neuerPfad -eq $alterPfad) {
                    Write-Host "  [OK] $($def.Label) is already at the target location." -ForegroundColor Green
                    continue
                }

                # OneDrive may manage these folders itself - moving them manually
                # can conflict with its own synchronization.
                if ($alterPfad -like "*OneDrive*") {
                    Write-Host "  [!!] $($def.Label) is currently backed up via OneDrive:" -ForegroundColor Yellow
                    Write-Host "       $alterPfad" -ForegroundColor Yellow
                    Write-Host "       Moving it can conflict with OneDrive synchronization." -ForegroundColor Yellow
                    Write-Host "       Recommendation: disable OneDrive folder backup first." -ForegroundColor Yellow
                    $weiterOneDrive = Read-Host "  Move '$($def.Label)' anyway? (y/N)"
                    if ($weiterOneDrive -notmatch "^[yY]$") {
                        Write-Host "  Skipping $($def.Label)." -ForegroundColor DarkGray
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
                Write-Host "  Planned move:" -ForegroundColor White
                Write-Host ""
                foreach ($eintrag in $OrdnerPlan) {
                    $groesseGB = [math]::Round($eintrag.Groesse / 1GB, 2)
                    Write-Host ("    {0,-10} {1}  ->  {2}   (~{3} GB)" -f `
                        $eintrag.Label, $eintrag.AlterPfad, $eintrag.NeuerPfad, $groesseGB) -ForegroundColor Cyan
                }
                Write-Host ""
                Write-Host ("  Total disk space required: ~{0} GB" -f ([math]::Round($GesamtGroesse / 1GB, 2)))

                if ($null -ne $freierPlatz -and ($GesamtGroesse * 1.1) -gt $freierPlatz) {
                    Write-Host ("  [!!] Not enough free space on {0} (free: {1} GB). Skipping the move." -f `
                        $laufwerk, [math]::Round($freierPlatz / 1GB, 1)) -ForegroundColor Red
                    $OrdnerPlan.Clear()
                }
            } else {
                Write-Host "  There is nothing to move." -ForegroundColor Yellow
            }
        }
    }
}

# ─── Overview ────────────────────────────────────────────────────────────────

Abschnitt "Move Overview"
Write-Host ""

if ($OrdnerPlan.Count -eq 0) {
    Write-Host "  Nothing was selected to run." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "  Enter to exit"
    exit 0
}

foreach ($eintrag in $OrdnerPlan) { Write-Host "  *  Move folder: $($eintrag.Label)" -ForegroundColor Red }

Write-Host ""
$antwort = Read-Host "  Run this now? (Y/N)"

if ($antwort -notmatch "^[yY]$") {
    Write-Host ""
    Write-Host "  Cancelled." -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

# ─── Execution: move folders ─────────────────────────────────────────────────

Abschnitt "Moving User Folders"
Write-Host ""

$Erfolg = [System.Collections.ArrayList]::new()
$Fehler = [System.Collections.ArrayList]::new()

$UserShellFolders = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
$ShellFolders     = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders"
$mindEinErfolg    = $false

foreach ($eintrag in $OrdnerPlan) {
    Write-Host "  Moving $($eintrag.Label) ..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $eintrag.NeuerPfad -Force | Out-Null

    robocopy $eintrag.AlterPfad $eintrag.NeuerPfad /E /MOVE /R:1 /W:1 /NFL /NDL /NJH /NJS | Out-Null
    $rcCode = $LASTEXITCODE

    if ($rcCode -lt 8) {
        Set-ItemProperty -Path $UserShellFolders -Name $eintrag.RegName -Value $eintrag.NeuerPfad -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $ShellFolders     -Name $eintrag.RegName -Value $eintrag.NeuerPfad -ErrorAction SilentlyContinue
        Write-Host "  [OK] $($eintrag.Label) moved successfully" -ForegroundColor Green
        [void]$Erfolg.Add("Folder: $($eintrag.Label)")
        $mindEinErfolg = $true
    } else {
        Write-Host "  [!!] $($eintrag.Label) failed  (robocopy code: $rcCode)" -ForegroundColor Red
        [void]$Fehler.Add("Folder: $($eintrag.Label)")
    }
    Write-Host ""
}

if ($mindEinErfolg) {
    Write-Host "  Restarting Explorer so the new paths take effect ..." -ForegroundColor DarkGray
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    Start-Process explorer.exe
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
}

if ($Fehler.Count -eq 0) {
    Write-Host "  Everything completed successfully!" -ForegroundColor Green
}

Write-Host ""
Write-Host ("  " + ("-" * 56)) -ForegroundColor DarkGray
Write-Host ""
Read-Host "  Enter to exit"
