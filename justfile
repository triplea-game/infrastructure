# TripleA infrastructure — top-level tasks. Provisioning and configuration
# recipes live in terraform/justfile and ansible/justfile respectively.

alias test := check

# Show available recipes.
default:
    @just --list

# Install pre-commit and register it as a git pre-push hook.
setup:
    uv tool install pre-commit
    pre-commit install --hook-type pre-push

# Fix, in place, every formatting finding that 'just check' or the pre-push
# hooks report. A new formatting check belongs here too, with its fixer.
# The pre-push fixer hooks exit non-zero whenever they changed a file, so their
# status is ignored; 'just check' and the hooks themselves are the gate.
format: _format-tools
    for hook in end-of-file-fixer trailing-whitespace mixed-line-ending; do pre-commit run "$hook" --all-files --hook-stage pre-push || true; done

# The per-tool formatters. The pre-push 'just-format' hook calls this rather
# than 'format', since the whitespace fixers already run there as hooks.
_format-tools:
    cd terraform && just fmt
    cd ansible && just format

# Verification gate before an apply — currently ansible-lint; tests to follow.
check:
    cd ansible && just check
