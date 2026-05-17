#!/usr/bin/env bash
#
# gobust.sh — straight gobuster over my iplist, no nmap upfront.
#
# When I already know targets are HTTP (or I want to fuzz fast without
# waiting for nmap), this runs gobuster directly. For bare IPs / hostnames
# it tries a small set of common AI/web ports and fuzzes only the ones
# that answer. For full URLs in iplist.txt it skips the port-probe step
# and goes straight to fuzzing.
#
# Usage:
#   ./gobust.sh                           # reads ./iplist.txt
#   ./gobust.sh iplist.txt
#   ./gobust.sh 10.10.10.42               # single host, all common ports
#   ./gobust.sh http://10.10.10.42:8000   # single URL, fuzz directly
#
# Each iplist.txt line can be any of:
#   10.10.10.42                  - try ports below
#   api.lab.local                - try ports below
#   http://10.10.10.42:8000      - fuzz this URL, no port-probing
#   https://api.lab.local        - fuzz this URL
#   10.10.10.42:8000             - shorthand, treated as http://
#
# Output: ./results/<UTC-ts>-gobust/<host>-<port>-<scheme>.txt
#
# Knobs (env):
#   PORTS               — comma list of HTTP ports to try for bare IPs
#   WORDLIST            — path to gobuster wordlist (defaults to bundled)
#   GOBUSTER_THREADS    — default 20
#   GOBUSTER_TIMEOUT    — default 10s
#   CURL_TIMEOUT        — default 5 (liveness check)
#   EXTENSIONS          — gobuster -x list (e.g. "json,yaml,txt")
#
# Scope: authorized testing / exam prep only.

set -uo pipefail

# ---- config -----------------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Wordlist: prefer the one next to the script; fall back to CWD.
if [[ -n "${WORDLIST:-}" ]]; then
    :
elif [[ -f "${SCRIPT_DIR}/ai-endpoints.txt" ]]; then
    WORDLIST="${SCRIPT_DIR}/ai-endpoints.txt"
elif [[ -f "./ai-endpoints.txt" ]]; then
    WORDLIST="./ai-endpoints.txt"
else
    WORDLIST="${SCRIPT_DIR}/ai-endpoints.txt"
fi

PORTS="${PORTS:-80,443,3000,5000,7860,8000,8001,8080,8443,8501,8888,9000,11434,1234}"
GOBUSTER_THREADS="${GOBUSTER_THREADS:-20}"
GOBUSTER_TIMEOUT="${GOBUSTER_TIMEOUT:-10s}"
CURL_TIMEOUT="${CURL_TIMEOUT:-5}"
EXTENSIONS="${EXTENSIONS:-}"
GOBUSTER_STATUS_CODES="200,201,204,301,302,307,308,401,403,405,500"

# ---- preflight --------------------------------------------------------------

usage() {
    sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 1
}

require() {
    command -v "$1" >/dev/null 2>&1 || { echo "[!] missing: $1" >&2; exit 1; }
}
require curl
require gobuster
[[ -f "$WORDLIST" ]] || { echo "[!] wordlist not found: $WORDLIST" >&2; exit 1; }

# ---- collect entries --------------------------------------------------------

DEFAULT_IPLIST="./iplist.txt"
declare -a ENTRIES

