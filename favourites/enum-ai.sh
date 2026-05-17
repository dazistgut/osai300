#!/usr/bin/env bash
#
# enum-ai.sh — drill into the AI/LLM surface that http-triage.sh found.
#
# For each live HTTP(S) service I throw GETs (and optional POSTs) at the
# high-value AI endpoints, then pattern-match to fingerprint the framework
# (OpenAI-compatible / Ollama / FastAPI / Anthropic / Gradio / Streamlit /
# KServe / TF Serving / Triton …).
#
# Output: ONE consolidated text report at ./results/<UTC-ts>-enum.txt
# (the raw responses are captured in /tmp during the run and cleaned up).
# Per target the report shows: verdict, models, endpoint status table,
# and a short body excerpt for each non-404 response.
#
# Usage:
#   ./enum-ai.sh                         # auto: most recent ./results/<ts>/ from http-triage
#   ./enum-ai.sh results/20260517T193000Z
#   ./enum-ai.sh http://10.10.10.42:8000
#   ./enum-ai.sh https://api.lab.local
#   ./enum-ai.sh urllist.txt             # file of base URLs, one per line
#
# Knobs (env):
#   PROBE=1            send POST probes to chat/completions endpoints (off by default)
#   PROBE_MODEL        model name for POST probes (default gpt-3.5-turbo)
#   CURL_TIMEOUT       seconds per request (default 8)
#   MAX_BODY_LINES     truncate body excerpts to this many lines (default 30)
#   MAX_BODY_CHARS     hard char cap for body excerpts (default 2000)
#   BODY_EXCERPTS=0    skip the body excerpts entirely (status table only)
#   KEEP_RAW=1         also keep raw responses in /tmp/enum-ai-raw-<ts>/
#
# Scope: authorized testing / exam prep only.
# Paths are CWD-relative (matches http-triage.sh).

set -uo pipefail

# ---- config -----------------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CURL_TIMEOUT="${CURL_TIMEOUT:-8}"
PROBE="${PROBE:-0}"
PROBE_MODEL="${PROBE_MODEL:-gpt-3.5-turbo}"
MAX_BODY_LINES="${MAX_BODY_LINES:-30}"
MAX_BODY_CHARS="${MAX_BODY_CHARS:-2000}"
BODY_EXCERPTS="${BODY_EXCERPTS:-1}"
KEEP_RAW="${KEEP_RAW:-0}"

# GETs I always do. <label>|<path>
GET_ENDPOINTS=$(cat <<'EOF'
v1-models|/v1/models
openai-models|/models
api-tags|/api/tags
api-version|/api/version
api-show|/api/show
v1-messages|/v1/messages
v2-models|/v2/models
v1-predictions|/v1/predictions
predictions|/predictions
openapi-json|/openapi.json
openapi-yaml|/openapi.yaml
swagger-json|/swagger.json
docs|/docs
redoc|/redoc
graphql|/graphql
health|/health
healthz|/healthz
livez|/livez
readyz|/readyz
version|/version
info|/info
metrics|/metrics
well-known-ai-plugin|/.well-known/ai-plugin.json
well-known-openai-plugin|/.well-known/openai-plugin.json
robots|/robots.txt
root|/
stcore-health|/_stcore/health
config|/config
EOF
)

# ---- preflight --------------------------------------------------------------

usage() {
    sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 1
}

require() {
    command -v "$1" >/dev/null 2>&1 || { echo "[!] missing: $1" >&2; exit 1; }
}
require curl

HAVE_JQ=0
command -v jq >/dev/null 2>&1 && HAVE_JQ=1

# ---- collect base URLs ------------------------------------------------------

declare -a BASE_URLS

add_url() {
    local url="$1"
    url="${url%/}"
    BASE_URLS+=("$url")
}

