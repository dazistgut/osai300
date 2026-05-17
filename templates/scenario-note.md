# Scenario: <short target name>

My working notes for one lab / target / box. I copy this whole file into
`scenarios/<YYYY-MM-DD>-<slug>.md` at the start of each new scenario and
fill it in as I go.

## Metadata

| Field | Value |
|-------|-------|
| Date opened | <YYYY-MM-DD> |
| Target | <name / URL / API endpoint> |
| Target type | generative-ai / rag / agent / agent2agent / multimodal |
| Scope | <in-scope endpoints, accounts, identities> |
| Out-of-scope | <explicit exclusions> |
| Time budget | <hours allotted> |
| Status | open / closed / submitted |

## 1 — Recon

What I fingerprinted before touching anything.

- Model family / version (how I confirmed it): 
- Provider / hosting (vendor, self-hosted, edge): 
- System prompt leak attempts: <link to transcript, payload used>
- Public docs / robots.txt / sitemap findings: 
- Auth model (anon / authed / per-tenant): 

Cross-reference: [1-recon/](../1-recon/)

## 2 — Enumeration

What the system actually exposes.

- Capabilities advertised vs. observed: 
- Tools / functions discovered (names + arg shapes): 
- RAG sources (if any): 
- Guardrails surfaced (refusal triggers, classifier names): 
- Rate limits / quota signals: 

Cross-reference: [2-enumeration/](../2-enumeration/)

## 3 — Exploitation log

Chronological. One row per attempt — successes AND failures, because the
failures matter for the report timeline.

| Time | Tag | Payload (ref) | Result | Notes |
|------|-----|---------------|--------|-------|
| HH:MM | PI / IPI / JB / TA / A2A / RAG / MM / EX / MX | `payloads/<path>` or inline | success / partial / blocked | what the model said / what surfaced |

Verbatim payloads I used live under [payloads/](../payloads/) — I link to
them here rather than pasting, so the exploitation log stays scannable.

Cross-reference: [3-exploitation/](../3-exploitation/)

## 4 — Post-exploitation

What I did with the foothold.

- Data I exfiltrated (what, channel, evidence link): 
- Persistence I established (memory entry, RAG poison, doc upload): 
- Pivots attempted (A2A, tool chain, identity reuse): 
- Cleanup checklist (every persistent change I need to undo before
  submission):
  - [ ] 
  - [ ] 

Cross-reference: [4-post-exploit/](../4-post-exploit/)

## 5 — Evidence captured

- Transcripts: <path>
- Screenshots: <path>
- HTTP captures (`.har`, `.pcap`): <path — these are gitignored>
- Callback logs (exfil server): <path>

## 6 — Findings drafted from this scenario

One bullet per finding I'll write up. Each becomes a copy of
`templates/finding-writeup.md` under [5-reporting/](../5-reporting/).

- [ ] <Finding title> — severity <L/M/H/Crit> — payload ref: <path>
- [ ] 

## 7 — Open questions / things I didn't get to

So I know what's left if I come back to this target.

- 
- 
