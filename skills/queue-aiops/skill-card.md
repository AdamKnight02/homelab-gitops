## Description:

Queue AIops helps agents inspect Redis caches and RabbitMQ brokers, diagnose memory, latency, backlog, and connection-churn issues, and perform audited broker operations.

This skill is ready for commercial/non-commercial use.

## Publisher:

[zw008](https://clawhub.ai/user/zw008)

### License/Terms of Use:

MIT-0

## Use Case:

Developers, SREs, and operations engineers use this skill to investigate Redis and RabbitMQ health, queue backlog, memory pressure, latency, and client behavior, then run governed maintenance actions when their broker account permits it.

### Deployment Geography for Use:

Global

## Known Risks and Mitigations:

Risk: The skill can give agents destructive broker-write authority without an enforceable MCP approval or read-only gate.

Mitigation: Install it only for operators authorized to administer the configured Redis or RabbitMQ brokers, and prefer read-only Redis ACL users or RabbitMQ monitoring-only accounts by default.

Risk: Queue purge and queue delete operations can cause irreversible message loss.

Mitigation: Grant write permissions only for deliberate maintenance, require an explicit dry-run review and operator signoff, and treat purge/delete operations as data-loss events.

Risk: Secrets and the master password can expose broker access if stored in shared configuration or checked into source control.

Mitigation: Keep QUEUE_AIOPS_MASTER_PASSWORD out of shared files and repositories, use the encrypted secret store, and restrict access to the configured runtime environment.

## Reference(s):

- [ClawHub skill page](https://clawhub.ai/zw008/skills/queue-aiops)
- [Project homepage](https://github.com/AIops-tools/Queue-AIops)
- [Capabilities reference](references/capabilities.md)
- [Setup guide](references/setup-guide.md)
- [CLI reference](references/cli-reference.md)
- [Agent guardrails](references/agent-guardrails.md)

## Skill Output:

**Output Type(s):** [text, markdown, shell commands, configuration, guidance]

**Output Format:** [Markdown guidance with JSON tool results, shell command snippets, and configuration examples]

**Output Parameters:** [1D]

**Other Properties Related to Output:** [Tool outputs can include broker telemetry, ranked RCA findings, audit metadata, dry-run previews, and undo descriptors.]

## Skill Version(s):

0.8.0 (source: server release evidence)

## Ethical Considerations:

Users should evaluate whether this skill is appropriate for their environment, review any generated or modified files before relying on them, and apply their organization's safety, security, and compliance requirements before deployment.
