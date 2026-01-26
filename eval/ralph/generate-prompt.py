#!/usr/bin/env python3
"""
Generate prompt files following the standards in improvement doc 018.

This generator creates well-structured prompts for Cairo development tasks
with proper step formatting, validation markers, and requirements sections.

Usage:
    # Interactive mode - answer questions to build a prompt
    python generate-prompt.py --interactive

    # Template mode - generate from predefined templates
    python generate-prompt.py --template cairo-library --name "my-vector-math" --steps 8
    python generate-prompt.py --template cairo-contract --name "my-token" --steps 6
    python generate-prompt.py --template cairo-algorithm --name "sorting" --steps 5

    # Output options
    python generate-prompt.py --template cairo-library --name "my-lib" --output prompts/my-lib.md
    python generate-prompt.py --template cairo-library --name "my-lib" --stdout
    python generate-prompt.py --template cairo-library --name "my-lib" --validate
"""

import argparse
import subprocess
import sys
from pathlib import Path
from typing import Optional


# Template definitions
TEMPLATES = {
    "cairo-library": {
        "description": "Generic library implementation",
        "base_steps": [
            {
                "title": "Imports and Core Structs",
                "description": "Create the foundation with imports and struct definitions.",
                "requirements": [
                    "Add necessary imports from core library",
                    "Define primary struct with appropriate fields",
                    "Add #[derive(Drop, Clone, Debug)] to structs",
                    "Add helper functions for common operations",
                ],
                "validation": "scarb build",
            },
            {
                "title": "Trait Definition",
                "description": "Define the trait with all method signatures (no implementation yet).",
                "requirements": [
                    "Define the main trait with generic type parameter",
                    "Include constructor signatures (new, from_* methods)",
                    "Include accessor signatures (get, len, etc.)",
                    "Include operation signatures (add, remove, transform, etc.)",
                ],
                "validation": "scarb build",
            },
            {
                "title": "Basic Implementation",
                "description": "Implement construction and accessor methods.",
                "requirements": [
                    "Create impl block with required trait bounds",
                    "Implement constructor with validation",
                    "Implement basic accessors using snapshot dereference (*self.field)",
                    "Handle edge cases with Option return types",
                ],
                "validation": "scarb build",
            },
        ],
        "feature_step_template": {
            "title": "Feature: {feature_name}",
            "description": "Implement {feature_name} functionality.",
            "requirements": [
                "Implement the core {feature_name} logic",
                "Handle edge cases appropriately",
                "Follow Cairo patterns for memory management",
            ],
            "validation": "scarb build",
        },
        "final_steps": [
            {
                "title": "Additional Operations",
                "description": "Implement remaining utility operations.",
                "requirements": [
                    "Implement any remaining trait methods",
                    "Add operator trait implementations (Add, Mul, etc.) if needed",
                    "Implement PartialEq for comparison operations",
                ],
                "validation": "scarb build",
            },
            {
                "title": "Tests",
                "description": "Create comprehensive test coverage.",
                "requirements": [
                    "Add #[cfg(test)] mod tests { ... }",
                    "Create helper functions for test data",
                    "Test construction with valid and invalid inputs",
                    "Test all operations with known values",
                    "Test edge cases and error conditions",
                ],
                "validation": "snforge test",
            },
        ],
    },
    "cairo-contract": {
        "description": "Starknet contract implementation",
        "base_steps": [
            {
                "title": "Storage and Events",
                "description": "Define contract storage and events.",
                "requirements": [
                    "Add Starknet imports: use starknet::ContractAddress;",
                    "Define #[starknet::contract] mod with storage struct",
                    "Define events with #[event] and #[derive(Drop, starknet::Event)]",
                    "Include storage variables for contract state",
                ],
                "validation": "scarb build",
            },
            {
                "title": "Interface Definition",
                "description": "Define the contract interface trait.",
                "requirements": [
                    "Define #[starknet::interface] trait with generic TContractState",
                    "Include all external function signatures",
                    "Use ref self: TContractState for write functions",
                    "Use self: @TContractState for view functions",
                ],
                "validation": "scarb build",
            },
            {
                "title": "Constructor",
                "description": "Implement the contract constructor.",
                "requirements": [
                    "Add #[constructor] function",
                    "Initialize all storage variables",
                    "Accept required initialization parameters",
                    "Emit initialization event if appropriate",
                ],
                "validation": "scarb build",
            },
        ],
        "feature_step_template": {
            "title": "Entry Point: {feature_name}",
            "description": "Implement {feature_name} external function.",
            "requirements": [
                "Add #[abi(embed_v0)] for the impl block if not already present",
                "Implement {feature_name} with appropriate access control",
                "Update storage state as needed",
                "Emit relevant events",
            ],
            "validation": "scarb build",
        },
        "final_steps": [
            {
                "title": "Tests",
                "description": "Create contract tests.",
                "requirements": [
                    "Add #[cfg(test)] mod tests with snforge imports",
                    "Use declare and deploy for contract deployment",
                    "Test constructor initialization",
                    "Test all entry points with valid inputs",
                    "Test access control and error conditions",
                ],
                "validation": "snforge test",
            },
        ],
    },
    "cairo-algorithm": {
        "description": "Algorithm implementation",
        "base_steps": [
            {
                "title": "Data Structures",
                "description": "Define data structures needed for the algorithm.",
                "requirements": [
                    "Add necessary imports",
                    "Define structs with appropriate fields",
                    "Add #[derive(Drop, Clone, Debug)] as needed",
                    "Define helper types or enums if needed",
                ],
                "validation": "scarb build",
            },
            {
                "title": "Core Algorithm",
                "description": "Implement the main algorithm logic.",
                "requirements": [
                    "Define the main algorithm function",
                    "Implement the core logic step by step",
                    "Handle base cases explicitly",
                    "Use appropriate data structures for intermediate results",
                ],
                "validation": "scarb build",
            },
        ],
        "feature_step_template": {
            "title": "Optimization: {feature_name}",
            "description": "Add {feature_name} optimization or variant.",
            "requirements": [
                "Implement {feature_name} variant of the algorithm",
                "Document time/space complexity",
                "Ensure correctness with edge cases",
            ],
            "validation": "scarb build",
        },
        "final_steps": [
            {
                "title": "Tests",
                "description": "Create comprehensive algorithm tests.",
                "requirements": [
                    "Add #[cfg(test)] mod tests { ... }",
                    "Test with empty/minimal inputs",
                    "Test with known values and expected outputs",
                    "Test edge cases (sorted, reverse-sorted, duplicates)",
                    "Test performance with larger inputs if applicable",
                ],
                "validation": "snforge test",
            },
        ],
    },
}


