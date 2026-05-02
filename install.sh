#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║   yozakura — swaync theme installer                          ║
# ║   Usage: bash install.sh [--theme <flavor>]                  ║
# ║          bash install.sh          (interactive menu)         ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

# ── ANSI palette ─────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
PINK='\033[38;5;218m'
LAVENDER='\033[38;5;147m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

info()    { echo -e "${CYAN}  →${RESET}  $*"        >&2; }
success() { echo -e "${GREEN}  ✓${RESET}  $*"      >&2; }
warn()    { echo -e "${YELLOW}  ⚠${RESET}  $*"     >&2; }
die()     { echo -e "${RED}  ✗  $*${RESET}"        >&2; exit 1; }
section() { echo -e "\n${BOLD}${MAGENTA}$*${RESET}" >&2; }

# ── GitHub raw base URL ───────────────────────────────────────────────────────
GITHUB_RAW="https://raw.githubusercontent.com/shunsui18/swaync/main"

# ── All files that must be fetched in remote mode ─────────────────────────────
# Paths are relative to the repo root.
REMOTE_FILES=(
  color-map-hiru.css
  color-map-yoru.css
  colors-hiru.css
  colors-yoru.css
  config.json
  style.css
  styles/control-center.css
  styles/notification.css
  styles/control-center-styles/button-grid-widget.css
  styles/control-center-styles/mpris-widget.css
  styles/control-center-styles/notification-group.css
  styles/notification-styles/content.css
  styles/notification-styles/critical.css
  notification-alerts/critical.mp3
  notification-alerts/normal.mp3
  scripts/bt-toggle.sh
  scripts/kdeconnect-toggle.sh
  scripts/notif-volume-wrapper.sh
)

