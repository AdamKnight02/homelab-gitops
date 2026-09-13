## Description: <br>
Comprehensive Azure Cloud Platform management via command-line interface. <br>

This skill is ready for commercial/non-commercial use. <br>

## Publisher: <br>
[ddevaal](https://clawhub.ai/user/ddevaal) <br>

### License/Terms of Use: <br>
MIT <br>


## Use Case: <br>
Developers, cloud engineers, and DevOps teams use this skill to draft and review Azure CLI commands, automation patterns, and helper-script workflows for managing Azure resources. <br>

### Deployment Geography for Use: <br>
Global <br>

## Known Risks and Mitigations: <br>
Risk: Azure CLI guidance and helper scripts can create, update, deploy, or delete cloud resources in the active subscription. <br>
Mitigation: Use a least-privilege Azure identity, prefer a sandbox or non-production subscription for examples, and confirm the active subscription and resource group before execution. <br>
Risk: Authentication examples involve Azure tokens, connection strings, or service-principal secrets that could expose cloud access if shared. <br>
Mitigation: Never provide secrets in chat or logs; use managed identity or secure secret stores where available. <br>
Risk: Resource cleanup and deployment workflows can affect costs or availability if run against production assets. <br>
Mitigation: Review proposed commands before running them and require explicit approval for create, update, delete, deployment, or run-command actions. <br>


## Reference(s): <br>
- [ClawHub Azure CLI Skill Page](https://clawhub.ai/ddevaal/skills/azure-cli) <br>
- [Azure CLI Documentation](https://learn.microsoft.com/en-us/cli/azure/) <br>
- [Azure CLI Command Reference](https://learn.microsoft.com/en-us/cli/azure/reference-index) <br>
- [Azure CLI GitHub Repository](https://github.com/Azure/azure-cli) <br>
- [Azure CLI Release Notes](https://github.com/Azure/azure-cli/releases) <br>
- [Azure CLI Complete Command Reference](references/REFERENCE.md) <br>


## Skill Output: <br>
**Output Type(s):** [Guidance, Markdown, Code, Shell commands, Configuration] <br>
**Output Format:** [Markdown with inline bash, PowerShell, and Azure CLI code blocks] <br>
**Output Parameters:** [1D] <br>
**Other Properties Related to Output:** [May reference bundled shell scripts for Azure status, cleanup, storage analysis, subscription reporting, and resource group deployment workflows.] <br>

## Skill Version(s): <br>
1.0.0 (source: server release metadata and frontmatter) <br>

## Ethical Considerations: <br>
Users should evaluate whether this skill is appropriate for their environment, review any generated or modified files before relying on them, and apply their organization's safety, security, and compliance requirements before deployment. <br>
