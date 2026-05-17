# Tools

My cheatsheets for the tooling I'll lean on during the exam.

| Tool | Use for | Cheatsheet |
|------|---------|-----------|
| PyRIT | Microsoft's red-team framework, programmatic attack chains | [pyrit/](pyrit/) |
| Garak | NVIDIA LLM vulnerability scanner, probe-based | [garak/](garak/) |
| PromptFoo | Eval + red-team for prompts, CI-style | [promptfoo/](promptfoo/) |
| Burp Suite | HTTP interception for AI APIs | [burp/](burp/) |
| Fuzzers | ffuf / wfuzz / custom for endpoint + param fuzzing | [fuzzers/](fuzzers/) |

## My install / setup checklist (do this before exam day)

```bash
# PyRIT
pip install pyrit                      # core
pip install pyrit[all]                 # all integrations

# Garak
pip install garak                      # via pip
# or:
git clone https://github.com/NVIDIA/garak && cd garak && pip install -e .

# PromptFoo
npm install -g promptfoo

# Burp Community is fine for the exam (Pro is better but not required)

# ffuf
go install github.com/ffuf/ffuf@latest
# or download release binary

# Useful extras
pip install rich                       # pretty terminal output
pip install httpx[http2]               # async HTTP
pip install python-multipart           # for file uploads
```

## My tool-choice decision tree

```
Do I need to scan-many-attacks-fast against an HTTP endpoint?
  → Garak (probe-based, batteries-included)

Do I need to script a custom multi-step attack with conversation state?
  → PyRIT (orchestrators, converters, memory)

Do I want CI-style assertions on prompt behaviour?
  → PromptFoo

Do I need to see / modify HTTP traffic?
  → Burp (intercept + repeater + intruder)

Do I need to enumerate paths / params on the host?
  → ffuf / wfuzz

Custom thing not covered?
  → Python + httpx + a payload list from payloads/
```
