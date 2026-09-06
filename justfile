# TripleA infrastructure — top-level tasks. Provisioning and configuration
# recipes live in terraform/justfile and ansible/justfile respectively.

# Show available recipes.
default:
    @just --list

# Install pre-commit and register it as a git pre-push hook.
setup:
    uv tool install pre-commit
    pre-commit install --hook-type pre-push

# Format all sources in place (currently terraform); invoked by the pre-commit hook.
format:
    cd terraform && just fmt

# Verification gate before an apply — currently ansible-lint; tests to follow.
verify:
    cd ansible && just verify
