#!/usr/bin/env bash
# Freeware Install Assistant - Linux (Debian/Ubuntu)
# Requires: apt, sudo
# Note: file must use Unix line endings (LF). On Windows:
#   Convert with: dos2unix install-linux.sh
#   Or: sed -i 's/\r//' install-linux.sh

# ─── Colors ───────────────────────────────────────────────────────────────

ROT='\033[0;31m'
GRUEN='\033[0;32m'
GELB='\033[1;33m'
CYAN='\033[0;36m'
WEISS='\033[1;37m'
GRAU='\033[0;90m'
RESET='\033[0m'

# ─── Helper functions ───────────────────────────────────────────────────────

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

# ─── Prerequisites ──────────────────────────────────────────────────────────

if [[ "$(uname -s)" != "Linux" ]]; then
    echo -e "${ROT}ERROR: This script is Linux-only.${RESET}"
    exit 1
fi

if ! command -v apt-get &>/dev/null; then
    echo -e "${ROT}ERROR: apt-get not found. Requires Debian/Ubuntu.${RESET}"
    exit 1
fi

if ! grep -qiE 'ubuntu|debian|linuxmint|pop' /etc/os-release 2>/dev/null; then
    echo -e "${GELB}WARNING: This may not be a Debian/Ubuntu system.${RESET}"
    echo -e "${GELB}         Continue at your own risk.${RESET}"
fi

# ─── Header ──────────────────────────────────────────────────────────────────

clear
echo ""
echo -e "  ${CYAN}+──────────────────────────────────────────────────────────+${RESET}"
echo -e "  ${CYAN}│       Freeware Install Assistant  ·  Linux                │${RESET}"
echo -e "  ${CYAN}+──────────────────────────────────────────────────────────+${RESET}"
echo ""
echo -e "  Platform: ${GRUEN}Linux  (apt)${RESET}"

# ─── System information ─────────────────────────────────────────────────────

abschnitt "System Information"
echo ""

HOSTNAME_V=$(hostname 2>/dev/null || echo "unknown")
OS_V=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d'"' -f2 || echo "Linux")
RAM_V=$(awk '/MemTotal/ {printf "%.1f GB", $2/1024/1024}' /proc/meminfo 2>/dev/null || echo "n/a")
CPU_V=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d':' -f2 | xargs || echo "n/a")

printf "  %-12s %s\n" "Hostname:"  "$HOSTNAME_V"
printf "  %-12s %s\n" "System:"    "$OS_V"
printf "  %-12s %s\n" "RAM:"       "$RAM_V"
printf "  %-12s %s\n" "CPU:"       "$CPU_V"

# ─── Program definitions ────────────────────────────────────────────────────
# Format: PROG_NAMEN[i], PROG_CMDS[i], PROG_PAKETE[i], PROG_SONDER[i]
# PROG_SONDER: "" = plain apt, "chrome" = Google Chrome, "vscode" = VS Code,
#              "brave" = Brave Browser
# Note: Adobe Acrobat Reader is deliberately not offered here - Adobe has not
# shipped an official Linux reader for years (Windows only, see
# install-windows.ps1).

PROG_NAMEN=("Firefox" "Google Chrome" "Brave Browser" "VLC" "7-Zip" "VS Code" "Git")
PROG_CMDS=( "firefox" "google-chrome" "brave-browser"  "vlc" "7z"   "code"    "git")
PROG_PAKETE=("firefox" "google-chrome-stable" "brave-browser" "vlc" "p7zip-full" "code" "git")
PROG_SONDER=("" "chrome" "brave" "" "" "vscode" "")

PYTHON_VERSIONEN=("3.10" "3.11" "3.12" "3.13")

# ─── Check installation status ──────────────────────────────────────────────

abschnitt "Installation Status"
echo ""

FEHLENDE_NAMEN=()
FEHLENDE_PAKETE=()
FEHLENDE_SONDER=()

for i in "${!PROG_NAMEN[@]}"; do
    name="${PROG_NAMEN[$i]}"
    cmd="${PROG_CMDS[$i]}"
    printf "  Checking %-22s ..." "$name"
    if ist_installiert "$cmd" || paket_installiert "${PROG_PAKETE[$i]}"; then
        printf "\r  [✅] %-22s installed            \n" "$name"
    else
        printf "\r  [❌] %-22s not installed         \n" "$name"
        FEHLENDE_NAMEN+=("$name")
        FEHLENDE_PAKETE+=("${PROG_PAKETE[$i]}")
        FEHLENDE_SONDER+=("${PROG_SONDER[$i]}")
    fi
done

# Check Python versions
echo ""
echo -e "  ${WEISS}Python versions:${RESET}"
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

# ─── Select programs to install ─────────────────────────────────────────────

AUSGEWAEHLT_NAMEN=()
AUSGEWAEHLT_PAKETE=()
AUSGEWAEHLT_SONDER=()

