# Finding N — <Title>

My per-finding template for the exam report. I copy this block into the
Findings section of the final report, one copy per confirmed finding,
ordered by severity (Critical → Low). Shape matches
[5-reporting/common/exam-report-structure.md](../5-reporting/common/exam-report-structure.md).

---

### Finding N — <Title>

| Field | Value |
|-------|-------|
| Target | <name + version> |
| Channel | <user prompt / doc upload / RAG corpus / EXIF / audio / tool result / …> |
| Class | <PI / IPI / JB / TA / A2A / RAG / MM / EX / MX / AE / SC> |
| OWASP LLM | LLM0X — <name> |
| MITRE ATLAS | AML.TXXXX — <name> |
| Severity | Critical / High / Medium / Low |
| Status | Confirmed |
| Scenario | scenarios/<file>.md |

**Summary**

One paragraph. What the finding is, in plain language. No speculation.

**Severity rubric** (per [5-reporting/common/severity-scoring.md](../5-reporting/common/severity-scoring.md))

- Confidentiality:  <L / M / H>
- Integrity:        <L / M / H>
- Availability:     <L / M / H>
- Scope:            <single user / single tenant / cross-tenant>
- Auth required:    <unauth / authed any role / authed specific role>
- User interaction: <zero-click / some / high>
- Persistence:      <single conversation / single user / all future sessions>
- Detection:        <stealthy / moderate / loud>

If this finding crosses into traditional appsec (XSS via markdown render,
SSRF via tool, command injection via tool parameter), I also cite a CVSS
4.0 vector:

> CVSS 4.0: <score> (<vector>)

**Steps to reproduce**

Numbered, copy-pastable. Reader should be able to redo this with nothing
but the report.

1. 
2. 
3. 

**Payload** (verbatim — no edits)

```
<payload here, exactly as sent>
```

Source: [payloads/<path>](../payloads/)

**Evidence**

- Transcript: <path or quoted excerpt with timestamp>
- Screenshot: <path>
- Callback log line (if exfil): <quoted line with timestamp>

**Impact**

What an attacker gains. Concrete, demonstrated — not speculative. Tie
back to the rubric fields above.

**Remediation**

Specific to this finding. Not generic ("add input validation"). Examples
of specific:

- Strip / sandbox markdown image rendering for assistant output
- Move tool `<name>` behind a per-call user-confirmation gate
- Treat retrieved RAG chunks as data, not instructions (template-level
  segregation, e.g., `<context>…</context>` with downstream stripping)

**References**

- OWASP LLM Top 10: <link>
- MITRE ATLAS technique: <link>
- Vendor advisory (if any): <link>
- My repo cross-ref: [<phase>/<target>/](../<phase>/<target>/)
