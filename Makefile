.DEFAULT_GOAL := help

.PHONY: help setup build clean check

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

setup: ## Install pre-commit and register it as a git push hook
	uv tool install pre-commit
	pre-commit install --hook-type pre-push


