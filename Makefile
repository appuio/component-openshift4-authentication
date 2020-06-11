MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:

.PHONY: all
all: lint

.PHONY: lint
lint: lint_jsonnet lint_yaml

.PHONY: lint_jsonnet
lint_jsonnet: $(shell find . -type f -name '*.*jsonnet' -or -name '*.libsonnet')
	jsonnetfmt --in-place --test -- $?

.PHONY: lint_yaml
lint_yaml: $(shell find . -type f -name '*.yaml' -or -name '*.yml')
	yamllint -f parsable --no-warnings -- $?
