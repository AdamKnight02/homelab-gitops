## Description: <br>
Manage Linear projects, issues, and tasks via the bundled Node CLI and the official Linear API. <br>

This skill is ready for commercial/non-commercial use. <br>

## Publisher: <br>
[matrixy](https://clawhub.ai/user/matrixy) <br>

### License/Terms of Use: <br>
MIT <br>


## Use Case: <br>
Developers and project teams use this skill to read, create, update, and organize Linear issues, projects, teams, milestones, comments, cycles, labels, and documents from an agent workflow. <br>

### Deployment Geography for Use: <br>
Global <br>

## Known Risks and Mitigations: <br>
Risk: The local CLI uses a Linear API key with the permissions assigned to that token. <br>
Mitigation: Use a dedicated least-privilege Linear token, keep it in the local environment, and rotate it if exposed. <br>
Risk: Create and update commands can modify Linear issues, projects, comments, milestones, and labels. <br>
Mitigation: Read current state first, confirm IDs and payloads before mutations, and summarize exactly what changed. <br>
Risk: Linear issue comments or descriptions can accidentally receive secrets or sensitive operational details. <br>
Mitigation: Avoid placing secrets in Linear comments or descriptions and review generated text before posting. <br>
Risk: npm dependency changes can alter the behavior of the bundled CLI. <br>
Mitigation: Keep dependency updates controlled and review package-lock changes before deployment. <br>


## Reference(s): <br>
- [Linear API Reference](references/API.md) <br>
- [ClawHub skill page](https://clawhub.ai/matrixy/skills/linear-skill) <br>
- [Source homepage](https://github.com/MaTriXy/linear-skill) <br>


## Skill Output: <br>
**Output Type(s):** [text, markdown, code, shell commands, configuration, guidance] <br>
**Output Format:** [Markdown guidance with shell commands and JSON snippets; CLI command results are JSON-like text from Linear API operations.] <br>
**Output Parameters:** [1D] <br>
**Other Properties Related to Output:** [Requires local Node.js/npm and LINEAR_API_KEY.] <br>

## Skill Version(s): <br>
1.0.0 (source: server release metadata, package.json) <br>

## Ethical Considerations: <br>
Users should evaluate whether this skill is appropriate for their environment, review any generated or modified files before relying on them, and apply their organization's safety, security, and compliance requirements before deployment. <br>
