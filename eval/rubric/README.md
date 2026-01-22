# Rubrics

- One file per prompt ID.
- Keep checks objective and deterministic.

Template:

```

Example rubric:
- `eval/rubric/cairo-generics-traits-01.md`
# Rubric for <prompt-id>

Pass if:
- The code compiles
- The generic trait uses correct bounds
- The public API matches the prompt

Fail if:
- Missing trait bounds
- Incorrect generic parameters

Notes:
- Add any edge cases worth checking
```
