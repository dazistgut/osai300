# Severity Scoring (AI/LLM)

Seeded reference. Standard CVSS doesn't map cleanly to LLM findings. Here's
the rubric I use for scoring, drawing from OWASP, vendor guidance, and the
practical impact of the finding.

## My rubric (per finding)

Score each on **L/M/H**, then pick the dominant severity.

| Factor | Low | Medium | High |
|--------|-----|--------|------|
| **Confidentiality impact** | Public info | Internal info / system prompt | Secrets / PII / credentials |
| **Integrity impact** | Misleading answer in one turn | Persistent biased answers | Tool-call side effect that changes data |
| **Availability impact** | None | Degraded response | Lockout / DoS (cost spike) |
| **Scope** | Single user | Single tenant / org | Cross-tenant / all users |
| **Authentication required** | Authenticated, specific role | Authenticated, any role | Unauthenticated / pre-auth |
| **User interaction required** | High (multiple opt-ins) | Some interaction | Zero-click (passive consumption) |
| **Persistence** | Single conversation | Single user, multiple sessions | All future sessions (memory / RAG poisoning) |
| **Detection difficulty** | Loud | Moderate | Stealthy / no logs |

## Mapping to overall severity

- **Critical** — Cross-tenant impact, zero-click, persistent, secrets/credentials.
  Example: A2A pivot that exfils RAG corpus across all users via a single
  uploaded doc.
- **High** — Same-tenant data exfil, or unauthenticated PI causing tool
  misuse with side effects.
  Example: Markdown image exfil of full conversation history; agent
  triggered to send mail from corporate identity.
- **Medium** — System prompt leak, jailbreak that produces policy-violating
  but not directly harmful content, single-session injection without exfil.
- **Low** — Refusal style leaks model family; minor information disclosure;
  hallucination in non-critical paths.

## When CVSS *is* useful

If the finding crosses into traditional appsec (XSS via markdown render,
SSRF via tool, command injection via tool parameter), I score the
underlying issue using **CVSS 4.0** and cite both:

> Severity: High (AI rubric) / CVSS 8.6 (AV:N/AC:L/AT:N/PR:N/UI:N/VC:H/VI:H/VA:N/SC:H/SI:N/SA:N)

## What I *don't* do

- Inflate severity by speculating about chains I didn't demonstrate
- Use CVSS for things it can't represent (e.g., "model hallucinates in
  niche topic" — there's no Confidentiality/Integrity/Availability angle)

## Per-finding scoring block (drop into writeup)

```
**Severity:** High

**Rubric:**
- Confidentiality: High (leaks user conversation)
- Integrity:      Low
- Availability:   None
- Scope:          Single tenant
- Auth required:  Authenticated (any user)
- User interaction: Zero-click (markdown auto-renders)
- Persistence:    Single conversation
- Detection:      Stealthy (image src is opaque)
```
