#!/usr/bin/env bash
# Freeware Installationsassistent - Linux (Debian/Ubuntu)
# Benoetigt: apt, sudo
# Hinweis: Datei muss Unix-Zeilenenden (LF) haben. Unter Windows:
#   Konvertierung mit: dos2unix install_assist_linux.sh
#   Oder: sed -i 's/\r//' install_assist_linux.sh

# ─── Farben ─────────────────────────────────────────────────────────────────

ROT='\033[0;31m'
GRUEN='\033[0;32m'
GELB='\033[1;33m'
CYAN='\033[0;36m'
WEISS='\033[1;37m'
GRAU='\033[0;90m'
RESET='\033[0m'

# ─── Hilfsfunktionen ────────────────────────────────────────────────────────

abschnitt() {
    echo ""
    echo -e "  ${GELB}► $1${RESET}"
    echo -e "  ${GRAU}$(printf '%0.s─' {1..54})${RESET}"
}

ist_installiert() {
    command -v "$1" &>/dev/null
}

paket_installiert() {
    dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

# ─── Voraussetzungen ────────────────────────────────────────────────────────

if [[ "$(uname -s)" != "Linux" ]]; then
    echo -e "${ROT}FEHLER: Dieses Skript ist nur fuer Linux geeignet.${RESET}"
    exit 1
fi

if ! command -v apt-get &>/dev/null; then
    echo -e "${ROT}FEHLER: apt-get nicht gefunden. Benoetigt Debian/Ubuntu.${RESET}"
    exit 1
fi

if ! grep -qiE 'ubuntu|debian|linuxmint|pop' /etc/os-release 2>/dev/null; then
    echo -e "${GELB}WARNUNG: Moeglichweise kein Debian/Ubuntu-System erkannt.${RESET}"
    echo -e "${GELB}         Fortfahren auf eigenes Risiko.${RESET}"
fi

# ─── Kopfzeile ──────────────────────────────────────────────────────────────

clear
echo ""
echo -e "  ${CYAN}+──────────────────────────────────────────────────────────+${RESET}"
echo -e "  ${CYAN}│       Freeware Installationsassistent  ·  Linux           │${RESET}"
echo -e "  ${CYAN}+──────────────────────────────────────────────────────────+${RESET}"
echo ""
echo -e "  Plattform: ${GRUEN}Linux  (apt)${RESET}"

# ─── Systeminformationen ────────────────────────────────────────────────────

abschnitt "Systeminformationen"
echo ""

HOSTNAME_V=$(hostname 2>/dev/null || echo "unbekannt")
OS_V=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "Linux")
RAM_V=$(awk '/MemTotal/ {printf "%.1f GB", $2/1024/1024}' /proc/meminfo 2>/dev/null || echo "n/a")
CPU_V=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d':' -f2 | xargs || echo "n/a")

printf "  %-12s %s\n" "Hostname:"  "$HOSTNAME_V"
printf "  %-12s %s\n" "System:"    "$OS_V"
printf "  %-12s %s\n" "RAM:"       "$RAM_V"
printf "  %-12s %s\n" "CPU:"       "$CPU_V"

# ─── Programmdefinitionen ───────────────────────────────────────────────────
# Format: PROG_NAMEN[i], PROG_CMDS[i], PROG_PAKETE[i], PROG_SONDER[i]
# PROG_SONDER: "" = normales apt, "chrome" = Google Chrome, "vscode" = VS Code,
#              "brave" = Brave Browser
# Hinweis: Adobe Acrobat Reader wird hier bewusst nicht angeboten - Adobe
# stellt seit Jahren keinen offiziellen Reader fuer Linux mehr bereit
# (nur Windows, siehe install_assist_windows.ps1).

