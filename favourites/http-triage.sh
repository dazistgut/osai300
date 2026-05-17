#!/usr/bin/env bash
#
# http-triage.sh — my recon chain for AI/LLM API surface discovery.
#
# Pipeline:
#   1. nmap each target on AI-relevant HTTP ports
#   2. curl every open port to confirm an HTTP service responds
#   3. curl -I to grab headers (server, x-powered-by, cors, etc.)
#   4. gobuster against each live service with my AI-endpoint wordlist
#
# Usage:
#   ./http-triage.sh                       # reads favourites/iplist.txt
#   ./http-triage.sh <targets-file>
#   ./http-triage.sh <single-ip-or-hostname>
#   ./http-triage.sh <cidr>                # e.g. 10.10.10.0/24
#
# Examples:
#   ./http-triage.sh                       # default: iplist.txt next to this script
#   ./http-triage.sh targets.txt
#   ./http-triage.sh 10.10.10.42
#   ./http-triage.sh 10.10.10.0/24
#
# Output:
#   ./results/<UTC-timestamp>/         (in the current working dir)
#     nmap-summary.txt
#     <host>/
#       <scheme>-<port>-headers.txt
#       <scheme>-<port>-gobuster.txt
#
# Paths are CWD-relative — I drop this script onto whatever box I'm on,
# put iplist.txt next to wherever I run it from, and the results land in
# the same working dir. The wordlist (ai-endpoints.txt) travels with the
# script, so it's looked up next to the script first, then in CWD as a
# fallback.
#
# Scope: authorized testing / exam prep only. I never point this at hosts
# I don't own or have written permission to test.
#
# Runs natively on Kali (default exam env). On my Windows host it runs via
# WSL or Git Bash provided nmap/curl/gobuster are on PATH.

set -uo pipefail

# ---- config -----------------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Wordlist travels with the script. Prefer the copy next to the script;
# fall back to one in the current working dir if I've copied just the
# script somewhere and dropped a wordlist beside it.
if [[ -n "${WORDLIST:-}" ]]; then
    :  # explicit override wins
elif [[ -f "${SCRIPT_DIR}/ai-endpoints.txt" ]]; then
    WORDLIST="${SCRIPT_DIR}/ai-endpoints.txt"
elif [[ -f "./ai-endpoints.txt" ]]; then
    WORDLIST="./ai-endpoints.txt"
else
    WORDLIST="${SCRIPT_DIR}/ai-endpoints.txt"  # let the preflight report the missing path
fi

# Ports I sweep — AI/LLM-flavored selection on top of standard web ports.
#   80,443         standard web
#   8000,8001,8002 FastAPI / Uvicorn / alt
#   8080,8443      common proxy / dev TLS
#   8888           Jupyter
#   3000           Node / Next / Grafana
#   5000,5001      Flask
#   7860           Gradio
#   8501           Streamlit
#   11434          Ollama
#   1234           LM Studio
#   9000           various dashboards
#   4000           various dev
PORTS="${PORTS:-80,443,3000,4000,5000,5001,7860,8000,8001,8002,8080,8443,8501,8888,9000,11434,1234}"

GOBUSTER_THREADS="${GOBUSTER_THREADS:-20}"
GOBUSTER_TIMEOUT="${GOBUSTER_TIMEOUT:-10s}"
CURL_TIMEOUT="${CURL_TIMEOUT:-8}"

# Status codes I want gobuster to report on (anything non-404, basically).
GOBUSTER_STATUS_CODES="200,201,204,301,302,307,308,401,403,405,500"

# ---- preflight --------------------------------------------------------------

usage() {
    sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 1
}

DEFAULT_IPLIST="./iplist.txt"

# No arg → fall back to ./iplist.txt in the current working dir.
# (Must exist and contain at least one non-comment line.)
if [[ $# -lt 1 ]]; then
    if [[ -s "$DEFAULT_IPLIST" ]] && grep -Eqv '^\s*(#|$)' "$DEFAULT_IPLIST"; then
        set -- "$DEFAULT_IPLIST"
    else
        echo "[!] no targets passed and $(pwd)/iplist.txt is missing or empty" >&2
        echo "    add one IP/hostname/CIDR per line to that file, then re-run" >&2
        echo
        usage
    fi
fi

require() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "[!] missing required tool: $1" >&2
        exit 1
    }
}

require nmap
require curl
require gobuster

[[ -f "$WORDLIST" ]] || {
    echo "[!] wordlist not found: $WORDLIST" >&2
    echo "    set WORDLIST=/path/to/list.txt or restore favourites/ai-endpoints.txt" >&2
    exit 1
}

# ---- target list ------------------------------------------------------------

