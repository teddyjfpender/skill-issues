# Rubrics

This directory contains evaluation rubrics for the step-loop system. Each rubric defines objective pass/fail criteria for validating generated code.

## Quick Reference

```bash
# Rubrics are auto-matched by prompt ID
./skill-issues run cairo-trapping-rain-water-01
# ↳ Looks for: eval/rubrics/cairo-trapping-rain-water-01.md
#              eval/rubric/cairo-trapping-rain-water-01.md

# Create from template (simple)
cp eval/rubric/_template-simple.md eval/rubric/cairo-<topic>-01.md

# Create from template (detailed)
cp eval/rubric/_template-detailed.md eval/rubric/cairo-<topic>-01.md
```

---

## Rubric Formats

Two formats are supported based on complexity:

### Simple Format (Single-Step Prompts)

For straightforward, one-shot tasks:

```markdown
# Rubric for <prompt-id>

Pass if:
- The file compiles with `scarb build`
- <Requirement 1 is met>
- <Requirement 2 is met>

Fail if:
- <Anti-pattern 1 is present>
- <Anti-pattern 2 is present>
```

### Detailed Format (Multi-Step Prompts)

For complex, incremental tasks:

```markdown
# Rubric: <prompt-id>

## Evaluation Criteria

### Step 1: <Step Title> (Build)
- [ ] <Criterion 1>
- [ ] <Criterion 2>
- [ ] Code compiles with `scarb build`

### Step 2: <Step Title> (Build)
- [ ] <Criterion 1>
- [ ] <Criterion 2>
- [ ] Code compiles with `scarb build`

### Step N: Tests (Test)
- [ ] <Test case 1>
- [ ] <Test case 2>
- [ ] All tests pass with `snforge test`

## Scoring
- Steps 1-N: <points> each
- Total: <total> points
```

---

## Required Elements

| Element | Simple | Detailed | Purpose |
|---------|--------|----------|---------|
| `# Rubric` header | ✅ | ✅ | Identifies the rubric |
| `Pass if:` section | ✅ | ⚪ | Success criteria |
| `Fail if:` section | ✅ | ⚪ | Failure criteria |
| `## Evaluation Criteria` | ⚪ | ✅ | Detailed breakdown |
| `### Step N:` sections | ⚪ | ✅ | Per-step criteria |
| `## Scoring` | ⚪ | ✅ | Point allocation |

---

## Writing Effective Criteria

### 1. Be Objective and Testable

Every criterion should be verifiable without subjective judgment.

```markdown
# ❌ Bad - Subjective
- [ ] Code is well-written
- [ ] Algorithm is efficient

# ✅ Good - Objective
- [ ] Code compiles with `scarb build`
- [ ] Algorithm runs in O(n) time complexity
- [ ] Function `solve` returns correct result for input [1,2,3]
```

### 2. Check Existence, Then Correctness

Structure criteria from basic to specific:

```markdown
### Step 2: Binary Search (Build)
- [ ] Function `binary_search(arr: @Array<u32>, target: u32) -> Option<u32>` exists
- [ ] Returns `Option::Some(index)` when target is found
- [ ] Returns `Option::None` when target is not found
- [ ] Uses divide-and-conquer approach (not linear scan)
- [ ] Code compiles with `scarb build`
```

### 3. Include Validation Type

Mark each step with its validation method:

| Tag | Meaning | Tool |
|-----|---------|------|
| `(Build)` | Must compile | `scarb build` |
| `(Test)` | Must pass tests | `snforge test` |
| `(Lint)` | Must have no warnings | `scarb lint` |
| `(Format)` | Must be formatted | `scarb fmt --check` |

### 4. Test Edge Cases Explicitly

List specific test cases with expected outputs:

```markdown
### Step 5: Tests (Test)
- [ ] Test empty array: `[]` -> `0`
- [ ] Test single element: `[5]` -> `5`
- [ ] Test negative numbers: `[-1, -2, -3]` -> `-6`
- [ ] Test overflow case: `[u32::MAX, 1]` -> handles gracefully
- [ ] All tests pass with `snforge test`
```

### 5. Verify Algorithm Properties

For algorithmic problems, check implementation details:

```markdown
### Step 3: Optimized Solution (Build)
- [ ] `solve_optimized(input: @Array<u32>) -> u32` function exists
- [ ] Uses two-pointer technique (not nested loops)
- [ ] O(n) time complexity (single pass)
- [ ] O(1) space complexity (no auxiliary arrays)
- [ ] Produces same results as brute force
- [ ] Code compiles with `scarb build`
```

---

## Scoring Guidelines

### Point Allocation

| Step Type | Suggested Points |
|-----------|------------------|
| Setup/Imports | 5 |
| Core Algorithm | 10 |
| Optimized Algorithm | 10 |
| Public API/Trait | 5 |
| Test Suite | 10-15 |

### Scoring Formula

```markdown
## Scoring
- Steps 1-2: Setup (5 points each) = 10 points
- Steps 3-4: Algorithms (10 points each) = 20 points
- Step 5: Public API (5 points) = 5 points
- Step 6: Tests (15 points) = 15 points
- Total: 50 points

### Grade Thresholds
- 45-50: Excellent
- 35-44: Good
- 25-34: Acceptable
- < 25: Needs improvement
```

