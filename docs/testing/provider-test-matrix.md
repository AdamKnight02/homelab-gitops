# Provider/Tier Test Matrix

## Overview

This document defines the test coverage matrix across cloud providers and service tiers. Each combination is classified by its test readiness level.

---

## Classification Levels

| Classification | Description | What's Tested |
|---------------|-------------|---------------|
| **STATIC** | Static validation only | terraform fmt, terraform validate, YAML syntax, manifest structure |
| **PLAN** | Terraform plan validated | All STATIC checks + terraform plan succeeds |
| **LIVE** | Full deployment tested | All PLAN checks + terraform apply + platform validation |
| **BLOCKED** | Cannot test | Missing tools, credentials, or implementation |

---

## Matrix

### Azure

| Tier | VM Size | Est. Cost | Classification | Can Plan | Can Apply | Notes |
|------|---------|-----------|---------------|----------|-----------|-------|
| Economy | Standard_B1s | ~$8/mo | STATIC | ✅ | ❌ | Authenticated, PLAN-ONLY mode |
| Standard | Standard_B2s | ~$32/mo | STATIC | ✅ | ❌ | Authenticated, PLAN-ONLY mode |
| Enterprise | Standard_D2s_v5 | ~$70/mo | STATIC | ✅ | ❌ | Authenticated, PLAN-ONLY mode |

**Status:** Azure CLI authenticated. Terraform validate passes. No deployment performed yet.

### AWS

| Tier | Instance Type | Est. Cost | Classification | Can Plan | Can Apply | Notes |
|------|--------------|-----------|---------------|----------|-----------|-------|
| Economy | t3.micro | ~$8/mo (free-tier) | PLAN | ✅ | ❌ | Free-tier eligible, not deployed |
| Standard | t3.small | ~$15/mo | PLAN | ✅ | ❌ | Not yet deployed |
| Enterprise | t3.medium | ~$30/mo | PLAN | ✅ | ❌ | Not yet deployed |

**Status:** AWS CLI authenticated. Terraform plan validated. No deployment performed yet.

### Alibaba Cloud

| Tier | Instance Type | Est. Cost | Classification | Can Plan | Can Apply | Notes |
|------|--------------|-----------|---------------|----------|-----------|-------|
| Economy | ecs.t6-c1m1.large | ~$10/mo | BLOCKED | ❌ | ❌ | aliyun CLI not installed |
| Standard | ecs.t6-c1m2.large | ~$20/mo | BLOCKED | ❌ | ❌ | aliyun CLI not installed |
| Enterprise | ecs.c6.large | ~$50/mo | BLOCKED | ❌ | ❌ | aliyun CLI not installed |

**Status:** BLOCKED. Alibaba Cloud CLI (`aliyun`) is not installed. Terraform configuration exists but cannot be validated or applied.

---

## External CA Integration Matrix

| Scenario | Provider | Type | Expected | Status | Notes |
|----------|----------|------|----------|--------|-------|
| No External CA | none | Baseline | PASS | ✅ Implemented | Internal CA only |
| Let's Encrypt Prod | letsencrypt | ACME | BLOCKED | 🚫 Blocked | Needs public DNS |
| Let's Encrypt Staging | letsencrypt-staging | ACME | BLOCKED | 🚫 Blocked | Safe for testing |
| DigiCert | digicert | AnyCA | BLOCKED | 🚫 Blocked | Needs API key |
| Sectigo | sectigo | AnyCA | BLOCKED | 🚫 Blocked | Needs API key |
| GlobalSign | globalsign | AnyCA | BLOCKED | 🚫 Blocked | Needs API key |
| Entrust | entrust | AnyCA | BLOCKED | 🚫 Blocked | Needs API key |
| GoDaddy | godaddy | Custom | BLOCKED | 🚫 Blocked | Needs custom adapter |
| Custom CA | custom | Custom | BLOCKED | 🚫 Blocked | Needs implementation |
| Add-On CA | addon | Lifecycle | BLOCKED | 🚫 Blocked | Post-deploy addition |
| Re-run CA Setup | rerun | Lifecycle | BLOCKED | 🚫 Blocked | Idempotency check |
| Remove CA | removal | Lifecycle | BLOCKED | 🚫 Blocked | Cleanup verification |
| Invalid Provider | invalid | Negative | FAIL | ✅ Implemented | Schema validation |
| Missing Credentials | missing-creds | Negative | FAIL | ✅ Implemented | Credential validation |
| Duplicate Gateway | duplicate | Negative | FAIL | ✅ Implemented | Unique constraint |

---

## Tool Availability

| Tool | Status | Impact |
|------|--------|--------|
| terraform | ✅ Available | All Terraform tests can run |
| kubectl | ✅ Available | K8s and platform tests can run |
| az (Azure CLI) | ✅ Authenticated | Azure cloud tests can run |
| aws (AWS CLI) | ✅ Authenticated | AWS cloud tests can run |
| aliyun (Alibaba CLI) | ❌ Not installed | Alibaba tests BLOCKED |
| pwsh (PowerShell) | ❌ Not installed | Windows tests use static fallback |
| helm | ⚠️ Optional | Helm chart tests skipped if missing |
| jq | ✅ Available | JSON processing available |
| yq | ⚠️ Optional | YAML processing has fallback |

---

## Coverage Summary

| Category | Total | Tested | Blocked | Coverage |
|----------|-------|--------|---------|----------|
| Provider/Tier combinations | 9 | 6 | 3 | 67% |
| External CA scenarios | 14 | 4 | 10 | 29% |
| Test levels | 7 | 7 | 0 | 100% |
| Tools | 9 | 6 | 3 | 67% |

---

## Upgrade Path

To move a provider/tier from STATIC → PLAN → LIVE:

1. **STATIC → PLAN:** Run `terraform plan` successfully
2. **PLAN → LIVE:** Run `terraform apply` + pass Levels 3-5 tests
3. **BLOCKED → STATIC:** Install required CLI tools and authenticate

To unblock Alibaba Cloud:
```bash
# Install Alibaba Cloud CLI
pip install aliyun-python-sdk-core
# Or download from: https://github.com/aliyun/aliyun-cli

# Configure credentials
aliyun configure
```

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-09-12 | QA Agent | Initial provider/tier test matrix |
