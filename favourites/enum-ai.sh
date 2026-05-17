#!/usr/bin/env bash
#
# enum-ai.sh — drill into the AI/LLM surface that http-triage.sh found.
#
# For each live HTTP(S) service I throw GETs (and optional POSTs) at the
# high-value AI endpoints, capture raw responses + headers, then pattern-
# match to fingerprint the framework (OpenAI-compatible / Ollama / FastAPI
# / Anthropic / Gradio / Streamlit / KServe / TF Serving / Triton …).
#
# Usage:
#   ./enum-ai.sh                         # auto: most recent ./results/<ts>/ from http-triage
#   ./enum-ai.sh results/20260517T193000Z
#   ./enum-ai.sh http://10.10.10.42:8000
#   ./enum-ai.sh https://api.lab.local
#   ./enum-ai.sh urllist.txt             # file of base URLs, one per line
#
# Output: ./results/<UTC-ts>-enum/<host>-<port>-<scheme>/
#   _fingerprint.txt   — heuristic verdict for this service
#   <endpoint>.body    — raw response body
#   <endpoint>.head    — response headers + status
#   _summary.txt at top level — one-line verdict per target across the run
#
# Active POST probes are opt-in: PROBE=1 ./enum-ai.sh
# By default this is a GET-only enumeration — POSTs add side-effects (cost,
# logs, possibly a generated completion) and I want to make that explicit.
#
# Scope: authorized testing / exam prep only.
#
# Paths are CWD-relative (matches http-triage.sh).

set -uo pipefail

# ---- config -----------------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CURL_TIMEOUT="${CURL_TIMEOUT:-8}"
PROBE="${PROBE:-0}"               # 1 = send POST probes to /v1/chat/completions etc.
PROBE_MODEL="${PROBE_MODEL:-gpt-3.5-turbo}"  # arbitrary; servers tend to echo back which models they accept

# Endpoints I always GET. One per line: <label>|<path>
# label becomes the filename, path is the URL suffix.
GET_ENDPOINTS=$(cat <<'EOF'
v1-models|/v1/models
v1-models-noslash|/v1/models/
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
    command -v "$1" >/dev/null 2>&1 || {
        echo "[!] missing required tool: $1" >&2
        exit 1
    }
}

require curl
# jq is optional — used to pretty-print and to extract model names. Degrade
# gracefully if it's not on the box.
HAVE_JQ=0
command -v jq >/dev/null 2>&1 && HAVE_JQ=1

# ---- collect base URLs ------------------------------------------------------

declare -a BASE_URLS

add_url() {
    local url="$1"
    url="${url%/}"   # strip trailing /
    BASE_URLS+=("$url")
}