PROG_NAMEN=("Firefox" "Google Chrome" "Brave Browser" "VLC" "7-Zip" "VS Code" "Git")
PROG_CMDS=( "firefox" "google-chrome" "brave-browser"  "vlc" "7z"   "code"    "git")
PROG_PAKETE=("firefox" "google-chrome-stable" "brave-browser" "vlc" "p7zip-full" "code" "git")
PROG_SONDER=("" "chrome" "brave" "" "" "vscode" "")

PYTHON_VERSIONEN=("3.10" "3.11" "3.12" "3.13")

# ─── Installationsstatus pruefen ────────────────────────────────────────────

abschnitt "Installationsstatus"
echo ""

FEHLENDE_NAMEN=()
FEHLENDE_PAKETE=()
FEHLENDE_SONDER=()

for i in "${!PROG_NAMEN[@]}"; do
    name="${PROG_NAMEN[$i]}"
    cmd="${PROG_CMDS[$i]}"
    printf "  Pruefe %-22s ..." "$name"
    if ist_installiert "$cmd" || paket_installiert "${PROG_PAKETE[$i]}"; then
        printf "\r  [✅] %-22s installiert          \n" "$name"
    else
        printf "\r  [❌] %-22s nicht installiert    \n" "$name"
        FEHLENDE_NAMEN+=("$name")
        FEHLENDE_PAKETE+=("${PROG_PAKETE[$i]}")
        FEHLENDE_SONDER+=("${PROG_SONDER[$i]}")
    fi
done

# Python-Versionen pruefen
echo ""
echo -e "  ${WEISS}Python-Versionen:${RESET}"
echo ""

PY_OK=()
PY_FEHLT=()

for ver in "${PYTHON_VERSIONEN[@]}"; do
    if ist_installiert "python${ver}" || paket_installiert "python${ver}"; then
        PY_OK+=("$ver")
        printf "  [✅] Python %s\n" "$ver"
    else
        PY_FEHLT+=("$ver")
        echo -e "  ${ROT}[❌] Python ${ver}${RESET}"
    fi
done

# ─── Auswahl der zu installierenden Programme ──────────────────────────────

AUSGEWAEHLT_NAMEN=()
AUSGEWAEHLT_PAKETE=()
AUSGEWAEHLT_SONDER=()

