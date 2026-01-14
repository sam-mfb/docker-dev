# Docker Dev Environment

## Docker Access

This container does not have direct access to the Docker socket. Use the MCP Docker server instead of running `docker` commands via Bash.

The `mcp__MCP_DOCKER__docker` tool requires the `args` parameter to pass commands:

```
args: "ps"           # docker ps
args: "images"       # docker images
args: "logs <name>"  # docker logs
args: "inspect <id>" # docker inspect
```
