# Exam Report Structure

Seeded reference. OffSec exam reports are heavily formatted. This is the
skeleton I assemble at the end.

## Top-level structure (mirrors classic OffSec format)

```
1. Cover page
   - Course / exam (AI-300 / OSAI)
   - Candidate: <my name>, OSID: <id>
   - Date range of exam
   - Document version
2. Executive summary
   - 1 page max, plain English
   - Critical findings, in business terms, no jargon
3. Methodology
   - Phases I followed (recon → enum → exploit → post-exploit → report)
   - Tools used (with versions)
   - Scope statement (in-scope / out-of-scope)
4. Findings
   - One section per finding, in severity order
   - Each finding follows the writeup template
5. Appendix
   A. Tool outputs / raw transcripts
   B. Payloads used (full, verbatim)
   C. Network / API captures
   D. Cleanup performed (memory entries / docs removed)
```

## Per-finding structure (copy `templates/finding-writeup.md`)

```
### Finding N — <Title>

| Field | Value |
|-------|-------|
| Target | <target name + version> |
| Channel | <user prompt / doc upload / RAG / EXIF / …> |
| Class | <PI / IPI / JB / TA / RAG / MM / EX / MX> |
| OWASP LLM | LLM0X |
| ATLAS | AML.TXXXX |
| Severity | Critical / High / Medium / Low |
| Status | Confirmed |

**Summary** — one paragraph.

**Steps to reproduce** — numbered, copy-pastable.

**Payload** — fenced code block, verbatim.

**Evidence** — screenshots, log lines, callbacks (with timestamps).

**Impact** — what an attacker gains; why it matters.

**Remediation** — practical, specific to the finding.

**References** — links to ATLAS / OWASP / vendor docs.
```

## Executive summary template I use

```
During the AI-300 exam window (DATE - DATE), I assessed <target description>
for AI/LLM-specific security risks. The assessment identified N findings,
including X critical, Y high, Z medium severity issues.

The most impactful findings were:

1. <one-line title> — <one-line business impact>
2. <one-line title> — <one-line business impact>
3. <one-line title> — <one-line business impact>

The root causes cluster into <one or two themes — e.g., "lack of trust
boundary between retrieved content and instructions" and "over-broad tool
scope">.

Recommended near-term actions:
- <action>
- <action>
- <action>
```

## What I never put in the report

- Speculative impact ("an attacker *could* have…") without proof
- Payloads I didn't test against the actual target
- Cleanup-not-yet-done items (I always finish cleanup *before* submitting)
- "I tried X and it didn't work" — only confirmed findings, unless the
  failure itself is the finding

## Sanity checks before submission

- [ ] Each finding has a verbatim payload
- [ ] Each finding has at least one screenshot OR callback log
- [ ] Each finding has a remediation that's *specific*, not generic
- [ ] Cleanup section enumerates every persistent change I made
- [ ] Tool versions are pinned (e.g., `garak 0.10.x`, `pyrit 0.6.x`)
- [ ] Page numbers, ToC, headers all consistent
