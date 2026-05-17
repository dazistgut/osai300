# MITRE ATLAS — quick mapping

Seeded reference. MITRE ATLAS is the AI/ML analog of ATT&CK. Useful for
report vocabulary and for thinking systematically about attack phase.

## Top-level tactics (the column headers)

1. **Reconnaissance** — model fingerprinting, surface mapping
2. **Resource Development** — building adversarial datasets, models
3. **Initial Access** — get into the pipeline (compromise dev/CI, supply chain)
4. **ML Model Access** — query access to the deployed model
5. **Execution** — prompt injection, jailbreak, malicious tool call
6. **Persistence** — memory/store/weights poisoning, backdoors
7. **Privilege Escalation** — escape from sandboxed agent context
8. **Defense Evasion** — guardrail bypass, obfuscated payloads
9. **Credential Access** — extract API keys / secrets from context
10. **Discovery** — capability/tool/data discovery (my 2-enumeration phase)
11. **Collection** — gather data via the model (RAG corpus, training data echo)
12. **Exfiltration** — markdown rendering exfil, tool-call exfil, side channels
13. **Impact** — denial of model service, data integrity violation, harm

## Common techniques I'll cite in reports

| Tactic | Technique | My phase |
|--------|-----------|---------|
| Reconnaissance | T1591 (Victim Org Info) / AML.T0006 | 1-recon |
| Discovery | AML.T0007 (Discover ML Model Ontology) | 2-enumeration |
| Execution | AML.T0051 (LLM Prompt Injection) | 3-exploitation |
| Execution | AML.T0054 (LLM Jailbreak) | 3-exploitation |
| Persistence | AML.T0070 (RAG Poisoning) | 4-post-exploit |
| Exfiltration | AML.T0024 (Exfiltration via ML Inference API) | 4-post-exploit |
| Impact | AML.T0048 (External Harms) | reporting |

(Technique IDs and names shift — I check ATLAS at atlas.mitre.org before
citing in the final report.)

## How I use this on the exam

- For each finding, I tag with the **primary tactic** in the writeup header.
- If the chain crosses tactics (recon → discovery → execution → exfil),
  I mention each step in the report's narrative section.

## Cross-reference

- [owasp-llm-top10.md](owasp-llm-top10.md) — OWASP LLM Top 10 (orthogonal)
