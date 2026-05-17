# OSAI-300 — My AI Red Teaming Reference

My personal reference repo for the **OffSec AI Red Teaming (AI-300 / OSAI)**
course and exam. Organised by **attack phase × target type**, with seeded
reference content under `common/` folders and free space at the root of each
topic for my own notes.

> **Scope:** Authorized security testing and exam preparation only. Everything
> here is publicly documented technique / tooling. I do not run any of this
> against systems I do not own or have written permission to test.

---

## Layout

```
osai300/
├── 0-fundamentals/         AI/ML/LLM basics, threat model, taxonomy
├── 1-recon/                Model & system fingerprinting, version detection
├── 2-enumeration/          Capability mapping, tool/function discovery, guardrail probing
├── 3-exploitation/         Prompt injection, jailbreaks, payload delivery
├── 4-post-exploit/         Data exfil, persistence, pivot via agents / A2A
├── 5-reporting/            Findings, CVSS-AI style scoring, exam-style report
│
├── tools/                  Tool cheatsheets (PyRIT, Garak, PromptFoo, Burp, ffuf…)
├── payloads/               Raw payload library, organized by technique
├── scenarios/              Per-lab / per-scenario working notes
├── templates/              Reusable templates (findings, payloads, scenarios)
│
├── INDEX.md                Quick-jump index for grep-friendly exam lookup
└── README.md               This file
```

Each phase folder has the same shape:

```
<phase>/
├── README.md               My top-level notes for this phase
├── generative-ai/          Target: plain generative model / chatbot
├── rag/                    Target: retrieval-augmented system
├── agent/                  Target: single tool-using agent
├── agent2agent/            Target: multi-agent / A2A system
├── multimodal/             Target: vision / audio / cross-modal
└── common/                 Seeded reference content (I don't put my own notes here)
```

**Convention:** I keep my own notes at the **root** of each target folder so
they feel familiar during the exam. I drop into `common/` for seeded reference
material when I need a refresher.

---

## How I use this during the exam

1. Start in [INDEX.md](INDEX.md) — has the highest-value commands and links
   grouped by phase.
2. Ripgrep across the whole repo: `rg -i "system prompt" --type md`.
3. Every page is plain markdown with consistent headings — search-friendly.
4. Per-lab working notes live in [scenarios/](scenarios/) — I copy
   [templates/scenario-note.md](templates/scenario-note.md) for each new box.
5. Final report uses [templates/finding-writeup.md](templates/finding-writeup.md)
   and [5-reporting/](5-reporting/).

---

## Tagging convention

When I write notes, I tag the technique with a short prefix so search works:

| Tag | Meaning |
|-----|---------|
| `PI:`  | Direct prompt injection |
| `IPI:` | Indirect prompt injection |
| `JB:`  | Jailbreak |
| `TA:`  | Tool / function abuse (agent) |
| `A2A:` | Agent-to-agent attack |
| `RAG:` | RAG-specific (poisoning, retrieval abuse) |
| `MM:`  | Multimodal payload |
| `EX:`  | Data exfiltration |
| `MX:`  | Model extraction / inversion |
| `AE:`  | Adversarial example (classic ML) |
| `SC:`  | Supply chain / weights / pipeline |

Example: `## JB: DAN-style persona override (multi-turn)`.

---

## Quick-start commands I reach for first

```bash
# Find a payload across the whole repo
rg -i "ignore previous instructions" payloads/

# List every cheatsheet
fd README.md tools/

# Open the highest-value page for this phase
$EDITOR 3-exploitation/README.md
```
