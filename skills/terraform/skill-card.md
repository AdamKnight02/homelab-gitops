## Description: <br>
Helps agents write, review, debug, refactor, test, and operate Terraform or OpenTofu infrastructure-as-code, including HCL, modules, state, plans, provider pinning, upgrades, drift, CI gates, and recovery workflows. <br>

This skill is ready for commercial/non-commercial use. <br>

## Publisher: <br>
[ivangdavila](https://clawhub.ai/user/ivangdavila) <br>

### License/Terms of Use: <br>
MIT-0 <br>


## Use Case: <br>
Developers, platform engineers, and infrastructure operators use this skill to get Terraform and OpenTofu guidance for HCL authoring, plan/apply triage, state recovery, module refactoring, provider upgrades, and CI/CD safety gates. <br>

### Deployment Geography for Use: <br>
Global <br>

## Known Risks and Mitigations: <br>
Risk: Terraform guidance can affect real infrastructure through generated plans, state operations, and apply commands. <br>
Mitigation: Review saved Terraform plans before applying, confirm every destroy or replacement, and use scoped CI gates for production changes. <br>
Risk: Terraform state, plan files, debug logs, and local memory can contain sensitive values. <br>
Mitigation: Keep local memory free of secrets, restrict access to state and plan artifacts, rotate exposed credentials, and treat debug logs as sensitive. <br>


## Reference(s): <br>
- [ClawHub Terraform skill page](https://clawhub.ai/ivangdavila/skills/terraform) <br>
- [Clawic Terraform skill page](https://clawic.com/skills/terraform) <br>


## Skill Output: <br>
**Output Type(s):** [text, markdown, code, shell commands, configuration, guidance] <br>
**Output Format:** [Markdown with inline HCL, JSON, YAML, and bash code blocks] <br>
**Output Parameters:** [1D] <br>
**Other Properties Related to Output:** [May include review checklists, plan triage steps, command sequences, and configuration examples for Terraform or OpenTofu workflows.] <br>

## Skill Version(s): <br>
1.0.4 (source: frontmatter and server release evidence) <br>

## Ethical Considerations: <br>
Users should evaluate whether this skill is appropriate for their environment, review any generated or modified files before relying on them, and apply their organization's safety, security, and compliance requirements before deployment. <br>
