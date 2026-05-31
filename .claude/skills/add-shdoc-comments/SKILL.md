---
name: add-shdoc-comments
description: Adds concise, simple English comments in shdoc format to specified shell functions.
---

# Add Shdoc Comments to Shell Functions

This skill assists in documenting shell functions (bash, zsh, sh) using the `shdoc` documentation format.

## When to Use

- Use this skill when a user asks to add document comments or shdoc comments to shell functions.
- Use this when modifying or refactoring shell scripts to follow consistent documentation standards.

## How to Use

Add a comment block immediately before the target function definition (or at the top of the file for file-level documentation). The comment block must follow the `shdoc` format and use simplified English.

### English Writing Rules

1. **Conciseness**: Keep sentences as short and direct as possible.
2. **Simple Vocabulary**: Use basic English words. Avoid complex or academic expressions (e.g., use "get" instead of "retrieve", "show" instead of "display", "check" instead of "validate").
3. **Technical Terms**: Keep necessary technical terms (e.g., "WSL", "regex", "stdout", "JSON", "environment variable") as is, but explain their usage simply.

### Documentation Workflow & Tag Selection

When documenting a function, follow this decision process to select the correct tags:

1. **Visibility Check**: Is this a private helper function?
   - If yes, use **`@internal`** `[MUST]`.
2. **Core Description**: State what the function does.
   - Use **`@description`** `[MUST]` (unless `@internal` is used). Start with an imperative verb.
3. **Analyze Inputs**:
   - If it accepts positional parameters, use **`@arg`** `[MUST]` for each argument.
   - If it accepts options/flags, use **`@option`** `[MUST]`.
   - If it reads from standard input, use **`@stdin`** `[MUST]`.
   - If it accepts no arguments, use **`@noargs`** `[SHOULD]` to be explicit.
4. **Analyze Side Effects & Outputs**:
   - If it prints to standard output, use **`@stdout`** `[MUST]`.
   - If it prints errors/logs to standard error, use **`@stderr`** `[MUST]`.
   - If it modifies or exports global/environment variables, use **`@set`** `[MUST]`.
5. **Analyze Exit Behavior**:
   - If the function can return non-zero exit codes, use **`@exitcode`** `[MUST]` to document all potential exit status values (including `0`).
6. **Clarity & Context**:
   - If the function has complex usage, use **`@example`** `[SHOULD]` to provide usage snippets.
   - If it relates to other functions or docs, use **`@see`** `[MAY]` to link them.

### Shdoc Format Specification

Use the following tags in comment blocks. Group related information and include empty comment lines (`#`) between sections for readability.

#### File & Section Documentation (At the beginning of a script/library)

| Tag & Syntax | Level | Condition / Timing to Use |
| :--- | :---: | :--- |
| **`# @file <filename>`** or<br>**`# @name <ProjectName>`** | `[MUST]` | Use once at the very beginning of the script to define the documentation title. |
| **`# @brief <One-line description>`** | `[MUST]` | Use once immediately after the file/name tag to summarize the script's purpose. |
| **`# @description <Multiline description>`** | `[SHOULD]` | Use if the script requires a detailed explanation, installation guide, or overview of features. |
| **`# @section <Section name>`** | `[MAY]` | Use to group related functions into sections in a long script. |

#### Function Documentation (Immediately before the function definition)

| Tag & Syntax | Level | Condition / Timing to Use |
| :--- | :---: | :--- |
| **`# @description <Description>`** | `[MUST]` | Use for all public functions to describe what they do. Start with an imperative verb (e.g., "Get", "Run", "Check"). (Omit if `@internal` is used). |
| **`# @arg $<num> <type> <Desc>`** | `[MUST]` | Use for **every** positional parameter (e.g., `$1`, `$2`) the function accepts. Specify the type (e.g., `string`, `integer`, `boolean`, `array`). |
| **`# @option <opt> <Desc>`** | `[MUST]` | Use if the function accepts flags/options (e.g., `-h`, `--value=<val>`). |
| **`# @stdout <Description>`** | `[MUST]` | Use if the function prints any normal output to stdout. |
| **`# @stderr <Description>`** | `[MUST]` | Use if the function prints warning/error messages or debug logs to stderr. |
| **`# @exitcode <num> <Condition>`** | `[MUST]` | Use if the function can exit with non-zero codes, or if exit codes represent different outcomes. List all possible codes, including `0` for success. |
| **`# @stdin <Description>`** | `[MUST]` | Use if the function reads input from stdin (e.g., via `read` or pipes). |
| **`# @set <VAR> <type> <Desc>`** | `[MUST]` | Use if the function modifies, exports, or sets global variables. |
| **`# @internal`** | `[MUST]` | Use on helper/private functions that should not be exposed in the public API/documentation. |
| **`# @example`** | `[SHOULD]` | Use for complex functions, multi-step usage, or when syntax is not immediately obvious. |
| **`# @noargs`** | `[SHOULD]` | Use when a function accepts no arguments, to explicitly clarify its zero-argument interface. |
| **`# @see <ref>`** | `[MAY]` | Use to reference related functions (e.g., `@see other_func()`) or external URLs. |

### Example

Before:

```bash
function get_env_var {
  local var_name=$1
  if [[ -z "${(P)var_name}" ]]; then
    echo "Error: Variable $var_name is not set" >&2
    return 1
  fi
  echo "${(P)var_name}"
}
```

After:

```bash
# @description Get the value of an environment variable by name.
#
# @example
#   get_env_var "HOME"
#
# @arg $1 string Name of the environment variable.
#
# @stdout The value of the environment variable.
# @stderr Error message if the variable is not set.
#
# @exitcode 0 If the variable is found.
# @exitcode 1 If the variable is empty or not set.
function get_env_var {
  local var_name=$1
  if [[ -z "${(P)var_name}" ]]; then
    echo "Error: Variable $var_name is not set" >&2
    return 1
  fi
  echo "${(P)var_name}"
}
```