def format_step(step_num: int, title: str, description: str, requirements: list[str], validation: str) -> str:
    """Format a single step according to doc 018 standards."""
    req_lines = "\n".join(f"- {req}" for req in requirements)

    validation_text = (
        f"Code compiles with `{validation}`" if validation == "scarb build"
        else f"All tests pass with `{validation}`"
    )

    return f"""## Step {step_num}: {title}

{description}

**Requirements:**
{req_lines}

**Validation:** {validation_text}

---
"""


def generate_prompt_content(
    name: str,
    description: str,
    context: str,
    steps: list[dict],
    constraints: list[str],
    deliverable: str,
    related_skills: Optional[list[str]] = None,
) -> str:
    """Generate the full prompt content."""

    # Title from name
    title = name.replace("-", " ").title()
    prompt_id = f"cairo-{name.lower().replace(' ', '-')}-01"

    # Build content
    content = f"# Prompt ID: {prompt_id}\n\n"
    content += f"Task:\n- {description}\n\n"

    # Related skills (optional)
    if related_skills:
        content += "## Related Skills\n"
        for skill in related_skills:
            content += f"- `{skill}`\n"
        content += "\n"

    # Context
    if context:
        content += f"## Context\n\n{context}\n\n"

    content += "---\n\n"

    # Steps
    for i, step in enumerate(steps, 1):
        content += format_step(
            step_num=i,
            title=step["title"],
            description=step["description"],
            requirements=step["requirements"],
            validation=step["validation"],
        )

    # Constraints
    content += "## Constraints\n\n"
    for constraint in constraints:
        content += f"- {constraint}\n"
    content += "\n"

    # Deliverable
    content += f"## Deliverable\n\n{deliverable}\n"

    return content


