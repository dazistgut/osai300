# Payloads

Raw, reusable payload strings. I `cat` / `rg` these directly during the
exam — no analysis, no commentary, just *the strings*.

| Folder | Contents |
|--------|---------|
| [prompt-injection/](prompt-injection/) | Direct PI strings — one per line for ffuf/Burp Intruder/Garak custom |
| [indirect-injection/](indirect-injection/) | Payloads designed to be embedded in docs, pages, emails |
| [jailbreaks/](jailbreaks/) | Published JB prompts (named) |
| [multimodal/](multimodal/) | Image / audio / EXIF carriers, encoded text in images |
| [exfil/](exfil/) | Exfil channel payloads (markdown image, redirector, DNS) |

## How I organise files

- `*.txt` — one payload per line (for tools that consume line-delimited).
- `*.md` — annotated payloads (named, with target/version notes).
- Each folder has a `README.md` indexing its contents.

## Discipline

- Verbatim — no edits "for taste". Edits ruin reproducibility.
- Tag each entry with what target it worked against (model + version + date).
- If a payload is retired (no longer works on the target), I move it to
  `*.retired.md` rather than delete — useful for the report timeline.
