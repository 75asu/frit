# Social Post Pattern — frit

## Platforms
Twitter and LinkedIn — same content for both every time.

## Twitter character budget
- Total: 280 chars
- Each URL counts as 23 chars regardless of length
- Three URLs = 69 chars reserved
- Text budget: 211 chars max (including newlines)

## Structure

```
[what got built — lowercase, declarative, one line]

[the infra primitive or component — CAPS, then dash, then what it does]
[the mechanism — one line, how it connects to the next layer]

[verification stat — concrete number or result]

next: [what comes next in the milestone map]

[closing line — see rotating options below]
75asu.github.io/frit/
kiln.binarysquad.org
truss.binarysquad.org
```

## Rules
- All lowercase except infra primitives and product names (FLUX, VAULT, GPU OPERATOR, DCGM, vLLM, etc.)
- No em dashes — use regular hyphen ( - ) only
- No exclamation marks
- No emojis
- No hype words (revolutionary, game-changing, production-ready, etc.)
- Specific numbers beat vague claims ("phi3 engine 1/1 Running in 14 min from cold" beats "fast startup")
- Always all three URLs at the bottom, every single post, no exceptions

## Closing line — rotating options

The closing line goes between "next: X" and the URLs. Rotate — don't repeat.

### Fixed options
| Line | Vibe |
|---|---|
| `the receipts:` | proof of work |
| `shipping in public:` | indie signal |
| `what this actually builds:` | connects lab work to products |
| `one T4, full stack:` | constraint-driven, specific |

### Repeatable formula
`the [today's component] behind these:` — ties the day's infra work to the products.

Examples:
- flux day: `the gitops behind these:`
- vault day: `the secrets behind these:`
- gpu operator day: `the gpu stack behind these:`
- vllm day: `the inference behind these:`
- dcgm day: `the observability behind these:`
- slo day: `the reliability behind these:`

## File naming
`twitter-linkedin-DDMMMYYYY[-topic].txt`
Example: `twitter-linkedin-26may2026-platform-zero.txt`
