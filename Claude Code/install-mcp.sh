#!/usr/bin/env bash
# Format: name|package|executable|extra args (space-separated, optional)
for entry in \
  "affine|affine-mcp-server@latest|affine-mcp" \
  "firefox-devtools|@mozilla/firefox-devtools-mcp@latest|firefox-devtools-mcp|--auto-profile"
do
  IFS='|' read -r name package bin extra <<< "$entry"
  read -ra extra <<< "$extra"
  claude mcp remove "$name" --scope user >/dev/null 2>&1
  # --prefix keeps npm from reading devEngines in the project's package.json;
  # single quotes leave ${USERPROFILE} for Claude Code to expand.
  claude mcp add "$name" --scope user -- npx --prefix '${USERPROFILE}' -y -p "$package" "$bin" "${extra[@]}"
done