if [[ ${#FEHLENDE_NAMEN[@]} -gt 0 ]]; then
    abschnitt "Select Programs"
    echo ""
    echo -e "  The following programs are not yet installed:"
    echo ""
    for i in "${!FEHLENDE_NAMEN[@]}"; do
        echo -e "    ${CYAN}[$((i+1))]  ${FEHLENDE_NAMEN[$i]}${RESET}"
    done
    echo ""
    echo -e "  ${GRAU}Input: comma-separated numbers (e.g. 1,3), 'all' or 'none'${RESET}"
    echo ""

    while true; do
        read -rp "  Selection: " eingabe
        eingabe="$(echo "$eingabe" | xargs)"

        if [[ -z "$eingabe" || "$eingabe" =~ ^(none|no|n)$ ]]; then
            break
        fi

        if [[ "$eingabe" =~ ^(all|a)$ ]]; then
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
                echo -e "  ${ROT}Invalid input: '$n'${RESET}"
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
    echo -e "  ${GRUEN}All programs from the list are already installed.${RESET}"
fi

# Python selection
GEWUENSCHTE_PYTHON=""
echo ""

if [[ ${#PY_FEHLT[@]} -gt 0 ]]; then
    echo -e "  Available to install:"
    for i in "${!PYTHON_VERSIONEN[@]}"; do
        ver="${PYTHON_VERSIONEN[$i]}"
        for f in "${PY_FEHLT[@]}"; do
            if [[ "$f" == "$ver" ]]; then
                echo -e "    ${CYAN}[$((i+1))]  Python ${ver}${RESET}"
                break
            fi
        done
    done
    echo -e "    ${GRAU}[0]  Do not install Python${RESET}"
    echo ""

    while true; do
        read -rp "  Selection (enter a number): " auswahl
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
                echo -e "  ${GELB}Python ${ver} is already installed.${RESET}"
            fi
        else
            echo -e "  ${ROT}Invalid input. Please enter a number.${RESET}"
        fi
    done
else
    echo -e "  ${GRUEN}All Python versions are already installed.${RESET}"
fi

# ─── Additional freeware ────────────────────────────────────────────────────

abschnitt "Additional Freeware"
echo ""

ZUSATZ_NAMEN=()
ZUSATZ_PAKETE=()

read -rp "  Install additional freeware that isn't on the list? (Y/N): " antwort_zusatz
echo ""

if [[ "$antwort_zusatz" =~ ^[yY]$ ]]; then
    echo -e "  ${GRAU}Look up the apt package name first with 'apt-cache search <name>'.${RESET}"
    echo -e "  ${GRAU}An empty program name ends the entry.${RESET}"
    echo ""
    while true; do
        read -rp "  Program name: " z_name
        [[ -z "$z_name" ]] && break

        read -rp "  apt package name for '$z_name': " z_paket
        if [[ -z "$z_paket" ]]; then
            echo -e "  ${GELB}No package name given, skipping '$z_name'.${RESET}"
            echo ""
            continue
        fi

        ZUSATZ_NAMEN+=("$z_name")
        ZUSATZ_PAKETE+=("$z_paket")
        echo -e "  ${GRUEN}[+] '$z_name' ($z_paket) queued for installation${RESET}"
        echo ""
    done
fi

# ─── Installation overview ──────────────────────────────────────────────────

abschnitt "Installation Overview"
echo ""

if [[ ${#AUSGEWAEHLT_NAMEN[@]} -eq 0 && -z "$GEWUENSCHTE_PYTHON" && ${#ZUSATZ_NAMEN[@]} -eq 0 ]]; then
    echo -e "  ${GELB}Nothing was selected for installation.${RESET}"
    echo ""
    exit 0
fi

for name in "${AUSGEWAEHLT_NAMEN[@]}"; do
    echo -e "  ${ROT}•  $name${RESET}"
done
[[ -n "$GEWUENSCHTE_PYTHON" ]] && echo -e "  ${ROT}•  Python $GEWUENSCHTE_PYTHON${RESET}"
for name in "${ZUSATZ_NAMEN[@]}"; do
    echo -e "  ${ROT}•  $name  (additional)${RESET}"
done

echo ""
read -rp "  Install these programs now? (Y/N): " antwort
echo ""

if [[ ! "$antwort" =~ ^[yY]$ ]]; then
    echo -e "  ${GELB}Installation cancelled.${RESET}"
    echo ""
    exit 0
fi

# ─── Sudo check ──────────────────────────────────────────────────────────────

if ! sudo -v 2>/dev/null; then
    echo -e "  ${ROT}ERROR: sudo privileges required.${RESET}"
    exit 1
fi

# ─── Install functions ───────────────────────────────────────────────────────

installiere_chrome() {
    local tmp; tmp=$(mktemp -d)
    echo -e "  ${CYAN}  Downloading Google Chrome ...${RESET}"
    if command -v wget &>/dev/null; then
        wget -q "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" \
             -O "${tmp}/chrome.deb" || return 1
    elif command -v curl &>/dev/null; then
        curl -sL "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" \
             -o "${tmp}/chrome.deb" || return 1
    else
        echo -e "  ${ROT}  wget/curl not found.${RESET}"
        return 1
    fi
    sudo dpkg -i "${tmp}/chrome.deb" 2>/dev/null || true
    sudo apt-get install -f -y -qq 2>/dev/null
    rm -rf "$tmp"
    ist_installiert "google-chrome" || ist_installiert "google-chrome-stable"
}

installiere_brave() {
    echo -e "  ${CYAN}  Adding the Brave repository ...${RESET}"
    sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
        https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg || return 1
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=amd64] \
https://brave-browser-apt-release.s3.brave.com/ stable main" \
        | sudo tee /etc/apt/sources.list.d/brave-browser-release.list > /dev/null
    sudo apt-get update -qq
    sudo apt-get install -y -qq brave-browser
}

installiere_vscode() {
    echo -e "  ${CYAN}  Downloading the Microsoft repository ...${RESET}"
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
    echo -e "  ${CYAN}  Adding the deadsnakes PPA ...${RESET}"
    if ! command -v add-apt-repository &>/dev/null; then
        sudo apt-get install -y -qq software-properties-common
    fi
    sudo add-apt-repository -y ppa:deadsnakes/ppa 2>/dev/null
    sudo apt-get update -qq
    sudo apt-get install -y -qq "python${ver}" "python${ver}-venv" 2>/dev/null || \
    sudo apt-get install -y -qq "python${ver}"
}

# ─── Update package lists ───────────────────────────────────────────────────

abschnitt "Installation Running"
echo ""
echo -e "  ${CYAN}Updating package lists ...${RESET}"
sudo apt-get update -qq

# ─── Installation ────────────────────────────────────────────────────────────

ERFOLG=()
FEHLER=()

for i in "${!AUSGEWAEHLT_NAMEN[@]}"; do
    name="${AUSGEWAEHLT_NAMEN[$i]}"
    paket="${AUSGEWAEHLT_PAKETE[$i]}"
    sonder="${AUSGEWAEHLT_SONDER[$i]}"

    echo ""
    echo -e "  ${CYAN}Installing ${name} ...${RESET}"

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
        echo -e "  [✅] ${name} installed successfully"
        ERFOLG+=("$name")
    else
        echo -e "  ${ROT}[❌] ${name} failed${RESET}"
        FEHLER+=("$name")
    fi
done

if [[ -n "$GEWUENSCHTE_PYTHON" ]]; then
    echo ""
    echo -e "  ${CYAN}Installing Python ${GEWUENSCHTE_PYTHON} ...${RESET}"
    if installiere_python "$GEWUENSCHTE_PYTHON"; then
        echo -e "  [✅] Python ${GEWUENSCHTE_PYTHON} installed successfully"
        ERFOLG+=("Python $GEWUENSCHTE_PYTHON")
    else
        echo -e "  ${ROT}[❌] Python ${GEWUENSCHTE_PYTHON} failed${RESET}"
        FEHLER+=("Python $GEWUENSCHTE_PYTHON")
    fi
fi

for i in "${!ZUSATZ_NAMEN[@]}"; do
    name="${ZUSATZ_NAMEN[$i]}"
    paket="${ZUSATZ_PAKETE[$i]}"

    echo ""
    echo -e "  ${CYAN}Installing ${name} ...${RESET}"

    if sudo apt-get install -y -qq "$paket" 2>/dev/null; then
        echo -e "  [✅] ${name} installed successfully"
        ERFOLG+=("$name")
    else
        echo -e "  ${ROT}[❌] ${name} failed${RESET}"
        FEHLER+=("$name")
    fi
done

# ─── Final report ────────────────────────────────────────────────────────────

abschnitt "Final Report"
echo ""

if [[ ${#ERFOLG[@]} -gt 0 ]]; then
    echo -e "  ${GRUEN}Installed successfully:${RESET}"
    for n in "${ERFOLG[@]}"; do
        echo -e "    ${GRUEN}[✅] $n${RESET}"
    done
    echo ""
fi

if [[ ${#FEHLER[@]} -gt 0 ]]; then
    echo -e "  ${ROT}Failed:${RESET}"
    for n in "${FEHLER[@]}"; do
        echo -e "    ${ROT}[❌] $n${RESET}"
    done
    echo ""
    echo -e "  ${GELB}Tip: check your internet connection and sudo privileges.${RESET}"
    echo ""
fi

if [[ ${#FEHLER[@]} -eq 0 ]]; then
    echo -e "  ${GRUEN}All installations completed successfully!${RESET}"
fi

echo ""
echo -e "  ${GRAU}$(printf '%0.s─' {1..56})${RESET}"
echo ""
