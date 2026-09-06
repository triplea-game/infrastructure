#!/usr/bin/env python3
"""Fails if any role's tasks/ notify a handler name that role's handlers/main.yml
doesn't define. ansible-lint has no rule for this (a stale notify: string is
a silent no-op, not a syntax error) and check-mode diff can't catch it either
— see the 84bba0f incident, where --fix capitalized handler names but left 19
notify: strings pointing at the old lowercase names. Every notify in this repo
targets a handler in its own role; there are no cross-role notifies today.

Parses tasks and handlers as real YAML (via PyYAML — the justfile's `verify`
recipe runs this through `uv run --with pyyaml` so the interpreter has it
regardless of what's on the system) instead of pattern-matching lines with
awk. The prior line-based
version accumulated edge cases across three review rounds — list-form
notify, quoted names, cross-file awk state, block-list handler style — each
one a fresh regex patched onto a hand-rolled YAML parser. Reading the actual
parsed structure closes that whole class of bug at once: notify and handler
name are just dict values wherever YAML says they are.
"""
import pathlib
import sys

import yaml

ROOT = pathlib.Path(__file__).resolve().parent


def notify_targets(node):
    """Yields every notify target under a parsed tasks-file node, recursing into block/rescue/always."""
    if isinstance(node, list):
        for item in node:
            yield from notify_targets(item)
    elif isinstance(node, dict):
        notify = node.get("notify")
        if isinstance(notify, str):
            yield notify
        elif isinstance(notify, list):
            for target in notify:
                if isinstance(target, str):
                    yield target
        for key in ("block", "rescue", "always"):
            if key in node:
                yield from notify_targets(node[key])


def handler_names(node):
    """Yields each handler's name from a parsed handlers/main.yml node."""
    if isinstance(node, list):
        for item in node:
            if isinstance(item, dict) and isinstance(item.get("name"), str):
                yield item["name"]


def load_yaml(path):
    with path.open() as f:
        return yaml.safe_load(f)


def main():
    status = 0
    role_dirs = sorted(set(ROOT.glob("roles/*/")) | set(ROOT.glob("roles/*/*/")))

    for role_dir in role_dirs:
        tasks_dir = role_dir / "tasks"
        if not tasks_dir.is_dir():
            continue

        task_files = sorted(tasks_dir.rglob("*.yml")) + sorted(tasks_dir.rglob("*.yaml"))
        if not task_files:
            continue

        targets = set()
        for task_file in task_files:
            targets.update(notify_targets(load_yaml(task_file) or []))
        if not targets:
            continue

        handlers_file = role_dir / "handlers" / "main.yml"
        if not handlers_file.is_file():
            print(f"error: {tasks_dir} notifies a handler, but {handlers_file} does not exist")
            status = 1
            continue

        handlers = set(handler_names(load_yaml(handlers_file) or []))
        for target in sorted(targets):
            if target not in handlers:
                print(f"error: {tasks_dir} notifies '{target}', which is not a handler name in {handlers_file}")
                status = 1

    sys.exit(status)


if __name__ == "__main__":
    main()
