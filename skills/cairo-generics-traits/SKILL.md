---
name: cairo-generics-traits
description: Explain Cairo generics and traits at a high level, including monomorphization and code size impact; use when a request asks why generics/traits reduce duplication, how trait bounds relate to generics, or why contract size increases with generics.
---

# Cairo Generics and Traits Overview

## Overview
Provide conceptual guidance on generics and traits, including when to use them and tradeoffs like monomorphization.

## Quick Use
- Read `references/generics-traits.md` before answering.
- Use simple examples (like `Option<T>`) to explain placeholders for types.
- Call out monomorphization when users ask about binary or contract size.

## Response Checklist
- Identify duplicated logic that generics can remove.
- Explain that each concrete type produces a specialized implementation.
- Mention traits as behavior constraints for generic types.

## Example Requests
- "Why did my contract get bigger after adding generics?"
- "What do generics and traits buy me in Cairo?"
- "How do trait bounds relate to generics?"
