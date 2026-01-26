# 018: Prompt Structure Standards

## Problem

Inconsistent prompt structure led to:
- Incorrect step extraction
- Unclear validation requirements
- Ambiguous output expectations

## Recommended Prompt Structure

### Document-Level Structure

```markdown
# Task Title

Brief description of the overall task.

## Context

Background information, constraints, and goals.

## Steps

### Step 1: Short Descriptive Title

Brief description of what this step accomplishes.

**Requirements:**
- Requirement 1
- Requirement 2
- Requirement 3

**Validation:** `scarb build`

### Step 2: Next Step Title

...

## Constraints

- Global constraint 1
- Global constraint 2

## Deliverable

Description of final expected output.
```

### Step-Level Structure

Each step should have:

1. **Header**: `## Step N: Title` (must match parsing regex)
2. **Description**: 1-2 sentence overview
3. **Requirements**: Bullet list of specific items to implement
4. **Validation**: Explicit command (`scarb build` or `snforge test`)

```markdown
## Step 3: Basic Matrix Implementation

Implement construction and accessor methods.

**Requirements:**
- Create `impl MatrixImpl<T, +Drop<T>, +Copy<T>, ...> of MatrixTrait<T>`
- Implement `new`: validate `data.len() == rows * cols`, return `Option`
- Implement `zeros`: create matrix filled with `Zero::zero()`
- Implement `identity`: create n×n matrix with `One::one()` on diagonal
- Implement `get`: bounds-check, return `Option<@T>`
- Implement `get_unchecked`: direct array access
- Implement `rows`, `cols`, `is_square`: simple accessors

**Validation:** Code compiles with `scarb build`
```

## Validation Types

### Build Validation
```markdown
**Validation:** Code compiles with `scarb build`
```

Use for steps that add:
- Struct definitions
- Trait definitions
- Impl blocks
- Helper functions

### Test Validation
```markdown
**Validation:** All tests pass with `snforge test`
```

Use for steps that add:
- Test functions
- Test module setup
- Integration tests

## Parsing Requirements

### Step Header Format
```
## Step N: Description
```

- Must start with `## Step `
- Followed by step number (1-99)
- Colon and description are optional but recommended
- No other markdown on the header line

### Step Number Extraction
```python
step_pattern = re.compile(r'^## Step (\d+)', re.MULTILINE)
```

### Step Content Boundaries

Content ends at:
- Next `## Step N` header
- Next `## ` section (e.g., `## Constraints`)
- `---` separator
- End of file

## Anti-Patterns

### Don't: Nested Numbering
```markdown
## Step 1
### 1.1 Sub-step    <!-- Parser won't find this -->
### 1.2 Sub-step
```

### Don't: Missing Validation
```markdown
## Step 4: Transpose
Implement transpose operation.
<!-- No validation specified - unclear when step is complete -->
```

### Don't: Vague Requirements
```markdown
## Step 5: Operations
Implement the operations.    <!-- Which operations? -->
```

### Don't: Multiple Validations
```markdown
**Validation:** `scarb build` and `snforge test`  <!-- Pick one per step -->
```

## Best Practices

1. **One validation per step**: Either build or test, not both
2. **Specific requirements**: List each function/struct to implement
3. **Incremental complexity**: Each step builds on previous
4. **Test steps last**: Steps 1-N-1 for code, step N for tests
5. **Clear boundaries**: Use consistent section markers

## Example: 12-Step Prompt

```markdown
## Steps

## Step 1: Imports and Core Structs
## Step 2: Trait Definition
## Step 3: Basic Implementation
## Step 4: Transpose
## Step 5: Arithmetic Operations
## Step 6: Determinant Functions
## Step 7: Vector Operations
## Step 8: PartialEq Implementations
## Step 9: Operator Traits
## Step 10: Test Module Setup
## Step 11: Construction Tests
## Step 12: Operation Tests

## Constraints
...
```

## Implementation Status

- [x] Documented standard structure
- [x] Created parsing requirements
- [x] Listed anti-patterns
- [x] Provided complete example
- [ ] Create prompt template generator
- [ ] Add prompt linter/validator
- [ ] Create VS Code snippet for step structure
