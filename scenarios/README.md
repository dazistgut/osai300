# Scenarios

My per-lab / per-target working notes. One file per scenario, named
`<YYYY-MM-DD>-<slug>.md`, copied from
[../templates/scenario-note.md](../templates/scenario-note.md) at the
start of each engagement.

## Naming

```
scenarios/
├── 2026-05-17-acme-rag-chatbot.md
├── 2026-05-17-acme-agent-mailer.md
└── 2026-05-18-acme-multimodal-vision.md
```

- Date prefix sorts chronologically — useful for the report timeline.
- Slug is `<target>-<target-type>` or `<target>-<short-descriptor>`.
- Keep one file per *target*, not per attempt — attempts go in the
  exploitation log inside the file.

## Lifecycle

1. Copy [../templates/scenario-note.md](../templates/scenario-note.md) →
   `scenarios/<date>-<slug>.md`.
2. Fill in metadata + recon before touching exploitation.
3. Log every attempt (success and failure) in the exploitation table —
   the failures matter for the report timeline.
4. When the scenario closes: tick the cleanup checklist, then mark
   `Status: closed` in the metadata block.
5. For each confirmed finding, copy
   [../templates/finding-writeup.md](../templates/finding-writeup.md)
   into the final report.

## What goes here vs. elsewhere

| Goes in `scenarios/` | Goes elsewhere |
|----------------------|----------------|
| Target-specific facts and timeline | General technique notes → phase folders |
| Links to payloads I used | The payloads themselves → [../payloads/](../payloads/) |
| Confirmed findings (draft form) | Final write-up → [../5-reporting/](../5-reporting/) |
| Cleanup checklist for this target | — |

## Sensitive data

Anything containing real target identifiers, secrets, or captured
artifacts goes in `*.local.md` (gitignored) or in
[../.scratch/](../) (also gitignored). Tracked scenario files should be
sanitized enough that I'd be comfortable showing them to a peer
reviewer.
