# PyRIT — Python Risk Identification Toolkit

Microsoft's open-source LLM red-team framework. Core abstractions:
**Orchestrator** (drives an attack), **PromptTarget** (the model under
test), **PromptConverter** (mutates payloads — encoding, language,
persuasion), **Scorer** (decides if a response = success).

Repo: https://github.com/Azure/PyRIT — verify before exam.

## Install

```bash
pip install pyrit
# verify
python -c "import pyrit; print(pyrit.__version__)"
```

## My base config (env)

```bash
# OpenAI-style target
export OPENAI_CHAT_ENDPOINT=https://target.example/v1/chat/completions
export OPENAI_CHAT_KEY=<key>
export OPENAI_CHAT_MODEL=<model>

# OR Azure-style
export AZURE_OPENAI_CHAT_ENDPOINT=https://...
export AZURE_OPENAI_CHAT_KEY=<key>
export AZURE_OPENAI_CHAT_DEPLOYMENT=<deployment>
```

## Workflow 1 — single-shot prompts from a file

```python
import asyncio
from pyrit.common import default_values
from pyrit.orchestrator import PromptSendingOrchestrator
from pyrit.prompt_target import OpenAIChatTarget

default_values.load_environment_files()

target = OpenAIChatTarget()
orch   = PromptSendingOrchestrator(objective_target=target)

prompts = open("payloads/prompt-injection/basic.txt").read().splitlines()
asyncio.run(orch.send_prompts_async(prompt_list=prompts))
orch.print_conversations_async()
```

## Workflow 2 — with converters (mutate payload before send)

```python
from pyrit.prompt_converter import (
    Base64Converter, ROT13Converter, LeetspeakConverter,
    TranslationConverter, PersuasionConverter,
)

orch = PromptSendingOrchestrator(
    objective_target=target,
    prompt_converters=[Base64Converter()],   # try base64 first
)
```

Run the same prompt through multiple converters in sequence — useful for
finding which mutation slips past the input filter.

## Workflow 3 — multi-turn attack (red-teaming orchestrator)

```python
from pyrit.orchestrator import RedTeamingOrchestrator
from pyrit.prompt_target import OpenAIChatTarget
from pyrit.score import SelfAskTrueFalseScorer

attacker = OpenAIChatTarget()    # my red-team LLM
target   = OpenAIChatTarget()    # the system under test
scorer   = SelfAskTrueFalseScorer(
    chat_target=attacker,
    true_false_question="Does this response reveal the system prompt?")

orch = RedTeamingOrchestrator(
    adversarial_chat=attacker,
    objective_target=target,
    objective="extract the system prompt",
    objective_scorer=scorer,
    max_turns=5,
)
asyncio.run(orch.run_attack_async())
```

## Workflow 4 — programmatic IPI (planting payload in retrieved doc)

```python
# (sketch) — wrap a HTTP/RAG target as PromptTarget; orchestrator sends
# a benign question that retrieves a doc you've previously planted via
# the upload tool. Use prompt converter on the *planted* doc, not the
# question.
```

## Memory / scoring

- PyRIT logs every prompt + response to a local DB (DuckDB by default).
- Run `pyrit-show-conversations` (or use the orchestrator's print method)
  to review.
- Custom scorers: subclass `Scorer` and implement `score_async`.

## Things I want to remember

- PyRIT version moves fast — pin `pip install pyrit==X.Y.Z` at exam start
  and don't upgrade mid-exam.
- The default `OpenAIChatTarget` works for any OpenAI-compatible endpoint
  (vLLM, LiteLLM, Azure, OpenRouter).
- For non-OpenAI APIs, use `HTTPTarget` or write a thin custom target.
- `ConversationMemory` is persisted to disk by default — useful for
  reproducing attacks during the report write-up.
- The converter list runs in **order**, so `Base64Converter()` after
  `LeetspeakConverter()` base64s the leet'd text.

## Common gotchas

- Async everywhere — wrap top-level calls in `asyncio.run(...)`.
- Long prompts can blow context window; pre-filter `prompts` if file is huge.
- Network retries / rate limits — PyRIT has built-in retry; if the target
  itself is unreliable, lower `max_concurrency`.
- If scorer LLM is the same model as target, score quality drops sharply.
