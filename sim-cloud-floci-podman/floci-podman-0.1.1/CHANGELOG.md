# Changelog

## v0.1.0

First release.

- `up` / `down` / `check` / `info` subcommands, each accepting a list of clouds
- Socket mounted with the `:z` SELinux relabel, so compute services work
- Containers joined to a named network, so spawned functions can reach the Runtime API
- Connection details printed after `up`, and available separately via `info --export`
- Storage round-trip check over plain REST — no cloud CLIs required
