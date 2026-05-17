# Burp Suite — for AI APIs

Burp is still the most useful tool for **anything** that talks HTTP — and
that's essentially every wrapped AI product on the exam.

## Setup quickly

1. Start Burp Community.
2. Configure browser proxy (`127.0.0.1:8080`) — or use Burp's embedded
   Chromium.
3. Install Burp's CA cert in the browser/system trust store.
4. Test by visiting an HTTPS site through the proxy.

## Workflow against an AI chat UI

1. **Intercept** the first chat turn. Capture:
   - Endpoint path
   - Request body shape (`messages`, `prompt`, `model`, etc.)
   - Auth header (Bearer / Session / both)
2. **Send to Repeater** for hand-crafted payloads.
3. **Send to Intruder** for payload-bank fuzzing.
4. Use **Logger** / **HTTP history** to find side-tools (uploads,
   moderation, telemetry) the UI calls.

## High-value Burp workflows

### 1) Pivoting from the chat endpoint

Look at what *else* the page calls. Often I find:
- `/api/upload` — file ingest (RAG / multimodal channel)
- `/api/feedback` — sometimes echoes prompt back (XSS sink)
- `/api/conversations/<id>` — leaks history including system prompt
- `/api/profile` — custom instructions sink
- `/api/admin/...` — yes, sometimes exposed (improper-access-control)

### 2) Streaming response handling

LLM APIs often stream Server-Sent Events. Burp Repeater shows the raw
stream. To work with it:

```bash
# Save Burp request as curl, then run with -N to see streaming
curl -N -X POST $URL \
  -H "Authorization: Bearer $KEY" \
  -d '{"prompt":"X","stream":true}'
```

### 3) Intruder with prompt-injection wordlist

- Mark `{"role":"user","content":"§<payload>§"}` as the position.
- Load payload list from `payloads/prompt-injection/strings.txt`.
- Use "Grep — Extract" to pull the model's response field.
- Use "Grep — Match" to flag responses that contain `system`,
  `instructions`, `tool`, etc.

### 4) File-upload IPI

- Intercept the upload request.
- Replace the file body with a poisoned doc from
  `payloads/indirect-injection/`.
- Re-fire the upload, then ask the chatbot to summarise the doc.

### 5) Auth replay across users

If two test accounts exist, replay one's auth header against the other's
conversation IDs. Tests for IDOR — surprisingly common in AI wrappers.

## Burp extensions worth installing (community edition allows)

- **JSON Web Tokens** — decode/edit JWT auth.
- **Logger++** — searchable HTTP log.
- **Param Miner** — find hidden parameters (sometimes `system_prompt`,
  `model_override`, `temperature` are passable from client!).

## Tips I want to remember

- Many AI APIs accept extra fields silently — try
  `{"system": "<my prompt>", ...}` even if not in the original request.
- Some accept `model:` from the client → I can request a *different*
  underlying model than the UI offers (often less-aligned).
- `temperature`, `top_p`, `max_tokens` are sometimes client-controllable —
  cranking temp can bypass deterministic-refusal training.
- The `n` parameter (OpenAI) can return multiple completions in one call —
  cheaper jailbreak search.

## Gotchas

- HTTPS sites with HSTS / cert pinning may not work via proxy without
  hostile cert install.
- Streaming endpoints time out in Repeater quickly — duplicate to a
  scripted Python repro before chasing details.
