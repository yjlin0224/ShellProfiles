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

# HTTP servers: URL from an environment variable, or prompted for when run
# interactively; an empty value skips the server and leaves its entry untouched.
ask_url() {
  [ -n "${!1}" ] || { [ -t 0 ] && read -rp "$1 (Enter to skip): " "$1"; }
}
ask_url HOME_ASSISTANT_MCP_URL
ask_url HOME_ASSISTANT_UNOFFICIAL_MCP_URL

if [ -n "$HOME_ASSISTANT_MCP_URL" ]; then
  claude mcp remove home-assistant --scope user >/dev/null 2>&1
  claude mcp add home-assistant --scope user --transport http "$HOME_ASSISTANT_MCP_URL" --client-id http://localhost:12345 --callback-port 12345
fi
if [ -n "$HOME_ASSISTANT_UNOFFICIAL_MCP_URL" ]; then
  claude mcp remove home-assistant-unofficial --scope user >/dev/null 2>&1
  claude mcp add home-assistant-unofficial --scope user --transport http "$HOME_ASSISTANT_UNOFFICIAL_MCP_URL"
fi