INPUT="$1"
TARGETS_FILE="$(mktemp)"
trap 'rm -f "$TARGETS_FILE"' EXIT

if [[ -f "$INPUT" ]]; then
    grep -Ev '^\s*(#|$)' "$INPUT" > "$TARGETS_FILE"
else
    # single IP, hostname, or CIDR — let nmap expand CIDRs itself
    echo "$INPUT" > "$TARGETS_FILE"
fi

TARGET_COUNT="$(wc -l < "$TARGETS_FILE")"
[[ "$TARGET_COUNT" -gt 0 ]] || { echo "[!] no targets" >&2; exit 1; }

# ---- output dir -------------------------------------------------------------

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="./results/${TS}"
mkdir -p "$OUT_DIR"
echo "[+] output: $OUT_DIR"
echo "[+] targets: $TARGET_COUNT"
echo "[+] ports: $PORTS"
echo

# ---- 1. nmap sweep ----------------------------------------------------------

NMAP_SUMMARY="${OUT_DIR}/nmap-summary.txt"
echo "[*] nmap sweep -> $NMAP_SUMMARY"

# -Pn      skip host-discovery (many exam targets drop ICMP)
# -sT      TCP connect (works without raw sockets / root)
# -sV      service/version detection
# --open   only show open ports
# -T4      reasonable speed
nmap -Pn -sT -sV --open -T4 -p "$PORTS" \
    -iL "$TARGETS_FILE" \
    -oN "$NMAP_SUMMARY" \
    > /dev/null

# parse "<host>:<port>" pairs from the nmap output.
# nmap -oN format:
#   Nmap scan report for <host>[ (<ip>)]
#   <port>/tcp open  <service> ...
mapfile -t HOST_PORT_PAIRS < <(awk '
    /^Nmap scan report for / {
        # take the IP in parens if present, else the bare host token
        if (match($0, /\(([^)]+)\)/, m)) { host = m[1] } else { host = $5 }
        next
    }
    /^[0-9]+\/tcp/ && /open/ {
        split($1, p, "/")
        print host ":" p[1]
    }
' "$NMAP_SUMMARY")

if [[ "${#HOST_PORT_PAIRS[@]}" -eq 0 ]]; then
    echo "[!] no open ports found"
    exit 0
fi

echo "[+] open services: ${#HOST_PORT_PAIRS[@]}"
echo

# ---- 2/3/4. probe + headers + fuzz -----------------------------------------

probe_one() {
    local host="$1" port="$2" scheme="$3"
    local host_dir="${OUT_DIR}/${host}"
    mkdir -p "$host_dir"

    local url="${scheme}://${host}:${port}/"
    local hdr_file="${host_dir}/${scheme}-${port}-headers.txt"
    local gob_file="${host_dir}/${scheme}-${port}-gobuster.txt"

    # 2. curl — does anything HTTP-shaped answer?
    local status
    status="$(curl -ks -o /dev/null -w '%{http_code}' \
        --max-time "$CURL_TIMEOUT" \
        "$url" || echo "000")"

    if [[ "$status" == "000" ]]; then
        return 0  # nothing responded on this scheme
    fi

    echo "[+] $url -> $status"

    # 3. curl -I for headers (saved verbatim, including request line)
    {
        echo "# $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "# curl -kIs --max-time $CURL_TIMEOUT $url"
        echo
        curl -kIs --max-time "$CURL_TIMEOUT" "$url"
    } > "$hdr_file"

    # 4. gobuster — fuzz against my AI endpoint wordlist
    echo "    -> gobuster ($gob_file)"
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
        --output "$gob_file" \
        2>/dev/null || true
}

for pair in "${HOST_PORT_PAIRS[@]}"; do
    host="${pair%:*}"
    port="${pair#*:}"

    # try https on the "tls-ish" ports first, then plain http on others.
    # cheap and works: if curl can't speak the wrong scheme it just times out
    # within CURL_TIMEOUT and we move on.
    case "$port" in
        443|8443) probe_one "$host" "$port" "https" ;;
        80|3000|4000|5000|5001|7860|8000|8001|8002|8080|8501|8888|9000|11434|1234)
            probe_one "$host" "$port" "http" ;;
        *)
            probe_one "$host" "$port" "http"
            probe_one "$host" "$port" "https"
            ;;
    esac
done

echo
echo "[+] done. results in $OUT_DIR"
echo "    nmap     : $NMAP_SUMMARY"
echo "    per-host : $OUT_DIR/<host>/"
echo
echo "    quick triage:"
echo "      rg -l '200|301|302' $OUT_DIR | head"
echo "      cat $OUT_DIR/*/*-headers.txt | grep -iE 'server:|x-powered-by:|x-llm|x-model'"
