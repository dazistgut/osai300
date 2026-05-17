# Favourites

My scratch folder for exam-day scripts. Not part of the structured
phase/target layout — these are tools I copy onto whatever box I'm working
from and run ad-hoc.

## Contents

| File | What it does |
|------|--------------|
| [http-triage.sh](http-triage.sh) | **Full chain — discovery.** nmap → curl → headers → gobuster against AI/LLM endpoints, in one shot |
| [gobust.sh](gobust.sh) | **Fast path — fuzz only.** Reads `iplist.txt`, expands bare hosts across common HTTP ports, runs gobuster only on the ones that answer. Skip when I already know it's HTTP and want to save the nmap minute. |
| [enum-ai.sh](enum-ai.sh) | **Fingerprint.** Drills into each live service: GETs `/v1/models`, `/openapi.json`, `/api/tags`, `.well-known/ai-plugin.json` etc., heuristically IDs the framework (Ollama / OpenAI-compatible / FastAPI / Anthropic / Gradio / Streamlit / KServe / Triton …) |
| [ai-endpoints.txt](ai-endpoints.txt) | AI-flavored gobuster wordlist used by http-triage and gobust |
| [iplist.example.txt](iplist.example.txt) | Template for the target file — I copy this to `./iplist.txt` wherever I'm running |

## The chain

```
                  ┌─► http-triage.sh ──► results/<ts>/        ──┐
iplist.txt ──┤    │  (nmap+curl+gobuster)  per-host folders     ├──► enum-ai.sh ──► results/<ts>-enum/
                  │                                              │   (fingerprint)    _summary.txt
                  └─► gobust.sh    ────► results/<ts>-gobust/  ──┘
                     (gobuster only)     one file per service
```

`enum-ai.sh` auto-discovers the most recent http-triage `results/<ts>/`.
`gobust.sh` doesn't produce an enum-compatible layout — when I run it
standalone I either pipe its hits into a manual enum-ai call (single URLs),
or follow up with the full http-triage on the same iplist.

When I reach for which:

| Situation | Use |
|-----------|-----|
| Fresh box, unknown ports, time to spare | `http-triage.sh` (full chain) |
| Already know it's an HTTP API, want fast endpoint hits | `gobust.sh` |
| Have endpoints, want to know what framework it is | `enum-ai.sh` |

## Path convention

These scripts are **CWD-relative for engagement data** and **script-dir-relative
for bundled assets**. Concretely, when I run `./http-triage.sh`:

| Path | Where it lives |
|------|----------------|
| `iplist.txt` | Current working dir — I create it next to where I run from |
| `results/<UTC-ts>/` | Current working dir — written next to where I run from |
| `ai-endpoints.txt` | Travels with the script (looked up next to `http-triage.sh`, then CWD as fallback) |

That means I can `scp http-triage.sh ai-endpoints.txt kali:/tmp/` and run
from `/tmp/` on the lab box; the script does the right thing without me
fixing up paths.

## http-triage.sh — quick reference

```bash
# day-of flow on a new box:
cp /path/to/favourites/iplist.example.txt ./iplist.txt
# edit ./iplist.txt with the lab IPs
./http-triage.sh                          # reads ./iplist.txt, writes ./results/<ts>/

# one-off without writing a file:
./http-triage.sh 10.10.10.42
./http-triage.sh 10.10.10.0/24            # CIDR — nmap expands it

# alternate target file:
./http-triage.sh /some/other/targets.txt
```

**Any `iplist.txt` anywhere in this repo is gitignored** (alongside
`iplist.local.txt`, `targets.txt`, `targets.local.txt`) so real exam
targets never get pushed. The tracked template lives at
[iplist.example.txt](iplist.example.txt).

Output layout:

```
results/20260517T193000Z/
├── nmap-summary.txt
└── 10.10.10.42/
    ├── http-8000-headers.txt
    ├── http-8000-gobuster.txt
    ├── http-11434-headers.txt   # ollama
    └── http-11434-gobuster.txt
```

`results/` is also gitignored (existing `.gitignore` rule on line 28).

## Knobs (env vars)

I override these inline when I need to:

```bash
PORTS=80,443,8000,11434 ./http-triage.sh
GOBUSTER_THREADS=50     ./http-triage.sh
WORDLIST=/usr/share/seclists/Discovery/Web-Content/api/api-endpoints.txt \
    ./http-triage.sh 10.10.10.42
```

| Var | Default | When I change it |
|-----|---------|------------------|
| `PORTS` | wide AI/web sweep (80,443,3000,5000,7860,8000-8002,8080,8443,8501,8888,9000,11434,1234) | Narrow to known-open ports to save time |
| `WORDLIST` | `ai-endpoints.txt` next to script, else `./ai-endpoints.txt` | Swap for SecLists when I want classic web paths |
| `GOBUSTER_THREADS` | 20 | Bump to 50 on local labs, drop to 5 against fragile targets |
| `GOBUSTER_TIMEOUT` | 10s | Slow targets |
| `CURL_TIMEOUT` | 8 | Slow targets |

## gobust.sh — quick reference