ingest_triage_dir() {
    local dir="$1"
    [[ -d "$dir" ]] || return 1
    local host_dir host scheme port hdr_file
    for host_dir in "$dir"/*/; do
        [[ -d "$host_dir" ]] || continue
        host="$(basename "$host_dir")"
        for hdr_file in "$host_dir"*-headers.txt; do
            [[ -f "$hdr_file" ]] || continue
            local base
            base="$(basename "$hdr_file" -headers.txt)"
            scheme="${base%%-*}"
            port="${base#*-}"
            add_url "${scheme}://${host}:${port}"
        done
    done
}

find_latest_results() {
    local dir
    dir="$(ls -1dt ./results/*/ 2>/dev/null | while read -r d; do
        [[ -f "${d}nmap-summary.txt" ]] && echo "$d" && break
    done)"
    [[ -n "$dir" ]] && echo "${dir%/}"
}

if [[ $# -lt 1 ]]; then
    LATEST="$(find_latest_results)"
    if [[ -n "$LATEST" ]]; then
        echo "[+] auto-discovered triage results: $LATEST"
        ingest_triage_dir "$LATEST"
    else
        echo "[!] no arg passed and no ./results/<ts>/ from http-triage found" >&2
        echo
        usage
    fi
else
    INPUT="$1"
    if [[ -d "$INPUT" ]]; then
        echo "[+] using triage results dir: $INPUT"
        ingest_triage_dir "$INPUT"
    elif [[ -f "$INPUT" ]]; then
        echo "[+] reading base URLs from: $INPUT"
        while IFS= read -r line; do
            [[ -z "$line" || "$line" =~ ^\s*# ]] && continue
            add_url "$line"
        done < <(grep -Ev '^\s*(#|$)' "$INPUT")
    elif [[ "$INPUT" =~ ^https?:// ]]; then
        add_url "$INPUT"
    else
        echo "[!] don't know how to handle: $INPUT" >&2
        echo "    expected: <dir>, <file>, or http(s)://<url>" >&2
        echo
        usage
    fi
fi

[[ "${#BASE_URLS[@]}" -gt 0 ]] || { echo "[!] no base URLs to enumerate" >&2; exit 1; }

echo "[+] targets: ${#BASE_URLS[@]}"
[[ "$PROBE" == "1" ]] && echo "[+] PROBE=1 — POSTs enabled" \
                     || echo "[i] GET-only (set PROBE=1 to enable POST probes)"
echo

# ---- output paths -----------------------------------------------------------

TS="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT="./results/${TS}-enum.txt"
mkdir -p "./results"

RAW_DIR="$(mktemp -d -t enum-ai-raw-XXXXXX)"
cleanup() {
    if [[ "$KEEP_RAW" == "1" ]]; then
        echo "[+] raw responses kept: $RAW_DIR"
    else
        rm -rf "$RAW_DIR"
    fi
}
trap cleanup EXIT

# ---- fetching ---------------------------------------------------------------

fetch_get() {
    local url="$1" body_file="$2" head_file="$3"
    {
        echo "# $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "# GET $url"
    } > "$head_file"
    curl -ks --max-time "$CURL_TIMEOUT" \
        -o "$body_file" \
        -D >(cat >> "$head_file") \
        -w "STATUS=%{http_code} SIZE=%{size_download} CT=%{content_type}\n" \
        "$url" 2>/dev/null >> "$head_file" || echo "STATUS=000 SIZE=0 CT=" >> "$head_file"
}

fetch_post() {
    local url="$1" body_file="$2" head_file="$3" data="$4"
    {
        echo "# $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "# POST $url"
        echo "# data: $data"
    } > "$head_file"
    curl -ks --max-time "$CURL_TIMEOUT" \
        -X POST -H "Content-Type: application/json" -d "$data" \
        -o "$body_file" \
        -D >(cat >> "$head_file") \
        -w "STATUS=%{http_code} SIZE=%{size_download} CT=%{content_type}\n" \
        "$url" 2>/dev/null >> "$head_file" || echo "STATUS=000 SIZE=0 CT=" >> "$head_file"
}

meta_of() {
    # echo "STATUS SIZE CT" parsed out of the head file
    awk '
        /^STATUS=/ {
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^STATUS=/) status = substr($i, 8)
                if ($i ~ /^SIZE=/)   size   = substr($i, 6)
                if ($i ~ /^CT=/)     ct     = substr($i, 4)
            }
        }
        END { print (status ? status : "000"), (size ? size : 0), (ct ? ct : "-") }
    ' "$1"
}

slug_for_url() {
    local url="$1" scheme rest host port
    scheme="${url%%://*}"
    rest="${url#*://}"
    rest="${rest%%/*}"
    if [[ "$rest" == *:* ]]; then host="${rest%:*}"; port="${rest##*:}"
    else host="$rest"; case "$scheme" in https) port=443;; *) port=80;; esac
    fi
    echo "${host}-${port}-${scheme}"
}

# ---- fingerprinting (works off RAW_DIR/<slug>/ for one target) -------------

fingerprint() {
    local d="$1"
    local verdicts=()

    if [[ -s "${d}/api-tags.body" ]] && grep -q '"models"' "${d}/api-tags.body" \
        && grep -q '"modified_at"' "${d}/api-tags.body" 2>/dev/null; then
        verdicts+=("Ollama")
    fi

    if [[ -s "${d}/v1-models.body" ]] && grep -q '"object":"list"' "${d}/v1-models.body" \
        && grep -q '"data"' "${d}/v1-models.body"; then
        verdicts+=("OpenAI-compatible (/v1/models)")
    fi

    if [[ -s "${d}/v1-messages.head" ]]; then
        local st_msg
        st_msg="$(meta_of "${d}/v1-messages.head" | awk '{print $1}')"
        if [[ "$st_msg" =~ ^(400|401|405)$ ]] \
            && grep -qi 'anthropic\|x-api-key' "${d}/v1-messages.head" "${d}/v1-messages.body" 2>/dev/null; then
            verdicts+=("Anthropic-compatible (/v1/messages)")
        fi
    fi

    if [[ -s "${d}/openapi-json.body" ]] && grep -q '"openapi"' "${d}/openapi-json.body"; then
        if grep -q 'FastAPI' "${d}/openapi-json.body"; then
            verdicts+=("FastAPI")
        else
            verdicts+=("OpenAPI (framework unclear)")
        fi
    fi
    if grep -qi '^server: uvicorn' "${d}"/*.head 2>/dev/null; then
        verdicts+=("Uvicorn (likely FastAPI)")
    fi

    if grep -qi 'gradio' "${d}/root.body" 2>/dev/null; then
        verdicts+=("Gradio")
    fi

    if [[ -s "${d}/stcore-health.head" ]]; then
        local st_stc
        st_stc="$(meta_of "${d}/stcore-health.head" | awk '{print $1}')"
        [[ "$st_stc" == "200" ]] && verdicts+=("Streamlit")
    fi

    if [[ -s "${d}/v2-models.body" ]] && grep -qE '"name"|"versions"' "${d}/v2-models.body"; then
        verdicts+=("KServe v2 / Triton (/v2/models)")
    fi

    if [[ -s "${d}/v1-predictions.head" ]] || [[ -s "${d}/predictions.head" ]]; then
        if grep -qi 'tensorflow\|tfserving' "${d}"/*.head "${d}"/*.body 2>/dev/null; then
            verdicts+=("TensorFlow Serving")
        fi
    fi

    if grep -qi '^server: gunicorn' "${d}"/*.head 2>/dev/null; then
        verdicts+=("Gunicorn (Flask/Django/Starlette behind it)")
    fi
    if grep -qi '^x-powered-by: express' "${d}"/*.head 2>/dev/null; then
        verdicts+=("Node/Express")
    fi

    if [[ "${#verdicts[@]}" -eq 0 ]]; then
        echo "unknown — see endpoint responses below"
    else
        printf '%s\n' "${verdicts[@]}" | awk '!seen[$0]++' | paste -sd '; ' -
    fi
}

extract_models() {
    local d="$1"
    [[ "$HAVE_JQ" == "1" ]] || return 0
    if [[ -s "${d}/v1-models.body" ]]; then
        jq -r '.data[]?.id // empty' "${d}/v1-models.body" 2>/dev/null
    fi
    if [[ -s "${d}/api-tags.body" ]]; then
        jq -r '.models[]?.name // empty' "${d}/api-tags.body" 2>/dev/null
    fi
}

# ---- body excerpt helper ----------------------------------------------------

is_text_ct() {
    case "$1" in
        */json*|*/yaml*|*/xml*|text/*|application/javascript*|application/x-yaml*) return 0 ;;
        *) return 1 ;;
    esac
}

body_excerpt() {
    local body="$1" ct="$2"
    [[ -s "$body" ]] || { echo "(empty body)"; return; }
    is_text_ct "$ct" || { echo "(non-text body, $(wc -c < "$body") bytes — skipped)"; return; }

    local tmp
    tmp="$(mktemp)"
    # Pretty-print JSON if jq is available and the content looks JSON-ish.
    if [[ "$HAVE_JQ" == "1" ]] && [[ "$ct" == */json* ]] && jq -e . < "$body" >/dev/null 2>&1; then
        jq . < "$body" > "$tmp"
    else
        cp "$body" "$tmp"
    fi

    # Truncate by lines then by chars.
    local out
    out="$(head -n "$MAX_BODY_LINES" "$tmp" | cut -c1-200)"
    if [[ "$(wc -c <<< "$out")" -gt "$MAX_BODY_CHARS" ]]; then
        out="$(echo "$out" | cut -c1-"$MAX_BODY_CHARS")"
        out="${out}"$'\n[... truncated ...]'
    elif [[ "$(wc -l < "$tmp")" -gt "$MAX_BODY_LINES" ]]; then
        out="${out}"$'\n[... truncated, '"$(wc -l < "$tmp")"' lines total ...]'
    fi
    rm -f "$tmp"
    echo "$out"
}

