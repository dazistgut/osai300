# OWASP LLM Top 10 — mapping to AI-300

Seeded reference. The OWASP LLM Top 10 (2025 edition) is a common framing
device on the exam and in reports. Mapping here so I can write report
findings with the right vocabulary.

| Code | Name | Maps to my phase | Notes |
|------|------|-----------------|-------|
| LLM01 | Prompt Injection | 3-exploitation | Both direct and indirect |
| LLM02 | Sensitive Information Disclosure | 1-recon / 4-post-exploit | System prompts, training data, RAG corpus |
| LLM03 | Supply Chain | (outside RT scope mostly) | Compromised model weights, deps |
| LLM04 | Data and Model Poisoning | 4-post-exploit | Memory poisoning, vector store poisoning |
| LLM05 | Improper Output Handling | 3-exploitation / 4-post-exploit | XSS via answer, SSRF via markdown image |
| LLM06 | Excessive Agency | 2-enumeration / 3-exploitation | Over-broad tool scope, side-effect tools |
| LLM07 | System Prompt Leakage | 1-recon | Recon goal #1 |
| LLM08 | Vector & Embedding Weaknesses | 4-post-exploit | RAG poisoning, embedding similarity attacks |
| LLM09 | Misinformation | (often in scope as impact) | Hallucination weaponization |
| LLM10 | Unbounded Consumption | (DoS — out of scope for exam) | Token-cost amplification |

## How I cite in a report

`Finding: Indirect Prompt Injection via uploaded PDF (OWASP LLM01).`

When two codes apply (e.g., IPI that exfiltrates RAG corpus = LLM01 + LLM02),
I cite both, primary first.

## Cross-reference

- [mitre-atlas.md](mitre-atlas.md) — MITRE ATLAS tactics (orthogonal taxonomy)
