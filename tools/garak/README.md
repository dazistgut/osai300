# Garak — LLM Vulnerability Scanner

NVIDIA's "nmap for LLMs". Probe-based, batteries-included scanner for
common LLM weaknesses (prompt injection, jailbreaks, leakage, encoding,
hallucination, toxicity).

Repo: https://github.com/NVIDIA/garak — verify before exam.

## Install

```bash
pip install garak
python -m garak --help
python -m garak --list_probes        # see what's available
python -m garak --list_detectors
```

## Generator types (the `--model_type`)

| Type | Use for |
|------|---------|
| `openai` | OpenAI API directly |
| `azure` | Azure OpenAI |
| `rest` | Generic HTTP endpoint with custom request/response shape |
| `huggingface` | local HF model |
| `ggml` / `ggml.GGUFLLaMA` | local GGUF model |
| `litellm` | anything LiteLLM proxies |

## My fastest first scan

```bash
python -m garak \
  --model_type openai \
  --model_name <model> \
  --probes promptinject,encoding,dan,leakreplay \
  --report_prefix exam-target-1
```

Outputs `exam-target-1.report.jsonl` + `.html`. JSONL contains every
attempt; HTML is the readable summary.

## REST target (most common in the exam — wrapped APIs)

Create `rest.json`:

```json
{
  "rest": {
    "name": "custom",
    "uri": "https://target.example/api/chat",
    "method": "POST",
    "headers": {
      "Authorization": "Bearer YOUR_KEY",
      "Content-Type": "application/json"
    },
    "req_template_json_object": {
      "messages": [{"role": "user", "content": "$INPUT"}],
      "stream": false
    },
    "response_json": true,
    "response_json_field": "choices/0/message/content"
  }
}
```

Run:

```bash
python -m garak --model_type rest --generator_option_file rest.json \
  --probes promptinject,encoding
```

Adjust `response_json_field` to your API's shape. Anthropic-shaped:
`content/0/text`. Google: `candidates/0/content/parts/0/text`.

## Most useful probes (in my exam priority order)

| Probe | What it tries |
|-------|----------------|
| `promptinject` | Greshake-style prompt injection corpus |
| `encoding` | base64/hex/etc. instruction smuggling |
| `dan` | Persona override (DAN family) |
| `leakreplay` | Training data leak (poetry, lyrics, code) |
| `realtoxicityprompts` | Toxic completion bait |
| `xss` | Output is HTML/markdown — does it render dangerous content |
| `latentinjection` | Indirect / latent injection via context |
| `goodside` | Riley Goodside-style attacks |
| `malwaregen` | Will it produce malware-like code |
| `glitch` | Glitch tokens / boundary tokens |
| `lmrc` | Misinformation / safety category |

Use `--probes <p1>,<p2>` (comma-separated). `--probe_options` lets me tune.

## Detector tuning

Detectors decide if a response = success. Defaults are reasonable. To list:

```bash
python -m garak --list_detectors
```

## Tips I want to remember

- `--parallel_attempts 4` to speed up against APIs that allow concurrency.
- `--seed 42` for reproducibility (the report needs reproducible attempts).
- `--report_prefix` keeps the artifacts named per-target.
- `--narrow_output` to keep terminal output readable.
- Pipe failed attempts to a file for the report:
  `jq 'select(.detector_score > 0.5)' run.report.jsonl > findings.jsonl`
- Probes are Python — I can read the source to understand what each does
  if a finding needs explanation.

## Gotchas

- Long-running. Start a scan in the background while I do interactive work.
- Some probes deliberately produce policy-violating content in successful
  attempts — that's the *point* but it means I shouldn't redistribute
  the raw `.jsonl`.
- REST template variables: `$INPUT` is replaced with the probe text; if my
  API has other required fields, they go in `req_template_json_object`.
- HF / local models need disk space + RAM; not a great fit during a timed
  exam unless I pre-pulled.
