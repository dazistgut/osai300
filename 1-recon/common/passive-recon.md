# Passive Recon

Seeded reference. Stuff I can gather without sending suspicious prompts to
the target — useful when stealth matters or when I'm scoping before active
work.

## Public docs / surfaces

- `robots.txt` and `sitemap.xml` of the host site — often references
  `/api/chat`, `/v1/`, `/copilot`, etc.
- `.well-known/` paths — sometimes lists AI/MCP endpoints.
- The product's public docs / changelog — they usually name the model
  vendor (OpenAI / Anthropic / Bedrock / Vertex / Azure / Cohere) and
  feature flags.
- Marketing / blog posts — model family is often boasted about.
- Status page — endpoint names leaked in incident reports.

## HTTP-only fingerprints (no prompt sent)

```bash
# Headers only
curl -sSI $URL

# Capture all + body of an OPTIONS request (CORS hint)
curl -sS -X OPTIONS $URL -i
```

Things I look for:

- `Server`, `X-Powered-By` headers
- CSP directives — sometimes name vendor endpoints (e.g., `api.openai.com`)
- Cookie names — `__Secure-next-auth.session-token` → Next.js stack, etc.
- `X-Vercel-*`, `X-Fly-Request-Id`, `cf-ray` → host
- 401/403 body — sometimes reveals upstream framework

## JavaScript / network analysis (web targets)

In browser devtools:

- **Network tab** while sending a single test message. Look at the request
  shape, headers, and the response stream format (`data: {…}\n\n` SSE vs
  newline-delimited JSON vs single JSON blob).
- **Sources** — search bundled JS for `system_prompt`, `instructions`,
  `model:`, `temperature:`, `tools:`, `function_call`, vendor SDK names.
- WebSocket frames if used.

```bash
# Pull and search frontend bundles
curl -sS $URL/_next/static/chunks/*.js | grep -oE '"(model|temperature|top_p|max_tokens|system|tools)":[^,]+' | sort -u
```

## Repo / package recon

If the target is open-source or has a public repo:

```bash
# Find prompts
rg -i "you are an" .
rg -i "system_prompt|system_message" .

# Find tool definitions
rg "tools?\s*=\s*\[" .

# Find env / API key references (helps me understand auth model)
rg -i "OPENAI_API_KEY|ANTHROPIC_API_KEY|AZURE_OPENAI|BEDROCK"
```

If there's a `package.json` / `requirements.txt` / `pyproject.toml`,
look at dependencies: `langchain`, `llamaindex`, `autogen`, `crewai`,
`semantic-kernel`, `openai`, `anthropic`, `instructor`, `guardrails-ai`,
`promptfoo` (defender), `garak` (defender), `rebuff` (defender).

## OSINT for the operator

- GitHub Code Search for the company's distinctive prompt strings (try the
  product's slogan or persona name).
- HuggingFace org pages — they sometimes publish fine-tunes or eval datasets.
- The CISO / security blog — names tooling and known issues.

## My passive-recon checklist

- [ ] Captured all HTTP headers on a benign request
- [ ] Captured response shape (SSE/JSON/etc.)
- [ ] Grepped frontend bundles for config keys
- [ ] Checked `robots.txt`, `sitemap.xml`, `.well-known/`
- [ ] Read product docs / changelog for model vendor
- [ ] Checked GitHub for the org / project
- [ ] Listed inferred stack: vendor, framework, defenders
