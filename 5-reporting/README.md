# 5 — Reporting

My reporting workspace. OffSec exams require a written report — I keep this
folder ready so I'm not building structure under time pressure.

## Subfolders

- `generative-ai/` `rag/` `agent/` `agent2agent/` `multimodal/` —
  per-target findings I drop here as I draft them.
- [common/](common/) — section-by-section exam report scaffolding,
  severity-scoring notes.

## My workflow during the exam

1. **As I exploit**, I copy [../templates/finding-writeup.md](../templates/finding-writeup.md)
   into the right target folder and fill in: title, target, channel, payload,
   evidence, impact, remediation.
2. **At report time**, I assemble the per-finding files into the final report
   using [common/exam-report-structure.md](common/exam-report-structure.md).
3. **I score every finding** using [common/severity-scoring.md](common/severity-scoring.md).
   AI/LLM findings don't map cleanly to CVSS — I use the AI-specific factors
   noted there.
