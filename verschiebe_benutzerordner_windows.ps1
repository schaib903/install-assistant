#Requires -Version 5.1
# Verschiebe-Benutzerordner - Windows
# Verschiebt Bilder/Downloads/Dokumente auf eine andere Partition.
# Eigenstaendiges Skript, getrennt vom Grundsetup (setup_assistent_windows.ps1).

$ProgressPreference    = "SilentlyContinue"
$ErrorActionPreference = "Continue"

# ─── Hilfsfunktionen ────────────────────────────────────────────────────────

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

# ─── Voraussetzungen ────────────────────────────────────────────────────────

if ($env:OS -ne "Windows_NT") {
    Write-Host "FEHLER: Dieses Skript ist nur fuer Windows." -ForegroundColor Red
    exit 1
}

# ─── Kopfzeile ──────────────────────────────────────────────────────────────

Clear-Host
Write-Host ""
Write-Host "  +------------------------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |      Verschiebe-Benutzerordner  -  Windows                 |" -ForegroundColor Cyan
Write-Host "  +------------------------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Hinweis: verschiebt echte Nutzerdaten (Bilder/Downloads/Dokumente)." -ForegroundColor DarkGray

# ─── Laufwerksuebersicht ────────────────────────────────────────────────────

Abschnitt "Laufwerksuebersicht"
Write-Host ""
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

# ─── Uebersicht ─────────────────────────────────────────────────────────────

Abschnitt "Verschiebungsuebersicht"
Write-Host ""

if ($OrdnerPlan.Count -eq 0) {
    Write-Host "  Es wurde nichts zur Ausfuehrung ausgewaehlt." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "  Enter zum Beenden"
    exit 0
}

foreach ($eintrag in $OrdnerPlan) { Write-Host "  *  Ordner verschieben: $($eintrag.Label)" -ForegroundColor Red }

Write-Host ""
$antwort = Read-Host "  Jetzt ausfuehren? (J/N)"

if ($antwort -notmatch "^[jJyY]$") {
    Write-Host ""
    Write-Host "  Abgebrochen." -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

# ─── Ausfuehrung: Ordner verschieben ────────────────────────────────────────

Abschnitt "Benutzerordner werden verschoben"
Write-Host ""

$Erfolg = [System.Collections.ArrayList]::new()
$Fehler = [System.Collections.ArrayList]::new()

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
}

if ($Fehler.Count -eq 0) {
    Write-Host "  Alles erfolgreich abgeschlossen!" -ForegroundColor Green
}

Write-Host ""
Write-Host ("  " + ("-" * 56)) -ForegroundColor DarkGray
Write-Host ""
Read-Host "  Enter zum Beenden"
