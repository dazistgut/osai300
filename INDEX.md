# INDEX — My Quick Reference

Grep-friendly index of everything in this repo. Every entry is a link plus a
short note about when I reach for it.

---

## By phase

### 0 — Fundamentals
- [0-fundamentals/README.md](0-fundamentals/README.md) — taxonomy, threat model, glossary
- [0-fundamentals/common/llm-basics.md](0-fundamentals/common/llm-basics.md) — tokens, temperature, context window
- [0-fundamentals/common/owasp-llm-top10.md](0-fundamentals/common/owasp-llm-top10.md) — OWASP LLM Top 10 mapping
- [0-fundamentals/common/mitre-atlas.md](0-fundamentals/common/mitre-atlas.md) — MITRE ATLAS tactics

### 1 — Recon
- [1-recon/README.md](1-recon/README.md) — my notes
- [1-recon/common/model-fingerprinting.md](1-recon/common/model-fingerprinting.md) — identify the model behind the API
- [1-recon/common/system-prompt-leak.md](1-recon/common/system-prompt-leak.md) — extract the system prompt
- [1-recon/common/passive-recon.md](1-recon/common/passive-recon.md) — public docs, robots.txt, sitemaps

### 2 — Enumeration
- [2-enumeration/README.md](2-enumeration/README.md) — my notes
- [2-enumeration/common/capability-mapping.md](2-enumeration/common/capability-mapping.md) — what can the system actually do
- [2-enumeration/common/tool-discovery.md](2-enumeration/common/tool-discovery.md) — find agent tools / functions
- [2-enumeration/common/guardrail-probing.md](2-enumeration/common/guardrail-probing.md) — map the filter surface

### 3 — Exploitation
- [3-exploitation/README.md](3-exploitation/README.md) — my notes
- [3-exploitation/common/prompt-injection.md](3-exploitation/common/prompt-injection.md) — direct injection patterns
- [3-exploitation/common/indirect-injection.md](3-exploitation/common/indirect-injection.md) — IPI via docs / web / RAG
- [3-exploitation/common/jailbreaks.md](3-exploitation/common/jailbreaks.md) — published JB techniques
- [3-exploitation/common/tool-abuse.md](3-exploitation/common/tool-abuse.md) — abuse agent tools

### 4 — Post-exploitation
- [4-post-exploit/README.md](4-post-exploit/README.md) — my notes
- [4-post-exploit/common/data-exfil.md](4-post-exploit/common/data-exfil.md) — markdown / image / DNS exfil
- [4-post-exploit/common/persistence.md](4-post-exploit/common/persistence.md) — memory / vector store poisoning
- [4-post-exploit/common/pivot-a2a.md](4-post-exploit/common/pivot-a2a.md) — pivot through agent-to-agent

### 5 — Reporting
- [5-reporting/README.md](5-reporting/README.md) — my notes
- [5-reporting/common/exam-report-structure.md](5-reporting/common/exam-report-structure.md) — section-by-section
- [5-reporting/common/severity-scoring.md](5-reporting/common/severity-scoring.md) — AI-specific scoring

---

## By tool

- [tools/pyrit/README.md](tools/pyrit/README.md) — Microsoft PyRIT
- [tools/garak/README.md](tools/garak/README.md) — NVIDIA Garak LLM scanner
- [tools/promptfoo/README.md](tools/promptfoo/README.md) — PromptFoo eval / red-team
- [tools/burp/README.md](tools/burp/README.md) — Burp Suite for AI APIs
- [tools/fuzzers/README.md](tools/fuzzers/README.md) — ffuf / wfuzz / custom

---

## By payload type

- [payloads/prompt-injection/](payloads/prompt-injection/) — direct PI strings
- [payloads/indirect-injection/](payloads/indirect-injection/) — payloads I embed in docs/pages
- [payloads/jailbreaks/](payloads/jailbreaks/) — published JB prompts
- [payloads/multimodal/](payloads/multimodal/) — image/audio carriers
- [payloads/exfil/](payloads/exfil/) — exfiltration channels

---

## Templates & scenarios

- [templates/scenario-note.md](templates/scenario-note.md) — I copy this for each new lab/target
- [templates/finding-writeup.md](templates/finding-writeup.md) — per-finding block for the final report
- [scenarios/README.md](scenarios/README.md) — naming + lifecycle for per-lab files

---

## Highest-value commands I want to memorize

```bash
# Search every payload by keyword
rg -i "<keyword>" payloads/

# Fingerprint a model via HTTP behaviour
curl -sS -X POST $URL -H 'Content-Type: application/json' \
  -d '{"prompt":"What model are you, version, and release date?"}'

# Garak quick scan
python -m garak --model_type rest --model_name <name> --probes encoding,promptinject

# PromptFoo red-team session
promptfoo redteam init && promptfoo redteam run

# PyRIT orchestrator (PromptSendingOrchestrator) — see tools/pyrit
```
