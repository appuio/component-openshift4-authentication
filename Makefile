MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:

FILES_JSONNET ?= $(shell find . -type f -name '*.*jsonnet' -or -name '*.libsonnet')
FILES_YAML ?= $(shell find . -type f -name '*.yaml' -or -name '*.yml')

JSONNETFMT_ARGS ?= --in-place

.PHONY: all
all: lint

.PHONY: lint
lint: lint_jsonnet lint_yaml

.PHONY: lint_jsonnet
lint_jsonnet: $(FILES_JSONNET)
	jsonnetfmt $(JSONNETFMT_ARGS) --test -- $?

.PHONY: lint_yaml
lint_yaml: $(FILES_YAML)
	yamllint -f parsable -c .yamllint.yaml --no-warnings -- $?

.PHONY: format
format: format_jsonnet

.PHONY: format_jsonnet
format_jsonnet: $(FILES_JSONNET)
	jsonnetfmt $(JSONNETFMT_ARGS) -- $?
