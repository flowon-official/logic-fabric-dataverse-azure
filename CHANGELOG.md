# Changelog

All notable changes to these templates are documented here. The project follows
[Semantic Versioning](https://semver.org/). Template versions are independent of the container
image versions; each release states the image tag it defaults to.

## [1.8.0] - 2026-11-23

- Default images: Foundry `2.0.8`; the others are unchanged. Foundry 2.0.8 runs `test` cases as a persona given
  as its user (`"analyst": "user@contoso.com"`; it failed with "The node must be of type 'JsonObject'"), and its
  teardown deletes what a case created even when the app's rules refuse one order of deletes or a business process
  was started on a row.

## [1.7.0] - 2026-11-22

- Default images: Foundry `2.0.7`; the others are unchanged. Foundry 2.0.7 deletes a logic flow or
  block that calls others (it refused, naming the flows it calls as users), `get` lists what uses an
  artifact, callers included, as `usedBy`, and `save` creates activity tables (Dataverse refused them
  without offline availability), returning before Dataverse's minutes-long create is done.

## [1.6.0] - 2026-11-22

- Default images: Foundry `2.0.6`; the others are unchanged. Foundry 2.0.6 reads a table, column,
  choice or relationship with `get` in the form `save` takes, creates inactive test rows, and reads a
  required date column that an update leaves out as empty instead of failing.

## [1.5.0] - 2026-11-21

- Default images: Foundry `2.0.5`; the others are unchanged. Foundry 2.0.5 lets a logic flow see a
  formula block's empty result, checks a test trigger that Dataverse refuses (a validation recipe, a
  column's range) against the case's expected error, saves currency column ranges, and serves a
  corrected grammar (choice types, new variables, clearing columns).

## [1.4.0] - 2026-11-21

- Default images: Foundry `2.0.4` and Guard `1.0.3`; the others are unchanged. Foundry 2.0.4 reports a
  logic flow's RaiseError and refused preconditions in `run` and `test`, creates test fixtures as its
  own user, returns a link to everything `save` and `get` name, and serves the rule catalog with the
  step types flows really have. Guard 1.0.3 reviews flows with the same corrected rules.

## [1.3.0] - 2026-11-21

- Default images: Foundry `2.0.2`; the others are unchanged. Foundry 2.0.2 creates solutions (with an
  existing or a new publisher) for new projects, saves tables in parts that fit a tool call, sets
  table features (notes, activities, queues, audit), publishes customizations as a Dataverse system
  job, saves reference rows of every column type, checks test personas' preconditions as the
  persona, and sends its request logs to Application Insights.
- Container console and system logs now go to a Log Analytics workspace whenever telemetry is on,
  also when `appInsightsConnectionString` reuses an existing Application Insights resource. Before,
  a reused resource meant no workspace, and the apps' request logs were kept nowhere.

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