if [[ ${#FEHLENDE_NAMEN[@]} -gt 0 ]]; then
    abschnitt "Auswahl der Programme"
    echo ""
    echo -e "  Folgende Programme sind noch nicht installiert:"
    echo ""
    for i in "${!FEHLENDE_NAMEN[@]}"; do
        echo -e "    ${CYAN}[$((i+1))]  ${FEHLENDE_NAMEN[$i]}${RESET}"
    done
    echo ""
    echo -e "  ${GRAU}Eingabe: Nummern durch Komma getrennt (z.B. 1,3), 'alle' oder 'keine'${RESET}"
    echo ""

    while true; do
        read -rp "  Auswahl: " eingabe
        eingabe="$(echo "$eingabe" | xargs)"

        if [[ -z "$eingabe" || "$eingabe" =~ ^(keine|nein|n)$ ]]; then
            break
        fi

        if [[ "$eingabe" =~ ^(alle|a)$ ]]; then
            AUSGEWAEHLT_NAMEN=("${FEHLENDE_NAMEN[@]}")
            AUSGEWAEHLT_PAKETE=("${FEHLENDE_PAKETE[@]}")
            AUSGEWAEHLT_SONDER=("${FEHLENDE_SONDER[@]}")
            break
        fi

        gueltig=true
        tmp_namen=()
        tmp_pakete=()
        tmp_sonder=()

        IFS=',' read -ra nummern <<< "$eingabe"
        for n in "${nummern[@]}"; do
            n="$(echo "$n" | xargs)"
            if [[ "$n" =~ ^[0-9]+$ ]] && [[ $n -ge 1 ]] && [[ $n -le ${#FEHLENDE_NAMEN[@]} ]]; then
                idx=$((n-1))
                tmp_namen+=("${FEHLENDE_NAMEN[$idx]}")
                tmp_pakete+=("${FEHLENDE_PAKETE[$idx]}")
                tmp_sonder+=("${FEHLENDE_SONDER[$idx]}")
            else
                echo -e "  ${ROT}Ungueltige Eingabe: '$n'${RESET}"
                gueltig=false
                break
            fi
        done

        if $gueltig; then
            AUSGEWAEHLT_NAMEN=("${tmp_namen[@]}")
            AUSGEWAEHLT_PAKETE=("${tmp_pakete[@]}")
            AUSGEWAEHLT_SONDER=("${tmp_sonder[@]}")
            break
        fi
    done
else
    echo ""
    echo -e "  ${GRUEN}Alle Programme aus der Liste sind bereits installiert.${RESET}"
fi

# Python-Auswahl
GEWUENSCHTE_PYTHON=""
echo ""

if [[ ${#PY_FEHLT[@]} -gt 0 ]]; then
    echo -e "  Zur Installation verfuegbar:"
    for i in "${!PYTHON_VERSIONEN[@]}"; do
        ver="${PYTHON_VERSIONEN[$i]}"
        for f in "${PY_FEHLT[@]}"; do
            if [[ "$f" == "$ver" ]]; then
                echo -e "    ${CYAN}[$((i+1))]  Python ${ver}${RESET}"
                break
            fi
        done
    done
    echo -e "    ${GRAU}[0]  Kein Python installieren${RESET}"
    echo ""

    while true; do
        read -rp "  Auswahl (Nummer eingeben): " auswahl
        [[ "$auswahl" == "0" || -z "$auswahl" ]] && break

        if [[ "$auswahl" =~ ^[0-9]+$ ]] && \
           [[ $auswahl -ge 1 ]] && [[ $auswahl -le ${#PYTHON_VERSIONEN[@]} ]]; then
            ver="${PYTHON_VERSIONEN[$((auswahl-1))]}"
            ist_fehlend=false
            for f in "${PY_FEHLT[@]}"; do [[ "$f" == "$ver" ]] && ist_fehlend=true && break; done

            if $ist_fehlend; then
                GEWUENSCHTE_PYTHON="$ver"
                break
            else
                echo -e "  ${GELB}Python ${ver} ist bereits installiert.${RESET}"
            fi
        else
            echo -e "  ${ROT}Ungueltige Eingabe. Bitte eine Zahl eingeben.${RESET}"
        fi
    done
else
    echo -e "  ${GRUEN}Alle Python-Versionen sind bereits installiert.${RESET}"
fi

# ─── Zusaetzliche Freeware ──────────────────────────────────────────────────

abschnitt "Zusaetzliche Freeware"
echo ""

ZUSATZ_NAMEN=()
ZUSATZ_PAKETE=()

read -rp "  Weitere Freeware installieren, die nicht in der Liste steht? (J/N): " antwort_zusatz
echo ""

if [[ "$antwort_zusatz" =~ ^[jJyY]$ ]]; then
    echo -e "  ${GRAU}apt-Paketname vorher mit 'apt-cache search <Name>' ermitteln.${RESET}"
    echo -e "  ${GRAU}Leere Eingabe beim Programmnamen beendet die Erfassung.${RESET}"
    echo ""
    while true; do
        read -rp "  Programmname: " z_name
        [[ -z "$z_name" ]] && break

        read -rp "  apt-Paketname fuer '$z_name': " z_paket
        if [[ -z "$z_paket" ]]; then
            echo -e "  ${GELB}Kein Paketname angegeben, '$z_name' wird uebersprungen.${RESET}"
            echo ""
            continue
        fi

        ZUSATZ_NAMEN+=("$z_name")
        ZUSATZ_PAKETE+=("$z_paket")
        echo -e "  ${GRUEN}[+] '$z_name' ($z_paket) wird zur Installation vorgemerkt${RESET}"
        echo ""
    done
fi

# ─── Installationsuebersicht ────────────────────────────────────────────────

abschnitt "Installationsuebersicht"
echo ""

if [[ ${#AUSGEWAEHLT_NAMEN[@]} -eq 0 && -z "$GEWUENSCHTE_PYTHON" && ${#ZUSATZ_NAMEN[@]} -eq 0 ]]; then
    echo -e "  ${GELB}Es wurde nichts zur Installation ausgewaehlt.${RESET}"
    echo ""
    exit 0
fi

for name in "${AUSGEWAEHLT_NAMEN[@]}"; do
    echo -e "  ${ROT}•  $name${RESET}"
done
[[ -n "$GEWUENSCHTE_PYTHON" ]] && echo -e "  ${ROT}•  Python $GEWUENSCHTE_PYTHON${RESET}"
for name in "${ZUSATZ_NAMEN[@]}"; do
    echo -e "  ${ROT}•  $name  (zusaetzlich)${RESET}"
done

echo ""
read -rp "  Diese Programme jetzt installieren? (J/N): " antwort
echo ""

if [[ ! "$antwort" =~ ^[jJyY]$ ]]; then
    echo -e "  ${GELB}Installation abgebrochen.${RESET}"
    echo ""
    exit 0
fi

# ─── Sudo-Check ─────────────────────────────────────────────────────────────

if ! sudo -v 2>/dev/null; then
    echo -e "  ${ROT}FEHLER: sudo-Berechtigungen erforderlich.${RESET}"
    exit 1
fi

# ─── Installationsfunktionen ─────────────────────────────────────────────────

installiere_chrome() {
    local tmp; tmp=$(mktemp -d)
    echo -e "  ${CYAN}  Lade Google Chrome herunter ...${RESET}"
    if command -v wget &>/dev/null; then
        wget -q "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" \
             -O "${tmp}/chrome.deb" || return 1
    elif command -v curl &>/dev/null; then
        curl -sL "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" \
             -o "${tmp}/chrome.deb" || return 1
    else
        echo -e "  ${ROT}  wget/curl nicht gefunden.${RESET}"
        return 1
    fi
    sudo dpkg -i "${tmp}/chrome.deb" 2>/dev/null || true
    sudo apt-get install -f -y -qq 2>/dev/null
    rm -rf "$tmp"
    ist_installiert "google-chrome" || ist_installiert "google-chrome-stable"
}

installiere_brave() {
    echo -e "  ${CYAN}  Fuege Brave-Repository hinzu ...${RESET}"
    sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
        https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg || return 1
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] \
https://brave-browser-apt-release.s3.brave.com/ stable main" \
        | sudo tee /etc/apt/sources.list.d/brave-browser-release.list > /dev/null
    sudo apt-get update -qq
    sudo apt-get install -y -qq brave-browser
}

installiere_vscode() {
    echo -e "  ${CYAN}  Lade Microsoft-Repository ...${RESET}"
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
        | gpg --dearmor > /tmp/microsoft_vscode.gpg 2>/dev/null || return 1
    sudo install -D -o root -g root -m 644 /tmp/microsoft_vscode.gpg \
        /etc/apt/keyrings/microsoft_vscode.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/microsoft_vscode.gpg] \
https://packages.microsoft.com/repos/code stable main" \
        | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
    sudo apt-get update -qq
    sudo apt-get install -y -qq code
}

installiere_python() {
    local ver="$1"
    echo -e "  ${CYAN}  Fuege deadsnakes-PPA hinzu ...${RESET}"
    if ! command -v add-apt-repository &>/dev/null; then
        sudo apt-get install -y -qq software-properties-common
    fi
    sudo add-apt-repository -y ppa:deadsnakes/ppa 2>/dev/null
    sudo apt-get update -qq
    sudo apt-get install -y -qq "python${ver}" "python${ver}-venv" 2>/dev/null || \
    sudo apt-get install -y -qq "python${ver}"
}

# ─── Paketliste aktualisieren ───────────────────────────────────────────────

abschnitt "Installation laeuft"
echo ""
echo -e "  ${CYAN}Aktualisiere Paketlisten ...${RESET}"
sudo apt-get update -qq

# ─── Installation ───────────────────────────────────────────────────────────

ERFOLG=()
FEHLER=()

for i in "${!AUSGEWAEHLT_NAMEN[@]}"; do
    name="${AUSGEWAEHLT_NAMEN[$i]}"
    paket="${AUSGEWAEHLT_PAKETE[$i]}"
    sonder="${AUSGEWAEHLT_SONDER[$i]}"

    echo ""
    echo -e "  ${CYAN}Installiere ${name} ...${RESET}"

    ok=false
    case "$sonder" in
        chrome)
            installiere_chrome && ok=true
            ;;
        brave)
            installiere_brave && ok=true
            ;;
        vscode)
            installiere_vscode && ok=true
            ;;
        *)
            sudo apt-get install -y -qq "$paket" 2>/dev/null && ok=true
            ;;
    esac

    if $ok; then
        echo -e "  [✅] ${name} erfolgreich installiert"
        ERFOLG+=("$name")
    else
        echo -e "  ${ROT}[❌] ${name} fehlgeschlagen${RESET}"
        FEHLER+=("$name")
    fi
done

if [[ -n "$GEWUENSCHTE_PYTHON" ]]; then
    echo ""
    echo -e "  ${CYAN}Installiere Python ${GEWUENSCHTE_PYTHON} ...${RESET}"
    if installiere_python "$GEWUENSCHTE_PYTHON"; then
        echo -e "  [✅] Python ${GEWUENSCHTE_PYTHON} erfolgreich installiert"
        ERFOLG+=("Python $GEWUENSCHTE_PYTHON")
    else
        echo -e "  ${ROT}[❌] Python ${GEWUENSCHTE_PYTHON} fehlgeschlagen${RESET}"
        FEHLER+=("Python $GEWUENSCHTE_PYTHON")
    fi
fi

for i in "${!ZUSATZ_NAMEN[@]}"; do
    name="${ZUSATZ_NAMEN[$i]}"
    paket="${ZUSATZ_PAKETE[$i]}"

    echo ""
    echo -e "  ${CYAN}Installiere ${name} ...${RESET}"

    if sudo apt-get install -y -qq "$paket" 2>/dev/null; then
        echo -e "  [✅] ${name} erfolgreich installiert"
        ERFOLG+=("$name")
    else
        echo -e "  ${ROT}[❌] ${name} fehlgeschlagen${RESET}"
        FEHLER+=("$name")
    fi
done

# ─── Abschlussbericht ───────────────────────────────────────────────────────

abschnitt "Abschlussbericht"
echo ""

if [[ ${#ERFOLG[@]} -gt 0 ]]; then
    echo -e "  ${GRUEN}Erfolgreich installiert:${RESET}"
    for n in "${ERFOLG[@]}"; do
        echo -e "    ${GRUEN}[✅] $n${RESET}"
    done
    echo ""
fi

if [[ ${#FEHLER[@]} -gt 0 ]]; then
    echo -e "  ${ROT}Fehlgeschlagen:${RESET}"
    for n in "${FEHLER[@]}"; do
        echo -e "    ${ROT}[❌] $n${RESET}"
    done
    echo ""
    echo -e "  ${GELB}Tipp: Internetverbindung und sudo-Rechte pruefen.${RESET}"
    echo ""
fi

if [[ ${#FEHLER[@]} -eq 0 ]]; then
    echo -e "  ${GRUEN}Alle Installationen erfolgreich abgeschlossen!${RESET}"
fi

echo ""
echo -e "  ${GRAU}$(printf '%0.s─' {1..56})${RESET}"
echo ""
