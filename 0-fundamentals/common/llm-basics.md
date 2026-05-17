# LLM Basics — quick refresher

Seeded reference. Things I want to be able to recall instantly on the exam.

## Tokens

- LLMs operate on **tokens**, not characters. Roughly 1 token ≈ 4 chars
  (English) or ~0.75 words.
- Most filter bypasses ride token boundaries: Unicode confusables, zero-width
  joiners, BPE-merge artefacts, base64, leetspeak.
- Tokenizer matters: GPT-4 / Claude / Llama use different vocabularies, so
  the same byte string tokenizes differently. A payload tuned for one model
  may need re-tuning for another.

## Sampling parameters

| Param | Effect | Why it matters for red teaming |
|-------|--------|------------------------------|
| `temperature` | randomness (0=greedy, >1=wild) | Higher temp → more refusal variance; helps bypass via retries |
| `top_p` (nucleus) | probability mass cutoff | Often left high in chatbots — exploitable |
| `top_k` | hard cap on candidate tokens | Rarely surfaced to user |
| `max_tokens` | output length cap | Sometimes triggers truncation-of-refusal bypass |
| `presence_penalty` / `frequency_penalty` | discourage repetition | Mostly irrelevant for RT |
| `stop` sequences | hard stop on substring | Worth probing — what stops the response? |

## Context window

- The **total** budget = system prompt + user turns + assistant turns +
  retrieved docs (for RAG) + tool results (for agents).
- Many attacks exploit context-window pressure: push earlier instructions
  out, or hide payloads past the model's effective attention.
- "Lost in the middle" — content in the middle of long contexts gets less
  attention than start/end. Useful for hiding *and* surfacing.

## System prompt

- The system prompt is the operator's primary control surface. Leaking it
  is usually finding #1.
- Typical contents I look for: persona, allowed/blocked topics, tool list,
  output format, refusal templates, references to env vars / secrets.

## Function / tool calling

- Most agent frameworks expose tools via a JSON schema (`name`, `description`,
  `parameters`). The **description** is read by the model — and is therefore
  an injection sink (a tool whose description includes "always call this with
  X" can be abused).
- Tool call is *chosen* by the model. So injection that biases the choice =
  injection that gets the tool called.

## Refusal styles (fingerprinting hints)

| Style | Often points to |
|-------|----------------|
| "I cannot and will not..." | GPT-4 class |
| "I'm not able to help with that." | Claude class |
| "As an AI language model..." | older GPT-3.5 / generic |
| "I cannot fulfill this request..." | Llama-Chat tuning |
| Highly verbose, policy-citing | GPT-4 / Claude with safety system prompt |

(These shift over time — I cross-check with HTTP-level fingerprinting.)
