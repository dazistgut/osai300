# Fuzzers — ffuf / wfuzz / custom

For HTTP-level enumeration (paths, params, vhosts) against the **hosting
stack** of an AI app — not the model itself. The model gets Garak / PyRIT;
the host gets ffuf.

## ffuf — my default

```bash
# Path discovery
ffuf -u https://target.example/FUZZ \
     -w /usr/share/seclists/Discovery/Web-Content/common.txt \
     -mc 200,301,302,401,403 \
     -fs 0

# Param discovery (POST body)
ffuf -u https://target.example/api/chat \
     -X POST -H 'Content-Type: application/json' \
     -d '{"FUZZ":"value"}' \
     -w params.txt \
     -mc 200 -fc 400

# Subdomain (vhost)
ffuf -u https://target.example/ \
     -H 'Host: FUZZ.target.example' \
     -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt \
     -mc 200,301,302
```

## Wordlists worth having

- `/usr/share/seclists/Discovery/Web-Content/raft-medium-words.txt`
- `/usr/share/seclists/Discovery/Web-Content/api/api-endpoints.txt`
- `/usr/share/seclists/Discovery/Web-Content/api/objects.txt`
- A custom AI-app list (I keep one in this folder — see below)

## My AI-flavoured path/param list (drop into ffuf)

Common paths I always test:

```
api/chat
api/completions
api/generate
api/embed
api/embeddings
api/models
api/conversations
api/messages
api/feedback
api/tools
api/agents
api/runs
api/threads
api/files
api/upload
api/admin
api/internal
v1/chat/completions
v1/completions
v1/embeddings
v1/models
v1/files
v1/threads
v1/runs
v1/assistants
mcp/servers
mcp/tools
.well-known/openai
.well-known/ai-plugin.json
```

Common JSON params worth fuzzing into a request body:

```
prompt
messages
input
query
question
system
system_prompt
instructions
context
model
temperature
top_p
top_k
max_tokens
stop
stream
tools
tool_choice
functions
function_call
metadata
conversation_id
thread_id
user
```

## When ffuf is the wrong hammer

If I'm looking for *content* in responses (e.g., "did the model leak X?")
not *paths*, Garak or PromptFoo are better fits.

## Tips

- `-rate 10` to avoid tripping rate limits on the target's chat endpoint.
- `-recursion -recursion-depth 2` for nested-path discovery.
- `-of json -o results.json` to keep machine-readable output for the report.
- For SSE / streaming endpoints, ffuf's match-by-status is reliable;
  match-by-size isn't (length varies wildly).