# Walk a results/<ts>/ dir from http-triage.sh and pull (host, scheme, port)
# tuples out of the headers filenames.
ingest_triage_dir() {
    local dir="$1"
    [[ -d "$dir" ]] || return 1
    local host_dir host scheme port hdr_file
    for host_dir in "$dir"/*/; do
        [[ -d "$host_dir" ]] || continue
        host="$(basename "$host_dir")"
        for hdr_file in "$host_dir"*-headers.txt; do
            [[ -f "$hdr_file" ]] || continue
            # filename shape: <scheme>-<port>-headers.txt
            local base
            base="$(basename "$hdr_file" -headers.txt)"
            scheme="${base%%-*}"
            port="${base#*-}"
            add_url "${scheme}://${host}:${port}"
        done
    done
}

find_latest_results() {
    # Most recent ./results/<UTC-ts>/ that has the http-triage shape
    # (i.e. contains an nmap-summary.txt). Excludes my own -enum runs.
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

if [[ "${#BASE_URLS[@]}" -eq 0 ]]; then
    echo "[!] no base URLs to enumerate" >&2
    exit 1
fi

echo "[+] targets: ${#BASE_URLS[@]}"
[[ "$PROBE" == "1" ]] && echo "[+] PROBE=1 — will send POSTs to chat/completions endpoints" || \
    echo "[i] GET-only (set PROBE=1 to enable POST probes)"
echo

# ---- output dir -------------------------------------------------------------

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUT_DIR="./results/${TS}-enum"
mkdir -p "$OUT_DIR"
SUMMARY="${OUT_DIR}/_summary.txt"
: > "$SUMMARY"

# ---- per-target enumeration -------------------------------------------------

slug_for_url() {
    # http://10.10.10.42:8000 -> 10.10.10.42-8000-http
    local url="$1" scheme host port
    scheme="${url%%://*}"
    local rest="${url#*://}"
    host="${rest%%:*}"
    port="${rest##*:}"
    [[ "$port" == "$rest" ]] && {
        # no explicit port
        case "$scheme" in
            https) port=443 ;;
            *)     port=80  ;;
        esac
    }
    echo "${host}-${port}-${scheme}"
}

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
        "$url" 2>/dev/null >> "$head_file" || echo "STATUS=000" >> "$head_file"
}

fetch_post() {
    local url="$1" body_file="$2" head_file="$3" data="$4" ctype="${5:-application/json}"
    {
        echo "# $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "# POST $url"
        echo "# data: $data"
    } > "$head_file"
    curl -ks --max-time "$CURL_TIMEOUT" \
        -X POST \
        -H "Content-Type: $ctype" \
        -d "$data" \
        -o "$body_file" \
        -D >(cat >> "$head_file") \
        -w "STATUS=%{http_code} SIZE=%{size_download} CT=%{content_type}\n" \
        "$url" 2>/dev/null >> "$head_file" || echo "STATUS=000" >> "$head_file"
}

status_of() {
    grep -oE 'STATUS=[0-9]+' "$1" | tail -1 | cut -d= -f2
}

fingerprint() {
    # Heuristic verdict for one target dir. Order matters — more specific first.
    local d="$1"
    local verdicts=()

    # Ollama: /api/tags returns {"models":[{"name":...,"modified_at":...}]}
    if [[ -s "${d}/api-tags.body" ]] && grep -q '"models"' "${d}/api-tags.body" \
        && grep -q '"modified_at"' "${d}/api-tags.body" 2>/dev/null; then
        verdicts+=("Ollama")
    fi

    # OpenAI-compatible: /v1/models with object:list + data[].owned_by
    if [[ -s "${d}/v1-models.body" ]] && grep -q '"object":"list"' "${d}/v1-models.body" \
        && grep -q '"data"' "${d}/v1-models.body"; then
        verdicts+=("OpenAI-compatible (/v1/models)")
    fi

    # Anthropic-style: /v1/messages typically 401/400 without auth header,
    # or accepts model+messages with anthropic-version header
    if [[ -s "${d}/v1-messages.head" ]]; then
        local st_msg
        st_msg="$(status_of "${d}/v1-messages.head")"
        if [[ "$st_msg" == "401" || "$st_msg" == "400" || "$st_msg" == "405" ]] \
            && grep -qi 'anthropic\|x-api-key' "${d}/v1-messages.head" "${d}/v1-messages.body" 2>/dev/null; then
            verdicts+=("Anthropic-compatible (/v1/messages)")
        fi
    fi

    # FastAPI: /openapi.json valid + "FastAPI" string OR Server: uvicorn
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

    # Gradio: HTML mentions gradio-app
    if grep -qi 'gradio' "${d}/root.body" 2>/dev/null; then
        verdicts+=("Gradio")
    fi

    # Streamlit: _stcore/health is the canonical health endpoint
    if [[ -s "${d}/stcore-health.head" ]]; then
        local st_stc
        st_stc="$(status_of "${d}/stcore-health.head")"
        [[ "$st_stc" == "200" ]] && verdicts+=("Streamlit")
    fi

    # KServe v2 / Triton: /v2/models
    if [[ -s "${d}/v2-models.body" ]] && grep -qE '"name"|"versions"' "${d}/v2-models.body"; then
        verdicts+=("KServe v2 / Triton (/v2/models)")
    fi

    # TF Serving / KServe v1: /v1/predictions or /predictions
    if [[ -s "${d}/v1-predictions.head" ]] || [[ -s "${d}/predictions.head" ]]; then
        if grep -qi 'tensorflow\|tfserving' "${d}"/*.head "${d}"/*.body 2>/dev/null; then
            verdicts+=("TensorFlow Serving")
        fi
    fi

    # Banner-based extras
    if grep -qi '^server: gunicorn' "${d}"/*.head 2>/dev/null; then
        verdicts+=("Gunicorn (Flask/Django/Starlette behind it)")
    fi
    if grep -qi '^x-powered-by: express' "${d}"/*.head 2>/dev/null; then
        verdicts+=("Node/Express")
    fi

    if [[ "${#verdicts[@]}" -eq 0 ]]; then
        echo "unknown — see raw responses"
    else
        # de-dup, keep order
        printf '%s\n' "${verdicts[@]}" | awk '!seen[$0]++' | paste -sd '; ' -
    fi
}

extract_models() {
    # Pull model names out of /v1/models or /api/tags if jq is available.
    local d="$1"
    [[ "$HAVE_JQ" == "1" ]] || return 0
    if [[ -s "${d}/v1-models.body" ]]; then
        jq -r '.data[]?.id // empty' "${d}/v1-models.body" 2>/dev/null
    fi
    if [[ -s "${d}/api-tags.body" ]]; then
        jq -r '.models[]?.name // empty' "${d}/api-tags.body" 2>/dev/null
    fi
}

enum_one() {
    local url="$1"
    local slug
    slug="$(slug_for_url "$url")"
    local d="${OUT_DIR}/${slug}"
    mkdir -p "$d"

    echo "[*] $url -> $d"

    # GETs
    while IFS='|' read -r label path; do
        [[ -z "$label" ]] && continue
        fetch_get "${url}${path}" "${d}/${label}.body" "${d}/${label}.head"
    done <<< "$GET_ENDPOINTS"

    # Optional POST probes
    if [[ "$PROBE" == "1" ]]; then
        # OpenAI-compatible chat completion
        fetch_post "${url}/v1/chat/completions" \
            "${d}/probe-v1-chat.body" \
            "${d}/probe-v1-chat.head" \
            "{\"model\":\"${PROBE_MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1}"

        # OpenAI-compatible legacy completion
        fetch_post "${url}/v1/completions" \
            "${d}/probe-v1-completions.body" \
            "${d}/probe-v1-completions.head" \
            "{\"model\":\"${PROBE_MODEL}\",\"prompt\":\"hi\",\"max_tokens\":1}"

        # Anthropic-style messages
        fetch_post "${url}/v1/messages" \
            "${d}/probe-v1-messages.body" \
            "${d}/probe-v1-messages.head" \
            "{\"model\":\"${PROBE_MODEL}\",\"max_tokens\":1,\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}]}"

        # Ollama generate
        fetch_post "${url}/api/generate" \
            "${d}/probe-ollama-generate.body" \
            "${d}/probe-ollama-generate.head" \
            "{\"model\":\"${PROBE_MODEL}\",\"prompt\":\"hi\",\"stream\":false}"
    fi

    # Fingerprint
    local verdict
    verdict="$(fingerprint "$d")"
    {
        echo "URL:        $url"
        echo "Verdict:    $verdict"
        echo "Models:"
        extract_models "$d" | sed 's/^/  - /' || true
        echo
        echo "GET status by endpoint:"
        for f in "${d}"/*.head; do
            [[ -f "$f" ]] || continue
            local label st
            label="$(basename "$f" .head)"
            st="$(status_of "$f")"
            printf "  %-30s %s\n" "$label" "${st:-???}"
        done
    } > "${d}/_fingerprint.txt"

    # Append to top-level summary
    {
        echo "## $url"
        echo "verdict: $verdict"
        local models
        models="$(extract_models "$d" | paste -sd ', ' -)"
        [[ -n "$models" ]] && echo "models: $models"
        echo
    } >> "$SUMMARY"

    echo "    -> $verdict"
}

for url in "${BASE_URLS[@]}"; do
    enum_one "$url"
done

echo
echo "[+] done. results in $OUT_DIR"
echo "    summary: $SUMMARY"
echo
echo "    quick triage:"
echo "      cat $SUMMARY"
echo "      rg -l 'gpt-|llama|claude|mistral|qwen' $OUT_DIR"
echo "      rg -i '\"object\":\"list\"|FastAPI|gradio|streamlit' $OUT_DIR"
