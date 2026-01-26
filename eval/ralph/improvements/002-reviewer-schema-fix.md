# Feature Improvement: Reviewer Schema Compatibility

**ID**: 002
**Status**: Fixed
**Priority**: High
**Created**: 2026-01-26

## Problem

The reviewer JSON schema was incompatible with Codex API's strict schema requirements. Codex requires all properties defined in a schema to also be listed in the `required` array.

## Error Message

```
Invalid schema for response_format 'codex_output_schema':
In context=('properties', 'issues', 'items'), 'required' is required to be supplied
and to be an array including every key in properties. Missing 'suggestion'.
```

## Root Cause

The `review-output.schema.json` defined `suggestion` as an optional property (not in `required` array), but Codex API enforces that all properties must be required.

## Fix Applied

Changed `eval/ralph/schema/review-output.schema.json`:
```json
// Before
"required": ["criterion", "severity", "description"]

// After
"required": ["criterion", "severity", "description", "suggestion"]
```

## Impact

- Reviewer step was failing silently and defaulting to "VALID" verdict
- No actual code review was happening before build verification
- This undermined the driver-reviewer collaboration pattern

## Lessons Learned

1. **Test schemas against target API**: Codex has stricter JSON schema requirements than standard JSON Schema
2. **Monitor reviewer output**: The loop should detect and report when reviewer fails
3. **Consider optional fields**: If a field should truly be optional, it may need to be excluded from the schema entirely for Codex compatibility

## Related Files

- `eval/ralph/schema/review-output.schema.json`
- `eval/ralph/build-reviewer-prompt.py`
