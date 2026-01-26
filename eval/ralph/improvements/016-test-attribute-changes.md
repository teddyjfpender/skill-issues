# 016: Test Attribute Changes in snforge 0.55+

## Problem

Tests failed to compile with:
```
error: Plugin diagnostic: #[available_gas] can be used with named arguments only
 --> src/lib.cairo:533:5
    #[available_gas(1000000)]
    ^^^^^^^^^^^^^^^^^^^^^^^^^
```

## Root Cause

In snforge 0.55+, the `#[available_gas]` attribute syntax changed and was subsequently deprecated entirely. The old positional argument syntax is no longer supported.

## Evolution of Gas Attributes

### snforge < 0.50 (Old)
```cairo
#[test]
#[available_gas(1000000)]  // Positional argument
fn test_with_loop() {
    // ...
}
```

### snforge 0.50-0.54 (Transition)
```cairo
#[test]
#[available_gas(gas: 1000000)]  // Named argument required
fn test_with_loop() {
    // ...
}
```

### snforge 0.55+ (Current)
```cairo
#[test]
// No gas attribute needed - automatic tracking
fn test_with_loop() {
    // ...
}
```

## Solution

### For New Code
Simply omit the `#[available_gas]` attribute entirely:

```cairo
#[test]
fn test_matrix_operations() {
    let mut i = 0_u32;
    while i < 1000 {
        // Complex operations
        i += 1;
    };
    // snforge handles gas tracking automatically
}
```

### For Existing Code
Remove all `#[available_gas(...)]` attributes:

```bash
# Find files with the attribute
grep -r "available_gas" src/

# Remove the attribute lines
sed -i '' '/#\[available_gas/d' src/lib.cairo
```

## Other Test Attributes

### Still Valid
```cairo
#[test]
fn basic_test() { }

#[test]
#[ignore]
fn slow_test() { }

#[test]
#[should_panic(expected: ("error message",))]  // Note: tuple syntax
fn panicking_test() { }
```

### should_panic Syntax
```cairo
// OLD (may not work in newer versions)
#[should_panic(expected: "overflow")]

// NEW (tuple with trailing comma)
#[should_panic(expected: ("overflow",))]
```

## Skill Update

Updated `cairo-quirks/references/quirks.md`:

```markdown
### Tests Need Attributes

\`\`\`cairo
#[test]
fn test_addition() {
    // test code
}

#[test]
#[should_panic(expected: ("overflow",))]  // Note: tuple with trailing comma
fn test_overflow_panics() {
    // code that should panic
}

#[test]
fn test_with_loop() {
    // NOTE: #[available_gas] is deprecated in newer versions
    // For snforge 0.55+, gas tracking is automatic
    let mut i = 0_u32;
    while i < 100 {
        i += 1;
    };
}
\`\`\`

**NOTE**: The `#[available_gas(n)]` attribute is deprecated.
Do NOT use it. Tests run with automatic gas tracking in snforge 0.55+.
```

## Impact

This issue caused Step 12 (tests) to fail. All 12 test functions had the deprecated attribute. After updating the skill guidance, regenerated code omitted the attribute and compiled successfully.

## Checking snforge Version

```bash
# Check installed version
snforge --version

# In Scarb.toml
[dependencies]
snforge_std = "0.55.0"  # Check this version
```

## Implementation Status

- [x] Updated cairo-quirks skill
- [x] Updated SKILL.md checklist
- [x] Tested with snforge 0.55.0
- [x] Documented should_panic tuple syntax
- [ ] Add version detection to validation
- [ ] Create migration guide for older test code
