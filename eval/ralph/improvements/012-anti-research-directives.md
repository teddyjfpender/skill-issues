# 012: Anti-Research Directives in Prompts

## Problem

LLMs, especially when using agentic tools like Codex, tend to explore and research the codebase before generating code. While valuable for understanding tasks, this behavior is counterproductive when:
- All necessary context is provided in the prompt
- Speed is important
- The task is well-defined

## Evidence

Without directives, Codex ran 50+ search commands:
```
item_1: rg "Zero" -n eval/work
item_3: rg "Option" -n eval/work
item_5: sed -n '1,40p' eval/work/cairo-fixed-point-q128-01/src/lib.cairo
item_7: rg "Add<" -n eval/work
item_9: find /Users/... -maxdepth 5 -type d -name corelib
... (continued for 3+ minutes)
```

## Solution: Explicit Anti-Research Directives

### Tier 1: Clear Prohibition

```markdown
## CRITICAL INSTRUCTIONS - READ FIRST

**DO NOT RESEARCH OR EXPLORE THE CODEBASE.** Generate code immediately.

- You have ALL the information you need in this prompt
- DO NOT run grep, rg, find, or any search commands
- DO NOT read other files in the project
- DO NOT spend time researching import paths - they are provided below
- GENERATE CODE IMMEDIATELY based on the requirements
```

### Tier 2: Behavioral Limit

```markdown
If you run more than 2 commands before generating code, you are doing it wrong.
```

### Tier 3: Positive Guidance

```markdown
## Common Cairo Imports

Import these (they are NOT in prelude):
```cairo
use core::array::{Array, ArrayTrait};
use core::num::traits::{Zero, One};
```

DO NOT import these (they ARE in the prelude):
- Add, Sub, Mul, Div, Neg (arithmetic operators)
- Drop, Copy, Clone (memory traits)
- PartialEq, PartialOrd (comparison)
- Option, Some, None (option type)
```

### Tier 4: Closing Reminder

```markdown
## REMINDER: Generate code NOW. Do not search or explore.
```

## Prompt Structure with Directives

```markdown
# Cairo Code Generation - Step N of M

## CRITICAL INSTRUCTIONS - READ FIRST
[Anti-research directives]

## Language Reference
[Embedded skill content - provides all needed reference]

## Common Imports
[Explicit import guidance - removes need to search]

## Previously Verified Code
[Accumulated code - no need to read existing files]

## Step N Requirements
[Clear, specific requirements]

## Output Format
[Explicit format requirements]

## REMINDER: Generate code NOW.
```

## Effectiveness Metrics

| Directive Level | Avg Commands Before Code | Time to First Code |
|-----------------|-------------------------|-------------------|
| None | 50+ | 180+ sec |
| Tier 1 only | 10-20 | 90 sec |
| Tier 1 + 2 | 5-10 | 60 sec |
| All tiers | 0-2 | 30 sec |

## When to Allow Research

Research directives should be **removed** when:
- Task requires understanding existing codebase structure
- Prompt doesn't include all necessary context
- Task is exploratory (e.g., "find where X is implemented")
- Code needs to integrate with undocumented APIs

## Implementation Status

- [x] Added Tier 1 directives to step-loop prompts
- [x] Added Tier 2 behavioral limit
- [x] Added Tier 3 positive guidance (imports)
- [x] Added Tier 4 closing reminder
- [x] Tested effectiveness with Claude and Codex
- [ ] A/B test different directive strengths
- [ ] Add metrics tracking for research behavior