# ── Detect remote vs local execution ─────────────────────────────────────────
# When piped via bash <(curl ...), BASH_SOURCE[0] is a /proc/self/fd/* path.
# In that case we download all repo files to a temp dir instead of reading locally.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REMOTE=0
if [[ "$SCRIPT_DIR" == /proc/* || "$SCRIPT_DIR" == /dev/fd* ]]; then
  REMOTE=1
  SCRIPT_DIR="$(mktemp -d)"
  trap 'rm -rf "$SCRIPT_DIR"' EXIT
  info "Remote install detected — fetching files from GitHub..." >&2
  for rel in "${REMOTE_FILES[@]}"; do
    dest="${SCRIPT_DIR}/${rel}"
    mkdir -p "$(dirname "$dest")"
    curl -fsSL "${GITHUB_RAW}/${rel}" -o "$dest" \
      || die "Failed to download ${rel} from GitHub"
  done
  # Restore executable bits on scripts
  chmod +x "${SCRIPT_DIR}"/scripts/*.sh
fi

# ── Build flavor list from available color-map files ─────────────────────────
mapfile -t FLAVORS < <(
  ls "${SCRIPT_DIR}"/color-map-*.css 2>/dev/null \
    | sed 's/.*color-map-//;s/\.css//' \
    | sort
)
[[ ${#FLAVORS[@]} -gt 0 ]] \
  || die "No color-map-*.css theme files found in ${SCRIPT_DIR}"

# ── Parse CLI flags ───────────────────────────────────────────────────────────
FLAVOR=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --theme)
      [[ -n "${2:-}" ]] || die "--theme requires a flavor argument (e.g. yoru, hiru)"
      FLAVOR="$2"; shift 2 ;;
    --theme=*)
      FLAVOR="${1#*=}"; shift ;;
    -h|--help)
      echo -e "Usage: bash install.sh [--theme <flavor>]" >&2
      echo -e "       Available flavors: ${FLAVORS[*]}" >&2
      echo -e "       Run without flags for interactive menu." >&2
      exit 0 ;;
    *)
      die "Unknown option: $1 — run with --help for usage" ;;
  esac
done

# ── Interactive menu (shown when no --theme flag was given) ───────────────────
if [[ -z "$FLAVOR" ]]; then
  declare -A FLAVOR_ICON=(  [yoru]="🌙" [hiru]="☀️" )
  declare -A FLAVOR_TAG=(   [yoru]="night" [hiru]="day" )
  declare -A FLAVOR_DESC=(
    [yoru]="deep navy blues, soft sakura accents"
    [hiru]="warm ivory canvas, gentle pastel tones"
  )
  declare -A FLAVOR_COLOR=( [yoru]="$LAVENDER" [hiru]="$PINK" )

  echo -e "" >&2
  echo -e "  ${PINK}╭────────────────────────────────────────╮${RESET}" >&2
  echo -e "  ${PINK}│${RESET}   ${BOLD}${PINK}🌸  夜桜  ·  yozakura  ·  swaync${RESET}     ${PINK}│${RESET}" >&2
  echo -e "  ${PINK}│${RESET}        ${DIM}choose a flavor to install${RESET}      ${PINK}│${RESET}" >&2
  echo -e "  ${PINK}╰────────────────────────────────────────╯${RESET}" >&2
  echo -e "" >&2

  for i in "${!FLAVORS[@]}"; do
    label="${FLAVORS[$i]}"
    icon="${FLAVOR_ICON[$label]:-  }"
    tag="${FLAVOR_TAG[$label]:-}"
    desc="${FLAVOR_DESC[$label]:-}"
    col="${FLAVOR_COLOR[$label]:-$RESET}"
    echo -e "    ${BOLD}${col}$((i+1))  ${icon}  ${label}${RESET}  ${DIM}(${tag})${RESET}" >&2
    echo -e "      ${DIM}${desc}${RESET}" >&2
    echo "" >&2
  done

  echo -ne "  ${BOLD}${PINK}❯${RESET} ${BOLD}Choice [1–${#FLAVORS[@]}]:${RESET} " >&2
  read -r choice </dev/tty
  echo "" >&2

  # Accept number or name
  if [[ "$choice" =~ ^[0-9]+$ ]]; then
    idx=$((choice - 1))
    [[ $idx -ge 0 && $idx -lt ${#FLAVORS[@]} ]] \
      || die "Invalid choice: ${choice} — pick a number between 1 and ${#FLAVORS[@]}"
    FLAVOR="${FLAVORS[$idx]}"
  else
    FLAVOR="$(echo "$choice" | tr '[:upper:]' '[:lower:]' | xargs)"
  fi
fi

# ── Validate flavor ───────────────────────────────────────────────────────────
[[ -f "${SCRIPT_DIR}/color-map-${FLAVOR}.css" ]] \
  || die "Flavor '${FLAVOR}' not found.\n       Available flavors: ${FLAVORS[*]}"
[[ -f "${SCRIPT_DIR}/colors-${FLAVOR}.css" ]] \
  || die "colors-${FLAVOR}.css missing — repo may be incomplete"

# ── Destination paths ─────────────────────────────────────────────────────────
SWAYNC_CFG_DIR="${HOME}/.config/swaync"

# ── Step 1 — Create directory tree ───────────────────────────────────────────
section "[ 1/5 ]  Preparing directories"
mkdir -p \
  "${SWAYNC_CFG_DIR}" \
  "${SWAYNC_CFG_DIR}/styles/control-center-styles" \
  "${SWAYNC_CFG_DIR}/styles/notification-styles" \
  "${SWAYNC_CFG_DIR}/notification-alerts" \
  "${SWAYNC_CFG_DIR}/scripts"
success "Config tree ready: ${DIM}${SWAYNC_CFG_DIR}${RESET}"

# ── Step 2 — Install static config & root stylesheets ────────────────────────
section "[ 2/5 ]  Installing config & root stylesheets"
for f in config.json style.css; do
  src="${SCRIPT_DIR}/${f}"
  [[ -f "$src" ]] || { warn "Missing ${f} — skipping"; continue; }
  cp "$src" "${SWAYNC_CFG_DIR}/${f}"
  success "Installed ${f}"
done

# ── Step 3 — Install CSS theme files (all flavors) ───────────────────────────
section "[ 3/5 ]  Installing colour theme files"
for src in "${SCRIPT_DIR}"/color-map-*.css "${SCRIPT_DIR}"/colors-*.css; do
  [[ -f "$src" ]] || continue
  dest="${SWAYNC_CFG_DIR}/$(basename "$src")"
  cp "$src" "$dest"
  success "Installed $(basename "$src")"
done

# Install component stylesheets under styles/
for rel in \
    styles/control-center.css \
    styles/notification.css \
    styles/control-center-styles/button-grid-widget.css \
    styles/control-center-styles/mpris-widget.css \
    styles/control-center-styles/notification-group.css \
    styles/notification-styles/content.css \
    styles/notification-styles/critical.css; do
  src="${SCRIPT_DIR}/${rel}"
  [[ -f "$src" ]] || { warn "Missing ${rel} — skipping"; continue; }
  cp "$src" "${SWAYNC_CFG_DIR}/${rel}"
  success "Installed ${rel}"
done

# ── Step 4 — Symlink active flavor ───────────────────────────────────────────
section "[ 4/5 ]  Linking active flavor  →  ${FLAVOR}"
for pair in "color-map:color-map-${FLAVOR}.css" "colors:colors-${FLAVOR}.css"; do
  link_name="${pair%%:*}"
  target="${pair##*:}"
  dest="${SWAYNC_CFG_DIR}/${link_name}.css"
  # Remove stale symlink or file before re-linking
  [[ -L "$dest" || -f "$dest" ]] && rm -f "$dest"
  ln -s "${target}" "$dest"
  success "Linked  ${BOLD}${link_name}.css${RESET}${GREEN}  →  ${DIM}${target}${RESET}"
done

# ── Step 5 — Install notification alerts & scripts ───────────────────────────
section "[ 5/5 ]  Installing sounds & scripts"
for f in critical.mp3 normal.mp3; do
  src="${SCRIPT_DIR}/notification-alerts/${f}"
  [[ -f "$src" ]] || { warn "Missing notification-alerts/${f} — skipping"; continue; }
  cp "$src" "${SWAYNC_CFG_DIR}/notification-alerts/${f}"
  success "Installed notification-alerts/${f}"
done

SCRIPTS_INSTALLED=0
for src in "${SCRIPT_DIR}"/scripts/*.sh; do
  [[ -f "$src" ]] || continue
  dest="${SWAYNC_CFG_DIR}/scripts/$(basename "$src")"
  cp "$src" "$dest"
  chmod +x "$dest"
  success "Installed scripts/$(basename "$src")  ${DIM}(executable)${RESET}"
  SCRIPTS_INSTALLED=$((SCRIPTS_INSTALLED + 1))
done
[[ $SCRIPTS_INSTALLED -gt 0 ]] \
  || warn "No scripts found in ${SCRIPT_DIR}/scripts/ — skipped"

# ── Reload swaync if running ──────────────────────────────────────────────────
echo "" >&2
if command -v swaync-client &>/dev/null && swaync-client --reload-config &>/dev/null 2>&1; then
  success "swaync config reloaded live"
else
  info "swaync not running — start it to apply the theme"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo "" >&2
echo -e "${BOLD}${PINK}  ✦  yozakura / ${FLAVOR} installed successfully!${RESET}" >&2
echo -e "${DIM}      Config : ${SWAYNC_CFG_DIR}/config.json" >&2
echo -e "      Theme  : ${SWAYNC_CFG_DIR}/color-map-${FLAVOR}.css" >&2
echo -e "               ${SWAYNC_CFG_DIR}/colors-${FLAVOR}.css${RESET}" >&2
echo "" >&2
