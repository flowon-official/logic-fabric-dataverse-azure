# Changelog

All notable changes to these templates are documented here. The project follows
[Semantic Versioning](https://semver.org/). Template versions are independent of the container
image versions; each release states the image tag it defaults to.

## [1.12.0] - 2026-11-24

- Default images: Foundry `2.3.0`; the others are unchanged. Foundry 2.3.0 keeps each change's ledger in Dataverse:
  the artifacts it created, changed, deleted or released, its test runs and their results, its requirements and
  acceptance criteria, its review findings, the governance rules a reviewer waived, the tasks it's blocked on, and
  the `analyze` runs recorded with `record: true`. Foundry writes these rows as its own application user. A change
  can't be submitted while one of its blocking items is open, and accepting one with an open Blocker finding needs
  a reviewer. This needs the Logic Fabric Foundry solution 1.0.0.47; with an earlier one, Foundry skips these
  records and works as before.
- Foundry 2.3.0 also tries a save, delete or release again for up to 25 seconds while a solution import, upgrade or
  uninstall runs (it failed with "Cannot start another [WorkflowSetState] because there is a previous [Import]
  running"), finishes `analyze` with `kind: "security"` on large organizations, serves every flow action in
  `reference` (TryCatch included), returns the draft's source after a business process save, and creates a business
  unit as a `test` fixture under the root business unit.

## [1.11.0] - 2026-11-24

- Default images: Foundry `2.2.0`; the others are unchanged. Foundry 2.2.0 keeps each change's stage, so the
  authoring workflow's order holds in every AI client: a plan is approved only after its spec, `release` with
  `submit` sends a built change to its owner for acceptance, and the owner accepts it or sends it back to its build
  or its spec, with a reason. Submitting and accepting need the Logic Fabric Foundry solution 1.0.0.46; with an
  earlier one, approvals work as before. Its `test` reads `count: 0` as no rows, and its teardown removes rows the
  app's own rules keep refusing, with custom logic bypassed (this needs the prvBypassCustomBusinessLogic privilege,
  which System Administrators have).

## [1.10.3] - 2026-11-24

- Default images: Foundry `2.1.4`; the others are unchanged. Foundry 2.1.4 asks for an approval in the dialog of a
  client on the MCP 2026-07-28 revision, such as Claude Code (`approve` failed with "Elicitation is not supported in
  stateless mode"), and validates a query that reads an intersect table such as `teammembership` (it failed with
  "Value cannot be null (Parameter 'logicalName')"). Its `run` and `test` take a record input as `{"lookup": ...}`
  as well as its ID, and refuse any other value for one (it was read as empty). A business process delete needs
  Logic Fabric 1.0.0.45.

## [1.10.2] - 2026-11-23

- Default images: Foundry `2.1.2`; the others are unchanged. Foundry 2.1.2 lists the business process versions that
  use a logic flow or block (`get` with dependencies and `delete` failed with "NullReferenceException" for them), and
  its app view no longer reports a result it can't show as a failure.

## [1.10.1] - 2026-11-23

- Default images: Foundry `2.1.1`; the others are unchanged. Foundry 2.1.1 asks the owner to approve a change in
  the client's dialog again: 2.1.0 served every client without a session, so every approval went to its page.
- Foundry runs as one replica, whatever `foundrySizing` says: the dialog's answer must reach the replica that asked,
  and the approval page's sign-in cookies are sealed with keys held in memory. An existing deployment gets it on
  its next run.

## [1.10.0] - 2026-11-23

- Default images: Foundry `2.1.0`; the others are unchanged. Foundry 2.1.0 can keep the authoring workflow's
  gate itself: it asks the owner to approve a change's spec or plan (in the client's dialog, or on its approval
  page) and refuses writes to a gated project without an approved change. It needs the Logic Fabric Foundry
  solution (Logic Fabric 1.0.0.43) in the environment; without it Foundry works as before.
- The Foundry server's Entra app gets the web redirect URI `https://<Foundry>/approvals/signin-oidc` (and the custom
  domain's) with ID tokens, for the approval page's sign-in. An existing deployment gets them on its next run.

## [1.9.0] - 2026-11-23

- Default images: Foundry `2.0.9`; the others are unchanged. Foundry 2.0.9 runs a business process's own writes
  as Foundry's identity, not as the `test` persona, also when it connects with its own credentials (a local or
  stdio Foundry), and its rule catalog has Guard's BP-032 (a stage that branches without a gateway).

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