```bash
# default — reads ./iplist.txt
./gobust.sh

# one-off forms:
./gobust.sh 10.10.10.42                 # bare host, sweeps common ports
./gobust.sh http://10.10.10.42:8000     # URL, fuzz directly
./gobust.sh 10.10.10.42:8000            # shorthand, treated as http://

# alternate iplist:
./gobust.sh /some/other/list.txt
```

`iplist.txt` entries can mix and match — `10.10.10.42`, `api.lab.local`,
`http://1.2.3.4:8000`, and `1.2.3.4:8000` all coexist on the same list.
Bare hosts get port-swept; URLs/shorthand get fuzzed directly.

Output is one file per live service: `results/<ts>-gobust/<host>-<port>-<scheme>.txt`,
each containing whatever gobuster found.

| Var | Default | When I change it |
|-----|---------|------------------|
| `PORTS` | 80,443,3000,5000,7860,8000,8001,8080,8443,8501,8888,9000,11434,1234 | Narrow to known-open ports |
| `WORDLIST` | bundled `ai-endpoints.txt` | Swap for SecLists |
| `EXTENSIONS` | (none) | e.g. `EXTENSIONS=json,yaml,txt ./gobust.sh` |
| `GOBUSTER_THREADS` | 20 | Up to 50 on local labs, 5 on fragile targets |
| `GOBUSTER_TIMEOUT` | 10s | Slow targets |
| `CURL_TIMEOUT` | 5 | Liveness probe before fuzzing — bump for slow boxes |

## enum-ai.sh — quick reference

```bash
# default — walks the most recent ./results/<ts>/ from http-triage
./enum-ai.sh

# point at a specific triage run
./enum-ai.sh results/20260517T193000Z

# single URL one-off
./enum-ai.sh http://10.10.10.42:8000
./enum-ai.sh https://api.lab.local

# file of base URLs
./enum-ai.sh urllist.txt

# enable POST probes (active — sends minimal chat/completions payloads
# to confirm an OpenAI/Anthropic/Ollama-compatible API is live)
PROBE=1 ./enum-ai.sh
PROBE=1 PROBE_MODEL=llama3 ./enum-ai.sh
```

Output layout:

```
results/20260517T194500Z-enum/
├── _summary.txt                          # one-block verdict per target
└── 10.10.10.42-11434-http/
    ├── _fingerprint.txt                  # "Verdict: Ollama" + status table
    ├── api-tags.body                     # raw JSON: {"models":[...]}
    ├── api-tags.head
    ├── v1-models.body                    # status 404 here (Ollama doesn't expose this)
    └── ...
```

What the verdict line covers (heuristic, order = priority):

| Signal | Verdict |
|--------|---------|
| `/api/tags` returns `{"models":[{...,"modified_at":...}]}` | Ollama |
| `/v1/models` returns `{"object":"list","data":[...]}` | OpenAI-compatible |
| `/v1/messages` + `anthropic-version` / `x-api-key` in headers | Anthropic-compatible |
| `/openapi.json` contains "FastAPI" | FastAPI |
| `Server: uvicorn` header | Uvicorn (likely FastAPI) |
| `/` body contains "gradio" | Gradio |
| `/_stcore/health` returns 200 | Streamlit |
| `/v2/models` with `"versions"` | KServe v2 / Triton |
| `Server: gunicorn` | Gunicorn-fronted (Flask/Django/Starlette) |
| `X-Powered-By: Express` | Node/Express |

If `jq` is on the box, the summary also lists model names pulled from
`/v1/models` and `/api/tags`. Without `jq` it still runs — just no
auto-extraction.

## Triage tricks I use on the output

```bash
# every endpoint gobuster confirmed
rg -h '^/' results/<ts>/*/*-gobuster.txt | sort -u

# server banners (model/framework fingerprints often leak here)
rg -i 'server:|x-powered-by:|x-llm|x-model|via:' results/<ts>/*/*-headers.txt

# anything that looked like an OpenAPI doc
rg -l 'openapi|swagger|redoc|api-docs' results/<ts>/

# CORS surface
rg -i 'access-control-' results/<ts>/*/*-headers.txt

# every verdict from an enum-ai run, sorted
rg '^verdict:' results/<ts>-enum/_summary.txt | sort -u

# every model name surfaced across all targets
rg '^models:' results/<ts>-enum/_summary.txt
```

## Cross-references

- [1-recon/common/model-fingerprinting.md](../1-recon/common/model-fingerprinting.md) — what to *do* with the headers/banners this finds
- [2-enumeration/common/capability-mapping.md](../2-enumeration/common/capability-mapping.md) — what to do with the endpoints
- [tools/fuzzers/README.md](../tools/fuzzers/README.md) — ffuf/wfuzz cheatsheets if I need to switch off gobuster

## Scope reminder

Authorized testing / exam prep only. Same guardrail as the repo README —
I don't point this at hosts I don't own or have written permission to test.

## Adding new scripts here

- Keep each script self-documenting (usage block at the top).
- Hard-code sensible defaults; expose knobs via env vars, not flags
  (faster to override under exam pressure).
- **Engagement data goes in CWD** (target lists, result dirs, captures).
  **Bundled assets travel with the script** (wordlists, payload sets).
- Send output under `./results/<UTC-timestamp>/` so I never collide a run
  with the previous one.
- Any `iplist.txt` / `targets.txt` is gitignored anywhere in the repo.