def generate_from_template(
    template_name: str,
    name: str,
    num_steps: int,
    feature_names: Optional[list[str]] = None,
) -> str:
    """Generate a prompt from a template."""

    if template_name not in TEMPLATES:
        raise ValueError(f"Unknown template: {template_name}. Available: {list(TEMPLATES.keys())}")

    template = TEMPLATES[template_name]

    # Calculate how many feature steps we need
    base_count = len(template["base_steps"])
    final_count = len(template["final_steps"])
    feature_count = max(0, num_steps - base_count - final_count)

    # Build steps list
    steps = list(template["base_steps"])

    # Add feature steps
    feature_template = template["feature_step_template"]
    if feature_names is None:
        feature_names = [f"Feature {i+1}" for i in range(feature_count)]

    for i, feature_name in enumerate(feature_names[:feature_count]):
        step = {
            "title": feature_template["title"].format(feature_name=feature_name),
            "description": feature_template["description"].format(feature_name=feature_name),
            "requirements": [
                req.format(feature_name=feature_name)
                for req in feature_template["requirements"]
            ],
            "validation": feature_template["validation"],
        }
        steps.append(step)

    # Add final steps
    steps.extend(template["final_steps"])

    # Generate description based on template
    description = f"Implement a {template['description'].lower()} in Cairo."

    # Default context
    context_parts = [
        "**CRITICAL - No Inherent Impls**: Cairo does NOT support Rust-style `impl Type { }`. All methods must use traits.",
        "",
        "**Snapshot Field Access**: When `self: @Type<T>`, fields become snapshots. Use `*self.field` to dereference.",
    ]
    context = "\n".join(context_parts)

    # Default constraints
    constraints = [
        "Must compile with `scarb build`",
        "Must pass all tests with `snforge test`",
        "Use generics where appropriate",
        "Handle edge cases (empty inputs, invalid parameters)",
    ]

    # Default deliverable
    deliverable = "Complete `src/lib.cairo` with all steps implemented."

    # Related skills based on template
    related_skills = {
        "cairo-library": [
            "cairo-generics-traits",
            "cairo-arrays",
            "cairo-testing",
        ],
        "cairo-contract": [
            "cairo-starknet-contracts",
            "cairo-storage",
            "cairo-events",
            "cairo-testing",
        ],
        "cairo-algorithm": [
            "cairo-arrays",
            "cairo-loops",
            "cairo-recursion",
            "cairo-testing",
        ],
    }

    return generate_prompt_content(
        name=name,
        description=description,
        context=context,
        steps=steps,
        constraints=constraints,
        deliverable=deliverable,
        related_skills=related_skills.get(template_name),
    )


def interactive_mode() -> str:
    """Interactively build a prompt by asking questions."""

    print("=== Prompt Template Generator (Interactive Mode) ===\n")

    # Task name
    name = input("Task name (e.g., 'vector-math', 'token-contract'): ").strip()
    if not name:
        name = "my-task"

    # Description
    description = input("Brief task description: ").strip()
    if not description:
        description = "Implement a Cairo library."

    # Template selection
    print("\nAvailable templates:")
    for key, tmpl in TEMPLATES.items():
        print(f"  {key}: {tmpl['description']}")

    template = input("\nSelect template (or 'custom' for manual): ").strip()

    if template in TEMPLATES:
        # Number of steps
        try:
            num_steps = int(input("Number of steps (default 6): ").strip() or "6")
        except ValueError:
            num_steps = 6

        # Feature names
        base_count = len(TEMPLATES[template]["base_steps"])
        final_count = len(TEMPLATES[template]["final_steps"])
        feature_count = max(0, num_steps - base_count - final_count)

        feature_names = []
        if feature_count > 0:
            print(f"\nEnter names for {feature_count} feature step(s) (or press Enter for defaults):")
            for i in range(feature_count):
                fname = input(f"  Feature {i+1} name: ").strip()
                feature_names.append(fname if fname else f"Feature {i+1}")

        return generate_from_template(template, name, num_steps, feature_names)

    else:
        # Custom/manual mode
        print("\n--- Building custom prompt ---\n")

        # Context
        context = input("Context/background (optional): ").strip()

        # Number of steps
        try:
            num_steps = int(input("Number of steps: ").strip() or "4")
        except ValueError:
            num_steps = 4

        steps = []
        for i in range(1, num_steps + 1):
            print(f"\n--- Step {i} ---")
            title = input(f"  Title: ").strip() or f"Step {i}"
            desc = input(f"  Description: ").strip() or "Implement this step."

            print("  Requirements (enter each on a line, empty line to finish):")
            requirements = []
            while True:
                req = input("    - ").strip()
                if not req:
                    break
                requirements.append(req)
            if not requirements:
                requirements = ["Implement the required functionality"]

            validation = input("  Validation (scarb build / snforge test): ").strip()
            if validation not in ["scarb build", "snforge test"]:
                validation = "scarb build"

            steps.append({
                "title": title,
                "description": desc,
                "requirements": requirements,
                "validation": validation,
            })

        # Constraints
        print("\nConstraints (enter each on a line, empty line to finish):")
        constraints = []
        while True:
            c = input("  - ").strip()
            if not c:
                break
            constraints.append(c)
        if not constraints:
            constraints = ["Must compile with `scarb build`"]

        # Deliverable
        deliverable = input("\nDeliverable description: ").strip()
        if not deliverable:
            deliverable = "Complete `src/lib.cairo` with all steps implemented."

        return generate_prompt_content(
            name=name,
            description=description,
            context=context,
            steps=steps,
            constraints=constraints,
            deliverable=deliverable,
        )


