# Changelog

All notable changes to these templates are documented here. The project follows
[Semantic Versioning](https://semver.org/). Template versions are independent of the container
image versions; each release states the image tag it defaults to.

## [1.2.0] - 2026-11-20

- Default images: Foundry `2.0.1`; the others are unchanged (Assist `1.0.3`, Assurance, Context,
  Guard, Insight, Sentinel and Conductor `1.0.2`). Foundry 2.0.1 refuses to delete, publish,
  enable, disable, expose or hide the artifacts of a project whose solution is managed in the
  environment, as it already refused to change them.
- `foundry`: `foundryReadOnly` makes Foundry refuse every change. Use it for test and production
  environments.

## [1.1.0] - 2026-11-20

- Default images: Foundry `2.0.0`, Assist `1.0.3`, Assurance, Context, Guard, Insight and Sentinel
  `1.0.2`, Conductor `1.0.2`.
- `foundry`: `imageTag` is now empty by default, which runs the versions above; set it to run one
  tag for Foundry and every agent, as before.
- Foundry 2.0.0 replaces its tools with 13 new ones (`find`, `get`, `validate`, `save`, `delete`,
  `run`, `test`, `release`, `schema`, `lookup`, `security`, `reference`, `analyze`). The agents
  use them from 1.0.2 on (Assist from 1.0.3): upgrade Foundry and the agents together. MCP clients
  that call Foundry's old tool names must switch.

## [1.0.0] - 2026-10-26

First public release.

- `foundry`: Foundry MCP server and the Assist, Assurance, Context, Guard, Insight and Sentinel
  agents, with Entra app registrations for the on-behalf-of chain between them.
- `conductor`: standalone Conductor MCP server.
- Default image tag: `1.0.0`.

[1.2.0]: https://github.com/flowon-official/logic-fabric-dataverse-azure/releases/tag/v1.2.0
[1.1.0]: https://github.com/flowon-official/logic-fabric-dataverse-azure/releases/tag/v1.1.0
[1.0.0]: https://github.com/flowon-official/logic-fabric-dataverse-azure/releases/tag/v1.0.0