# ---- per-target enumeration -------------------------------------------------

enum_one() {
    local url="$1" idx="$2" total="$3"
    local slug
    slug="$(slug_for_url "$url")"
    local d="${RAW_DIR}/${slug}"
    mkdir -p "$d"

    echo "[*] [$idx/$total] $url"

    # GETs
    while IFS='|' read -r label path; do
        [[ -z "$label" ]] && continue
        fetch_get "${url}${path}" "${d}/${label}.body" "${d}/${label}.head"
    done <<< "$GET_ENDPOINTS"

    # Optional POST probes
    if [[ "$PROBE" == "1" ]]; then
        fetch_post "${url}/v1/chat/completions" \
            "${d}/probe-v1-chat.body" "${d}/probe-v1-chat.head" \
            "{\"model\":\"${PROBE_MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1}"
        fetch_post "${url}/v1/completions" \
            "${d}/probe-v1-completions.body" "${d}/probe-v1-completions.head" \
            "{\"model\":\"${PROBE_MODEL}\",\"prompt\":\"hi\",\"max_tokens\":1}"
        fetch_post "${url}/v1/messages" \
            "${d}/probe-v1-messages.body" "${d}/probe-v1-messages.head" \
            "{\"model\":\"${PROBE_MODEL}\",\"max_tokens\":1,\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}]}"
        fetch_post "${url}/api/generate" \
            "${d}/probe-ollama-generate.body" "${d}/probe-ollama-generate.head" \
            "{\"model\":\"${PROBE_MODEL}\",\"prompt\":\"hi\",\"stream\":false}"
    fi

    local verdict models
    verdict="$(fingerprint "$d")"
    models="$(extract_models "$d" | paste -sd ', ' -)"

    # ---- emit this target's report section ----
    {
        echo "================================================================================"
        echo "[${idx}/${total}] ${url}"
        echo "================================================================================"
        printf "Verdict : %s\n" "$verdict"
        if [[ -n "$models" ]]; then
            printf "Models  : %s\n" "$models"
        fi
        echo
        echo "Endpoint status:"
        printf "  %-7s %-9s %s\n" "STATUS" "SIZE" "ENDPOINT"

        # Status table, in the order I defined GET_ENDPOINTS
        local label path st size ct
        while IFS='|' read -r label path; do
            [[ -z "$label" ]] && continue
            read -r st size ct < <(meta_of "${d}/${label}.head" 2>/dev/null || echo "000 0 -")
            printf "  %-7s %-9s %s\n" "$st" "$size" "$path"
        done <<< "$GET_ENDPOINTS"

        # POST probe rows (only if PROBE=1)
        if [[ "$PROBE" == "1" ]]; then
            for label in probe-v1-chat probe-v1-completions probe-v1-messages probe-ollama-generate; do
                local head="${d}/${label}.head"
                [[ -f "$head" ]] || continue
                read -r st size ct < <(meta_of "$head")
                local path
                case "$label" in
                    probe-v1-chat)             path="POST /v1/chat/completions" ;;
                    probe-v1-completions)      path="POST /v1/completions" ;;
                    probe-v1-messages)         path="POST /v1/messages" ;;
                    probe-ollama-generate)     path="POST /api/generate" ;;
                esac
                printf "  %-7s %-9s %s\n" "$st" "$size" "$path"
            done
        fi

        # Body excerpts (skip 000 / 404 / disabled)
        if [[ "$BODY_EXCERPTS" == "1" ]]; then
            echo
            echo "Responses (excerpts, non-404 only):"
            while IFS='|' read -r label path; do
                [[ -z "$label" ]] && continue
                read -r st size ct < <(meta_of "${d}/${label}.head" 2>/dev/null || echo "000 0 -")
                [[ "$st" == "000" || "$st" == "404" ]] && continue
                echo
                printf -- "--- %s  [%s, %s bytes, %s] ---\n" "$path" "$st" "$size" "$ct"
                body_excerpt "${d}/${label}.body" "$ct"
            done <<< "$GET_ENDPOINTS"

            if [[ "$PROBE" == "1" ]]; then
                for label in probe-v1-chat probe-v1-completions probe-v1-messages probe-ollama-generate; do
                    local body="${d}/${label}.body" head="${d}/${label}.head"
                    [[ -f "$head" ]] || continue
                    read -r st size ct < <(meta_of "$head")
                    [[ "$st" == "000" || "$st" == "404" ]] && continue
                    local path
                    case "$label" in
                        probe-v1-chat)         path="POST /v1/chat/completions" ;;
                        probe-v1-completions)  path="POST /v1/completions" ;;
                        probe-v1-messages)     path="POST /v1/messages" ;;
                        probe-ollama-generate) path="POST /api/generate" ;;
                    esac
                    echo
                    printf -- "--- %s  [%s, %s bytes, %s] ---\n" "$path" "$st" "$size" "$ct"
                    body_excerpt "$body" "$ct"
                done
            fi
        fi

        echo
    } >> "$REPORT"

    echo "    -> $verdict"
}

# ---- run --------------------------------------------------------------------

# Header
{
    echo "################################################################################"
    echo "# enum-ai.sh report"
    echo "# Run     : ${TS}"
    echo "# Targets : ${#BASE_URLS[@]}"
    echo "# PROBE   : ${PROBE}"
    echo "################################################################################"
    echo
} > "$REPORT"

i=0
for url in "${BASE_URLS[@]}"; do
    i=$((i + 1))
    enum_one "$url" "$i" "${#BASE_URLS[@]}"
done

# Footer — verdicts-only index
{
    echo "================================================================================"
    echo "Verdict index (quick scan)"
    echo "================================================================================"
    grep -E '^\[[0-9]+/[0-9]+\] |^Verdict : ' "$REPORT" | paste -d ' ' - -
} >> "$REPORT"

echo
echo "[+] done. single report: $REPORT"
echo
echo "    eyeballing:"
echo "      less $REPORT"
echo "      grep -E '^(\\[[0-9]+/|Verdict|Models)' $REPORT"
