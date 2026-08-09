#!/usr/bin/env bash
# 2026 machiner opencode
# browsah - browser privacy, one button
#   usage: ./install.sh [firefox|helium|all]   (default: interactive menu)
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CHOICE="${1:-}"
if [ -z "$CHOICE" ]; then
  echo "  browsah - browser privacy installer"
  echo
  echo "  1) Firefox"
  echo "  2) Helium"
  echo "  3) Both"
  read -rp "  choice [3] " c
  case "${c:-3}" in
    1) CHOICE=firefox ;;
    2) CHOICE=helium ;;
    *) CHOICE=all ;;
  esac
fi

case "$CHOICE" in
  firefox)
    bash "$DIR/firefox/configure-firefox.sh"
    ;;
  helium)
    bash "$DIR/helium/configure-helium.sh"
    ;;
  all)
    echo "== Firefox =="
    bash "$DIR/firefox/configure-firefox.sh" || echo "!! Firefox step had a problem"
    echo
    echo "== Helium =="
    bash "$DIR/helium/configure-helium.sh" || echo "!! Helium step had a problem"
    ;;
  *)
    echo "usage: $0 [firefox|helium|all]"
    exit 1
    ;;
esac