---

## Matching Prompts to Rubrics

Rubrics are matched to prompts by ID. The system checks:

1. `eval/rubrics/<prompt-id>.md` (preferred)
2. `eval/rubric/<prompt-id>.md` (fallback)

**Naming must match exactly:**

```
eval/prompts/cairo-binary-search-01.md
         ↓ matches ↓
eval/rubric/cairo-binary-search-01.md
```

---

## Rubric Template (Simple)

For single-step or simple prompts:

```markdown
# Rubric for <prompt-id>

Pass if:
- The file compiles with `scarb build`
- `<StructName>` struct exists with required fields
- `<TraitName>` trait exists with required methods
- `<ImplName>` implements `<TraitName>` correctly
- `<function_name>` produces correct output for examples

Fail if:
- Code does not compile
- Required struct/trait/impl is missing
- Implementation does not match specification
- Edge cases are not handled
```

---

## Rubric Template (Detailed)

For multi-step prompts:

```markdown
# Rubric: <prompt-id>

## Evaluation Criteria

### Step 1: <Setup Step Title> (Build)
- [ ] Imports required traits from core library
- [ ] Helper function `<name>` exists with correct signature
- [ ] Helper function `<name>` exists with correct signature
- [ ] Code compiles with `scarb build`

### Step 2: <Core Algorithm Step Title> (Build)
- [ ] Function `<name>(<params>) -> <return>` exists
- [ ] Handles empty input correctly (returns <expected>)
- [ ] Handles single element correctly
- [ ] Implements <algorithm approach> correctly
- [ ] Code compiles with `scarb build`

### Step 3: <Optimized Algorithm Step Title> (Build)
- [ ] Function `<name>(<params>) -> <return>` exists
- [ ] Uses <optimization technique>
- [ ] Achieves O(<time>) time complexity
- [ ] Achieves O(<space>) space complexity
- [ ] Produces same results as Step 2 implementation
- [ ] Code compiles with `scarb build`

### Step 4: <Public API Step Title> (Build)
- [ ] Trait `<Name>Trait` defined with required methods
- [ ] Impl `<Name>Impl` implements trait correctly
- [ ] `solve` method uses optimal implementation
- [ ] All algorithm variants accessible via trait
- [ ] Code compiles with `scarb build`

### Step 5: <Tests Step Title> (Test)
- [ ] Example 1 test: <input> -> <expected>
- [ ] Example 2 test: <input> -> <expected>
- [ ] Edge case test: empty input -> <expected>
- [ ] Edge case test: single element -> <expected>
- [ ] Edge case test: <description> -> <expected>
- [ ] All algorithm variants produce identical results
- [ ] All tests pass with `snforge test`

## Scoring
- Step 1: Setup (5 points)
- Step 2: Core Algorithm (10 points)
- Step 3: Optimized Algorithm (10 points)
- Step 4: Public API (5 points)
- Step 5: Tests (10 points)
- Total: 40 points
```

---

## Common Criteria Patterns

### Struct Existence
```markdown
- [ ] `Pair<T>` struct exists with `first: T` and `second: T` fields
```

### Trait Definition
```markdown
- [ ] `Swap<T>` trait exists with `swap(self: Pair<T>) -> Pair<T>` method
```

### Implementation
```markdown
- [ ] `PairSwap<T>` impl exists for `Swap<T>`
- [ ] Implementation includes required trait bounds: `+Drop<T>, +Copy<T>`
```

### Function Signature
```markdown
- [ ] `binary_search(arr: @Array<u32>, target: u32) -> Option<u32>` exists
```

### Algorithm Correctness
```markdown
- [ ] Uses divide-and-conquer (not linear scan)
- [ ] Correctly handles mid-point calculation without overflow
```

### Test Coverage
```markdown
- [ ] Tests exist in `#[cfg(test)] mod tests` block
- [ ] At least 5 test functions defined
- [ ] Edge cases covered (empty, single, boundary values)
```

### Build Validation
```markdown
- [ ] Code compiles with `scarb build`
- [ ] No compiler warnings
- [ ] No unused imports
```

### Test Validation
```markdown
- [ ] All tests pass with `snforge test`
- [ ] No test panics or timeouts
```

---

## Examples

| Rubric | Format | Steps | Description |
|--------|--------|-------|-------------|
| `cairo-trapping-rain-water-01` | Detailed | 6 | Full checklist with scoring |
| `cairo-generics-traits-01` | Simple | 1 | Pass/fail criteria only |
| `cairo-merge-k-sorted-lists-01` | Detailed | 4 | Algorithm verification |

See these files for reference implementations.

---

## Tips

- **Mirror the prompt**: Each prompt step should have a corresponding rubric step
- **Be specific**: Vague criteria lead to inconsistent evaluation
- **Test the rubric**: Manually verify criteria against known good/bad code
- **Version together**: When creating `prompt-02.md`, also create `rubric-02.md`