if [[ $# -ge 1 ]]; then
    ARG="$1"
    if [[ -f "$ARG" ]]; then
        mapfile -t ENTRIES < <(grep -Ev '^\s*(#|$)' "$ARG")
    else
        ENTRIES=("$ARG")
    fi
else
    if [[ -s "$DEFAULT_IPLIST" ]] && grep -Eqv '^\s*(#|$)' "$DEFAULT_IPLIST"; then
        mapfile -t ENTRIES < <(grep -Ev '^\s*(#|$)' "$DEFAULT_IPLIST")
    else
        echo "[!] no arg and $(pwd)/iplist.txt missing or empty" >&2
        echo
        usage
    fi
fi

[[ "${#ENTRIES[@]}" -gt 0 ]] || { echo "[!] no entries" >&2; exit 1; }

# ---- output dir -------------------------------------------------------------

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="./results/${TS}-gobust"
mkdir -p "$OUT_DIR"

echo "[+] output: $OUT_DIR"
echo "[+] wordlist: $WORDLIST"
echo "[+] entries: ${#ENTRIES[@]}"
echo

# ---- helpers ----------------------------------------------------------------

# Probe a URL with a fast HEAD-then-GET; echo "alive" if anything responds.
alive() {
    local url="$1" status
    status="$(curl -ks -o /dev/null -w '%{http_code}' --max-time "$CURL_TIMEOUT" "$url" || echo 000)"
    [[ "$status" != "000" ]]
}

run_gobuster() {
    local url="$1"
    local host_port slug out
    # url = scheme://host[:port]/...  -> "host-port-scheme" for the filename
    local scheme rest host port
    scheme="${url%%://*}"
    rest="${url#*://}"
    rest="${rest%%/*}"           # strip path
    if [[ "$rest" == *:* ]]; then
        host="${rest%:*}"; port="${rest##*:}"
    else
        host="$rest"
        case "$scheme" in https) port=443 ;; *) port=80 ;; esac
    fi
    slug="${host}-${port}-${scheme}"
    out="${OUT_DIR}/${slug}.txt"

    echo "[*] gobuster $url -> $out"

    local ext_args=()
    [[ -n "$EXTENSIONS" ]] && ext_args=(--extensions "$EXTENSIONS")

    gobuster dir \
        --url "$url" \
        --wordlist "$WORDLIST" \
        --threads "$GOBUSTER_THREADS" \
        --timeout "$GOBUSTER_TIMEOUT" \
        --status-codes "$GOBUSTER_STATUS_CODES" \
        --no-error \
        --quiet \
        --no-progress \
        -k \
        --output "$out" \
        "${ext_args[@]}" \
        2>/dev/null || true

    # If gobuster found nothing, the file may be empty; leave it so I can see
    # the negative result in the run.
    local hits
    hits="$(wc -l < "$out" 2>/dev/null || echo 0)"
    echo "    -> $hits hits"
}

handle_entry() {
    local entry="$1"
    entry="${entry%/}"   # drop trailing slash

    # Full URL? fuzz directly.
    if [[ "$entry" =~ ^https?:// ]]; then
        if alive "$entry/"; then
            run_gobuster "$entry"
        else
            echo "[-] $entry not responding, skipping"
        fi
        return
    fi

    # host:port shorthand -> http://host:port
    if [[ "$entry" == *:* && ! "$entry" =~ ^\[ ]]; then
        local url="http://${entry}"
        if alive "$url/"; then
            run_gobuster "$url"
        else
            echo "[-] $entry not responding on http, trying https"
            url="https://${entry}"
            if alive "$url/"; then run_gobuster "$url"; else echo "[-] $entry dead"; fi
        fi
        return
    fi

    # Bare host -> expand across PORTS
    IFS=',' read -ra port_list <<< "$PORTS"
    local found=0
    for p in "${port_list[@]}"; do
        local scheme
        case "$p" in 443|8443) scheme="https" ;; *) scheme="http" ;; esac
        local url="${scheme}://${entry}:${p}"
        if alive "$url/"; then
            run_gobuster "$url"
            found=$((found + 1))
        fi
    done
    [[ "$found" -eq 0 ]] && echo "[-] $entry: no HTTP on any of $PORTS"
}

for e in "${ENTRIES[@]}"; do
    handle_entry "$e"
done

echo
echo "[+] done. results in $OUT_DIR"
echo
echo "    quick triage:"
echo "      wc -l $OUT_DIR/*.txt"
echo "      rg -H '' $OUT_DIR/*.txt | sort -u"
echo "      # endpoints worth chasing (non-403/404):"
echo "      rg -h '(Status: 200|Status: 30[0-9])' $OUT_DIR/*.txt"
