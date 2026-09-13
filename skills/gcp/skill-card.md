## Description: <br>
Architects, debugs, secures, and cost-optimizes Google Cloud environments across Cloud Run, GKE, Compute Engine, BigQuery, Cloud SQL, IAM, VPC, Vertex AI, storage, pipelines, and infrastructure workflows. <br>

This skill is ready for commercial/non-commercial use. <br>

## Publisher: <br>
[ivangdavila](https://clawhub.ai/user/ivangdavila) <br>

### License/Terms of Use: <br>
MIT-0 <br>


## Use Case: <br>
Developers, cloud engineers, and platform teams use this skill to plan, review, troubleshoot, secure, and optimize GCP projects and services. It can generate guidance, commands, infrastructure notes, and local operational memory for durable findings. <br>

### Deployment Geography for Use: <br>
Global <br>

## Known Risks and Mitigations: <br>
Risk: Generated gcloud commands can affect IAM, billing, projects, datasets, keys, node pools, or other cloud resources if executed without review. <br>
Mitigation: Review commands before running them, especially commands that create, modify, delete, detach billing, change IAM, or alter production resources. <br>
Risk: The skill stores local operational notes under ~/Clawic/data/, which may include sensitive incident context if users save it there. <br>
Mitigation: Protect the local Clawic data directory and store credential values only as pointers, not as secrets. <br>


## Reference(s): <br>
- [ClawHub skill page](https://clawhub.ai/ivangdavila/skills/gcp) <br>
- [Publisher profile](https://clawhub.ai/user/ivangdavila) <br>
- [Clawic Google Cloud skill page](https://clawic.com/skills/gcp) <br>


## Skill Output: <br>
**Output Type(s):** [Guidance, Markdown, Shell commands, Code, Configuration] <br>
**Output Format:** [Markdown with inline shell commands, code snippets, configuration examples, and local note updates] <br>
**Output Parameters:** [1D] <br>
**Other Properties Related to Output:** [Requires gcloud for command-oriented workflows and may read or write local operational notes under configured Clawic data paths.] <br>

## Skill Version(s): <br>
1.0.2 (source: artifact frontmatter and server release evidence) <br>

## Ethical Considerations: <br>
Users should evaluate whether this skill is appropriate for their environment, review any generated or modified files before relying on them, and apply their organization's safety, security, and compliance requirements before deployment. <br>
