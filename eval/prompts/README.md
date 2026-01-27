# Prompts

This directory contains task prompts for the step-loop evaluation system. Each prompt defines a coding challenge that the AI will solve incrementally.

## Quick Reference

```bash
# List available prompts
./skill-issues list

# Run a prompt
./skill-issues run <prompt-id>

# Create from template
cp eval/prompts/_template.md eval/prompts/cairo-<topic>-01.md
```

---

## Prompt Structure

Every prompt **must** follow this structure for the step-loop to parse it correctly:

```markdown
# Prompt ID: <language>-<topic>-<version>

Task:
- One-line summary of what to build

## Problem Description

Detailed explanation of the problem...

## Related Skills
- `skill-name-1`
- `skill-name-2`

## Context

Language-specific notes and gotchas...

---

## Step 1: <Step Title>

Description of what to implement in this step.

**Requirements:**
- Requirement 1
- Requirement 2

**Validation:** <validation-type>

---

## Step 2: <Step Title>

...

---

## Constraints

- Global constraints that apply to all steps

## Deliverable

What the final output should contain
```

---

## Required Sections

| Section | Required | Purpose |
|---------|----------|---------|
| `# Prompt ID:` | ✅ | Unique identifier, used for file naming |
| `Task:` | ✅ | One-line summary for logs and UI |
| `## Problem Description` | ✅ | Full problem statement with examples |
| `## Related Skills` | ⚪ | Skills to auto-load (optional) |
| `## Context` | ✅ | Language gotchas, critical notes |
| `## Step N:` | ✅ | Incremental implementation steps |
| `**Requirements:**` | ✅ | Checklist for each step |
| `**Validation:**` | ✅ | How to verify step completion |
| `## Constraints` | ✅ | Global rules and limitations |
| `## Deliverable` | ✅ | Final expected output |

---

## Step Design Best Practices

### 1. Progressive Complexity

Build from simple to complex. Each step should be independently verifiable.

```markdown
## Step 1: Setup and Helpers      ← Foundation
## Step 2: Naive Solution         ← Working but slow
## Step 3: Optimized Solution     ← Better algorithm
## Step 4: Public API             ← Clean interface
## Step 5: Tests                  ← Verification
```

### 2. Single Responsibility

Each step should do **one thing**. Avoid combining unrelated work.

```markdown
# ❌ Bad - Too much in one step
## Step 1: Implement sorting and searching with tests

# ✅ Good - Focused steps
## Step 1: Implement bubble sort
## Step 2: Implement binary search
## Step 3: Add test coverage
```

### 3. Clear Validation Criteria

Every step needs explicit validation. Use these standard types:

| Validation | Meaning |
|------------|---------|
| `Code compiles with scarb build` | Syntax/type checking only |
| `All tests pass with snforge test` | Must pass test suite |
| `Code compiles and lints clean` | No warnings allowed |

### 4. Explicit Function Signatures

Don't leave signatures ambiguous. Specify exact names and types.

```markdown
# ❌ Bad - Ambiguous
**Requirements:**
- Create a function to calculate the sum

# ✅ Good - Explicit
**Requirements:**
- Create function `sum(arr: @Array<u32>) -> u32`
- Return 0 for empty arrays
```

### 5. Include Edge Cases

List edge cases explicitly in requirements or test steps.

```markdown
**Requirements:**
- Handle empty array (return 0)
- Handle single element (return element)
- Handle negative numbers (use felt252)
```

---

## Context Section Guidelines

The `## Context` section is **critical** for language-specific knowledge. Include:

### Cairo-Specific Context

```markdown
## Context

**CRITICAL - No Inherent Impls**: Cairo does NOT support `impl Type { }`.
All methods must use traits.

**Array Access**: Use `arr.at(index)` which returns a snapshot.
Dereference with `*arr.at(i)`.

**Loops**: Use `while` loops with explicit index management.
Cairo has no `for` loops.

**No usize**: Cairo uses `u32` for array indexing.
```

### What to Include

- ⚠️ **Critical pitfalls** - Things that will definitely break
- 📝 **Syntax differences** - From familiar languages (Rust, Python)
- 🔧 **Required patterns** - Traits, derives, imports
- ❌ **Anti-patterns** - What NOT to do