def validate_prompt(content: str) -> tuple[int, int]:
    """
    Validate the generated prompt using lint-prompt.py.

    Returns:
        Tuple of (error_count, warning_count)
    """
    # Write to temp file
    import tempfile

    with tempfile.NamedTemporaryFile(mode='w', suffix='.md', delete=False) as f:
        f.write(content)
        temp_path = f.name

    try:
        # Find lint-prompt.py in same directory
        script_dir = Path(__file__).parent
        lint_script = script_dir / "lint-prompt.py"

        if not lint_script.exists():
            print("Warning: lint-prompt.py not found, skipping validation")
            return 0, 0

        result = subprocess.run(
            [sys.executable, str(lint_script), temp_path],
            capture_output=True,
            text=True,
        )

        # Print lint output
        print("\n=== Validation Results ===")
        print(result.stdout)
        if result.stderr:
            print(result.stderr)

        # Parse summary for counts
        import re
        match = re.search(r'(\d+) errors?, (\d+) warnings?', result.stdout)
        if match:
            return int(match.group(1)), int(match.group(2))

        return 0 if result.returncode == 0 else 1, 0

    finally:
        Path(temp_path).unlink()


def main():
    parser = argparse.ArgumentParser(
        description="Generate prompt files following doc 018 standards.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Interactive mode
  python generate-prompt.py --interactive

  # Generate from template
  python generate-prompt.py --template cairo-library --name "my-vector-math" --steps 8
  python generate-prompt.py --template cairo-contract --name "my-token" --steps 6
  python generate-prompt.py --template cairo-algorithm --name "sorting" --steps 5

  # With output options
  python generate-prompt.py --template cairo-library --name "my-lib" --output prompts/my-lib.md
  python generate-prompt.py --template cairo-library --name "my-lib" --validate
        """,
    )

    # Mode selection
    mode_group = parser.add_mutually_exclusive_group()
    mode_group.add_argument(
        "--interactive", "-i",
        action="store_true",
        help="Interactive mode - answer questions to build prompt",
    )
    mode_group.add_argument(
        "--template", "-t",
        choices=list(TEMPLATES.keys()),
        help="Generate from a predefined template",
    )

    # Template options
    parser.add_argument(
        "--name", "-n",
        help="Task name (used in title and prompt ID)",
    )
    parser.add_argument(
        "--steps", "-s",
        type=int,
        default=6,
        help="Number of steps (default: 6)",
    )
    parser.add_argument(
        "--features", "-f",
        nargs="*",
        help="Feature names for middle steps",
    )

    # Output options
    output_group = parser.add_mutually_exclusive_group()
    output_group.add_argument(
        "--output", "-o",
        help="Write to file",
    )
    output_group.add_argument(
        "--stdout",
        action="store_true",
        help="Print to stdout (default)",
    )

    parser.add_argument(
        "--validate", "-v",
        action="store_true",
        help="Run linter after generation",
    )

    args = parser.parse_args()

    # Generate content
    if args.interactive:
        content = interactive_mode()
    elif args.template:
        if not args.name:
            parser.error("--template requires --name")
        content = generate_from_template(
            template_name=args.template,
            name=args.name,
            num_steps=args.steps,
            feature_names=args.features,
        )
    else:
        parser.print_help()
        print("\nError: Must specify --interactive or --template")
        sys.exit(1)

    # Validate if requested
    if args.validate:
        errors, warnings = validate_prompt(content)
        if errors > 0:
            print(f"\nValidation failed with {errors} error(s)")
            sys.exit(1)

    # Output
    if args.output:
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(content)
        print(f"\nWrote prompt to: {output_path}")
    else:
        print("\n" + "=" * 60)
        print("GENERATED PROMPT")
        print("=" * 60 + "\n")
        print(content)


if __name__ == "__main__":
    main()
