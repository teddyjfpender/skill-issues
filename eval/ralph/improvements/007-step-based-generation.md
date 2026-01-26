# Feature Improvement: Step-Based Code Generation

**ID**: 007
**Status**: Open
**Priority**: Critical
**Created**: 2026-01-26

## Problem

The current ralph-loop generates ALL code in one shot, then validates. This leads to:
- Long generation times (5+ minutes before any feedback)
- Wasted work (if one part fails, everything must be regenerated)
- Poor error context (errors could be anywhere in a large codebase)
- Difficult debugging (hard to tell which requirement caused which error)

## Proposed Solution: Step-Based Generation

Break the task into sequential steps. Generate and validate each step before moving to the next.

### Step Format in Prompts

Prompts should be structured with explicit steps:

```markdown
### Step 1: Define Matrix Struct
Create the Matrix<T> struct with rows, cols, and data fields.
Add #[derive(Drop, Clone, Debug)].

### Step 2: Define MatrixTrait
Create MatrixTrait with method signatures for new, zeros, identity, get.

### Step 3: Implement Basic Methods
Implement new, zeros, identity, get methods.

### Step 4: Add Arithmetic Operations
Implement add, sub, mul, scalar_mul.

### Step 5: Add Tests
Write comprehensive tests for all operations.
```

### Generation Flow

```
For each step 1..N:
    1. Build prompt with:
       - Step requirements
       - Previous verified code (accumulated)
       - Skill references

    2. Generate code for THIS STEP only

    3. Merge with previous code

    4. Validate (build, optionally test)

    5. If PASS:
       - Save verified code
       - Move to next step

    6. If FAIL:
       - Extract error feedback
       - Retry step (up to max_retries)
       - If max retries exceeded, report failure
```

### Benefits

1. **Fast feedback**: ~30 seconds per step vs 5+ minutes for all
2. **Incremental progress**: Steps 1-3 pass? That code is safe
3. **Targeted errors**: "Step 4 failed" is clearer than "somewhere in 500 lines"
4. **Better prompts**: Smaller, focused requirements per step
5. **Resumable**: Can restart from last successful step

## Reference: Isabelle Step-Loop Pattern

From `isabella-crypto/ralph/step-loop-v2.sh`:

```bash
# Count steps in prompt
count_steps() {
    grep -c "^### Step [0-9]" "$1"
}

# Main loop
for step in $(seq 1 $total_steps); do
    # Extract step requirements
    extract_step_content "$prompt_file" "$step"

    # Generate code for this step
    generate_step_code "$step" "$accumulated_code"

    # Validate
    if validate_step "$step"; then
        accumulated_code+="$step_code"
        mark_step_complete "$step"
    else
        # Retry with error feedback
        retry_step "$step" "$error_output"
    fi
done
```

## Implementation Plan

1. **Update prompt format**: Add step markers to prompts
2. **Create step extractor**: Parse steps from prompt files
3. **Modify generation loop**: Generate per-step instead of all-at-once
4. **Accumulate code**: Build up verified code incrementally
5. **Track step progress**: Resume from last successful step

## Example: cairo-matrix-algebra-01 as Steps

```markdown
### Step 1: Core Structs and Imports
- Define Matrix<T> and Vector<T> structs
- Add necessary imports (Array, traits)
- Add derive macros

### Step 2: MatrixTrait Definition
- Define trait with all method signatures
- Include: new, zeros, identity, get, transpose

### Step 3: Basic Matrix Methods
- Implement new, zeros, identity
- Implement get, rows, cols, is_square

### Step 4: Matrix Arithmetic
- Implement add, sub (with dimension checking)
- Implement mul (matrix multiplication)
- Implement scalar_mul

### Step 5: Determinant Functions
- Implement det_2x2
- Implement det_3x3

### Step 6: Vector Operations
- Define VectorTrait
- Implement new, len, dot
- Implement matrix_vector_mul

### Step 7: Trait Implementations
- Implement PartialEq for Matrix and Vector
- Implement Add and Mul operators

### Step 8: Tests
- Test all operations
- Test edge cases (dimension mismatch, etc.)
```

## Success Metrics

- Each step completes in < 1 minute
- Total generation time reduced by 50%+
- Failed steps can be retried without restarting
- Clear visibility into which step failed and why