---

## Naming Convention

```
<language>-<topic>-<version>.md
```

| Part | Description | Examples |
|------|-------------|----------|
| `language` | Target language | `cairo`, `rust`, `python` |
| `topic` | Problem domain | `trapping-rain-water`, `binary-search` |
| `version` | Iteration number | `01`, `02`, `03` |

**Examples:**
- `cairo-trapping-rain-water-01.md`
- `cairo-generics-traits-01.md`
- `cairo-merge-k-sorted-lists-01.md`

---

## Prompt Template

Create new prompts using this template:

```markdown
# Prompt ID: cairo-<topic>-01

Task:
- <One-line description of what to build>

## Problem Description

<Detailed problem statement>

**Example 1:**
- Input: <input>
- Output: <output>
- Explanation: <why>

**Example 2:**
- Input: <input>
- Output: <output>

## Related Skills
- `cairo-quirks`
- `cairo-quality`

## Context

**CRITICAL**: <Most important gotcha that will break things>

**<Topic>**: <Relevant language note>

---

## Step 1: <Foundation Step>

<What to set up first>

**Requirements:**
- <Requirement 1>
- <Requirement 2>

**Validation:** Code compiles with `scarb build`

---

## Step 2: <Core Implementation>

<Main algorithm or logic>

**Requirements:**
- Create function `<name>(<params>) -> <return>`
- <Behavior requirement>
- Handle <edge case>

**Validation:** Code compiles with `scarb build`

---

## Step 3: <Optimization or Variant> (Optional)

<Better algorithm or alternative approach>

**Requirements:**
- Create function `<name>(<params>) -> <return>`
- <Complexity requirement: O(n) time, O(1) space>

**Validation:** Code compiles with `scarb build`

---

## Step 4: <Public Interface>

<Clean API wrapper>

**Requirements:**
- Create trait `<Name>Trait` with method signatures
- Create impl `<Name>Impl` implementing the trait
- Add `solve` method using optimal solution

**Validation:** Code compiles with `scarb build`

---

## Step 5: <Tests>

<Comprehensive test coverage>

**Requirements:**
- Test Example 1: <input> -> <output>
- Test Example 2: <input> -> <output>
- Test edge case: <case> -> <expected>
- Test edge case: <case> -> <expected>

**Validation:** All tests pass with `snforge test`

---

## Constraints

- Must compile with `scarb build`
- Must pass all tests with `snforge test`
- Use `<type>` for all numeric values
- Handle edge cases: <list>

## Deliverable

Complete implementation with:
1. <Component 1>
2. <Component 2>
3. <Component 3>
4. Comprehensive test suite
```

---

## Generating a Prompt

### From a LeetCode Problem

1. Copy problem description and examples
2. Identify 3-5 incremental steps (naive → optimal)
3. Add Cairo-specific context
4. Define explicit function signatures
5. List all edge cases for tests

### From an Existing Codebase

1. Identify the core algorithm
2. Break into logical implementation phases
3. Note any language-specific patterns used
4. Create test cases from existing tests

### Tips

- **Start simple**: Step 1 should always compile trivially
- **End with tests**: Final step validates everything works
- **Be explicit**: Ambiguity causes failures
- **Include examples**: Input/output pairs are essential
- **Version prompts**: Create `-02` instead of editing `-01`

---

## Versioning

**Never edit existing prompts.** Create a new version instead.

```bash
# Original has issues
eval/prompts/cairo-binary-search-01.md

# Create improved version
eval/prompts/cairo-binary-search-02.md
```

This allows:
- Comparing results across versions
- Tracking prompt improvements
- Reproducible evaluations

---

## Examples

| Prompt | Steps | Complexity | Description |
|--------|-------|------------|-------------|
| `cairo-trapping-rain-water-01` | 6 | Hard | Three algorithms + tests |
| `cairo-generics-traits-01` | 1 | Easy | Single-step generic demo |
| `cairo-merge-k-sorted-lists-01` | 4 | Medium | Heap-based merge |

See these files for reference implementations.
