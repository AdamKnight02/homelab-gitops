## Description: <br>
Architects, debugs, secures, and cost-optimizes AWS infrastructure across services such as EC2, Lambda, RDS, VPC, IAM, ECS, and CloudFront. <br>

This skill is ready for commercial/non-commercial use. <br>

## Publisher: <br>
[ivangdavila](https://clawhub.ai/user/ivangdavila) <br>

### License/Terms of Use: <br>
MIT-0 <br>


## Use Case: <br>
Developers, operators, and cloud engineers use this skill to plan, troubleshoot, secure, and cost-optimize AWS accounts and workloads. It supports service selection, CLI workflows, IAM and network diagnosis, infrastructure-as-code review, production readiness, and local operational notes. <br>

### Deployment Geography for Use: <br>
Global <br>

## Known Risks and Mitigations: <br>
Risk: AWS CLI commands and infrastructure recommendations can affect live cloud resources, cost, security posture, or availability if run in the wrong account or region. <br>
Mitigation: Review proposed commands, account identity, region, IAM scope, pricing assumptions, and change plans before execution; prefer dry runs or infrastructure-as-code plans when available. <br>
Risk: The skill maintains local notes about AWS accounts, inventory, spend, runbooks, and security findings, which may include sensitive account IDs, ARNs, resource names, policy structure, and operational history. <br>
Mitigation: Install only on a protected workstation, restrict access to the local Clawic data paths, and avoid storing credential values. <br>


## Reference(s): <br>
- [ClawHub skill page](https://clawhub.ai/ivangdavila/skills/aws) <br>
- [Clawic AWS skill page](https://clawic.com/skills/aws) <br>


## Skill Output: <br>
**Output Type(s):** [text, markdown, code, shell commands, configuration, guidance] <br>
**Output Format:** [Markdown guidance with AWS CLI commands, configuration notes, and infrastructure recommendations] <br>
**Output Parameters:** [1D] <br>
**Other Properties Related to Output:** [May read AWS CLI context and maintain local Clawic notes under configured paths; artifact evidence states credential values should not be stored.] <br>

## Skill Version(s): <br>
1.0.7 (source: frontmatter and server release evidence) <br>

## Ethical Considerations: <br>
Users should evaluate whether this skill is appropriate for their environment, review any generated or modified files before relying on them, and apply their organization's safety, security, and compliance requirements before deployment. <br>
