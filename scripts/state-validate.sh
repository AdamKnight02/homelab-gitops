#!/usr/bin/env bash
# =============================================================================
# state-validate.sh — Terraform State Validation Script
# =============================================================================
# Validates Terraform state before any plan/apply/destroy operation.
# Checks provider/customer/environment/component identity, state integrity,
# and safety rules.
#
# Usage:
#   ./scripts/state-validate.sh --provider azure --environment lab
#   ./scripts/state-validate.sh --provider aws --environment prod --strict
#
# Exit codes:
#   0 = Validation passed
#   1 = Validation failed
#   2 = Validation warnings (non-strict mode: pass, strict mode: fail)
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Default options
PROVIDER=""
ENVIRONMENT=""
CUSTOMER="default"
COMPONENT=""
STRICT_MODE=false
SKIP_IDENTITY_CHECK=false
SKIP_INTEGRITY_CHECK=false
SKIP_SAFETY_CHECK=false

# Validation results
ERRORS=0
WARNINGS=0

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${timestamp}] [${level}] ${message}"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; WARNINGS=$((WARNINGS + 1)); }
log_error() { log "ERROR" "$@"; ERRORS=$((ERRORS + 1)); }
log_pass() { log "PASS" "$@"; }

# -----------------------------------------------------------------------------
# Usage
# -----------------------------------------------------------------------------
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Validate Terraform state before plan/apply/destroy operations.

OPTIONS:
    --provider PROVIDER       Cloud provider (azure, aws, alibaba) [required]
    --environment ENV         Environment (lab, dev, staging, prod) [required]
    --customer CUSTOMER       Customer identifier (default: default)
    --component COMPONENT     Component to validate (compute, network, pki, etc.)
    --strict                  Strict mode: warnings become errors
    --skip-identity-check     Skip provider/customer/environment identity check
    --skip-integrity-check    Skip state integrity check
    --skip-safety-check       Skip safety rules check
    --help                    Show this help message

EXAMPLES:
    # Validate Azure lab environment
    $(basename "$0") --provider azure --environment lab

    # Validate AWS prod environment in strict mode
    $(basename "$0") --provider aws --environment prod --strict

    # Validate specific component
    $(basename "$0") --provider azure --environment lab --component pki

EXIT CODES:
    0 = Validation passed
    1 = Validation failed
    2 = Validation warnings (non-strict: pass, strict: fail)

EOF
    exit 0
}

# -----------------------------------------------------------------------------
# Parse Arguments
# -----------------------------------------------------------------------------
parse_args() {
    # Check for --help first
    for arg in "$@"; do
        if [[ "$arg" == "--help" ]]; then
            usage
        fi
    done

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --provider)
                PROVIDER="$2"
                shift 2
                ;;
            --environment)
                ENVIRONMENT="$2"
                shift 2
                ;;
            --customer)
                CUSTOMER="$2"
                shift 2
                ;;
            --component)
                COMPONENT="$2"
                shift 2
                ;;
            --strict)
                STRICT_MODE=true
                shift
                ;;
            --skip-identity-check)
                SKIP_IDENTITY_CHECK=true
                shift
                ;;
            --skip-integrity-check)
                SKIP_INTEGRITY_CHECK=true
                shift
                ;;
            --skip-safety-check)
                SKIP_SAFETY_CHECK=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done

    # Validate required arguments
    if [[ -z "${PROVIDER}" ]]; then
        log_error "--provider is required"
        usage
    fi

    if [[ -z "${ENVIRONMENT}" ]]; then
        log_error "--environment is required"
        usage
    fi

    # Validate provider
    if [[ ! "${PROVIDER}" =~ ^(azure|aws|alibaba)$ ]]; then
        log_error "Invalid provider: ${PROVIDER}. Must be azure, aws, or alibaba."
        exit 1
    fi

    # Validate environment
    if [[ ! "${ENVIRONMENT}" =~ ^(lab|dev|staging|prod)$ ]]; then
        log_error "Invalid environment: ${ENVIRONMENT}. Must be lab, dev, staging, or prod."
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Check Provider Identity
# -----------------------------------------------------------------------------
check_identity() {
    if [[ "${SKIP_IDENTITY_CHECK}" == true ]]; then
        log_info "Skipping identity check"
        return 0
    fi

    log_info "Checking provider/customer/environment identity..."

    local tf_dir="${WORKSPACE_DIR}/infra/terraform/${PROVIDER}"

    # Check if directory exists
    if [[ ! -d "${tf_dir}" ]]; then
        log_error "Terraform directory not found: ${tf_dir}"
        return 1
    fi

    # Check if Terraform is initialized
    if [[ ! -d "${tf_dir}/.terraform" ]]; then
        log_warn "Terraform not initialized in ${tf_dir}. Run 'terraform init' first."
    fi

    # Check backend configuration
    local backend_file="${tf_dir}/backend.tf"
    if [[ -f "${backend_file}" ]]; then
        log_info "Backend configuration found: ${backend_file}"
        
        # Verify backend type matches provider
        local backend_type
        backend_type="$(grep -oP 'backend "\K[^"]+' "${backend_file}" || echo 'unknown')"
        
        case "${PROVIDER}" in
            azure)
                if [[ "${backend_type}" != "azurerm" ]]; then
                    log_error "Backend type mismatch: expected azurerm, got ${backend_type}"
                else
                    log_pass "Backend type matches provider: ${backend_type}"
                fi
                ;;
            aws)
                if [[ "${backend_type}" != "s3" ]]; then
                    log_error "Backend type mismatch: expected s3, got ${backend_type}"
                else
                    log_pass "Backend type matches provider: ${backend_type}"
                fi
                ;;
            alibaba)
                if [[ "${backend_type}" != "oss" ]]; then
                    log_error "Backend type mismatch: expected oss, got ${backend_type}"
                else
                    log_pass "Backend type matches provider: ${backend_type}"
                fi
                ;;
        esac
    else
        log_warn "No backend configuration found. Using local state."
    fi

    # Check variables match environment
    local tfvars_file="${tf_dir}/terraform.tfvars"
    if [[ -f "${tfvars_file}" ]]; then
        local env_var
        env_var="$(grep -oP 'environment\s*=\s*"\K[^"]+' "${tfvars_file}" || echo '')"
        
        if [[ -n "${env_var}" && "${env_var}" != "${ENVIRONMENT}" ]]; then
            log_error "Environment mismatch: tfvars has '${env_var}', expected '${ENVIRONMENT}'"
        elif [[ -n "${env_var}" ]]; then
            log_pass "Environment matches tfvars: ${env_var}"
        fi
    fi

    # Check state identity (if state exists)
    if [[ -d "${tf_dir}/.terraform" ]]; then
        local state_env
        state_env="$(cd "${tf_dir}" && terraform output -raw environment 2>/dev/null || echo '')"
        
        # Skip if no outputs found (state not applied yet)
        if [[ "${state_env}" == *"No outputs found"* ]]; then
            log_info "State not applied yet (no outputs found)"
            state_env=""
        fi
        
        if [[ -n "${state_env}" && "${state_env}" != "${ENVIRONMENT}" ]]; then
            log_error "State environment mismatch: state has '${state_env}', expected '${ENVIRONMENT}'"
        elif [[ -n "${state_env}" ]]; then
            log_pass "State environment matches: ${state_env}"
        fi

        local state_provider
        state_provider="$(cd "${tf_dir}" && terraform output -raw cloud_provider 2>/dev/null || echo '')"
        
        # Skip if no outputs found (state not applied yet)
        if [[ "${state_provider}" == *"No outputs found"* ]]; then
            state_provider=""
        fi
        
        if [[ -n "${state_provider}" && "${state_provider}" != "${PROVIDER}" ]]; then
            log_error "State provider mismatch: state has '${state_provider}', expected '${PROVIDER}'"
        elif [[ -n "${state_provider}" ]]; then
            log_pass "State provider matches: ${state_provider}"
        fi
    fi

    log_info "Identity check complete"
    return 0
}

# -----------------------------------------------------------------------------
# Check State Integrity
# -----------------------------------------------------------------------------
check_integrity() {
    if [[ "${SKIP_INTEGRITY_CHECK}" == true ]]; then
        log_info "Skipping integrity check"
        return 0
    fi

    log_info "Checking state integrity..."

    local tf_dir="${WORKSPACE_DIR}/infra/terraform/${PROVIDER}"

    # Check if state file exists (local backend)
    local state_file="${tf_dir}/terraform.tfstate"
    if [[ -f "${state_file}" ]]; then
        log_info "Local state file found: ${state_file}"
        
        # Verify JSON
        if ! jq empty "${state_file}" > /dev/null 2>&1; then
            log_error "State file is not valid JSON: ${state_file}"
        else
            log_pass "State file is valid JSON"
        fi

        # Check state version
        local state_version
        state_version="$(jq -r '.version // 0' "${state_file}")"
        if [[ "${state_version}" -lt 4 ]]; then
            log_warn "State version ${state_version} is older than expected (>= 4)"
        else
            log_pass "State version is current: ${state_version}"
        fi

        # Check for serial
        local serial
        serial="$(jq -r '.serial // 0' "${state_file}")"
        log_info "State serial: ${serial}"

        # Check lineage
        local lineage
        lineage="$(jq -r '.lineage // "unknown"' "${state_file}")"
        log_info "State lineage: ${lineage}"
    else
        log_info "No local state file found (using remote backend)"
    fi

    # Check if Terraform can read state
    if [[ -d "${tf_dir}/.terraform" ]]; then
        if ! (cd "${tf_dir}" && terraform state list > /dev/null 2>&1); then
            log_warn "Terraform cannot read state. State may not exist yet (never applied)."
        else
            log_pass "Terraform can read state"
            
            # Count resources
            local resource_count
            resource_count="$(cd "${tf_dir}" && terraform state list 2>/dev/null | wc -l)"
            log_info "Resources in state: ${resource_count}"
        fi
    fi

    # Check for state lock
    if [[ -d "${tf_dir}/.terraform" ]]; then
        # Try to acquire lock with short timeout
        if ! (cd "${tf_dir}" && terraform plan -lock=true -lock-timeout=5s -input=false > /dev/null 2>&1); then
            log_warn "State may be locked by another process"
        else
            log_pass "State lock can be acquired"
        fi
    fi

    log_info "Integrity check complete"
    return 0
}

# -----------------------------------------------------------------------------
# Check Safety Rules
# -----------------------------------------------------------------------------
check_safety() {
    if [[ "${SKIP_SAFETY_CHECK}" == true ]]; then
        log_info "Skipping safety check"
        return 0
    fi

    log_info "Checking safety rules..."

    local tf_dir="${WORKSPACE_DIR}/infra/terraform/${PROVIDER}"

    # Rule 1: Check for pending changes
    if [[ -d "${tf_dir}/.terraform" ]]; then
        local plan_exit_code
        (cd "${tf_dir}" && terraform plan -detailed-exitcode -input=false > /dev/null 2>&1) && plan_exit_code=$? || plan_exit_code=$?
        
        case ${plan_exit_code} in
            0)
                log_pass "No pending changes"
                ;;
            1)
                log_error "Terraform plan failed with error"
                ;;
            2)
                log_warn "Pending changes detected. Review before proceeding."
                ;;
        esac
    fi

    # Rule 2: Check for sensitive outputs
    if [[ -d "${tf_dir}/.terraform" ]]; then
        local sensitive_outputs
        sensitive_outputs="$(cd "${tf_dir}" && terraform output -json 2>/dev/null | jq -r 'to_entries | map(select(.value.sensitive == true)) | .[].key' 2>/dev/null || echo '')"
        
        if [[ -n "${sensitive_outputs}" ]]; then
            log_info "Sensitive outputs found (will not be displayed):"
            echo "${sensitive_outputs}" | while read -r output; do
                log_info "  - ${output}"
            done
        fi
    fi

    # Rule 3: Check for state files in Git
    if [[ -d "${WORKSPACE_DIR}/.git" ]]; then
        local state_in_git
        state_in_git="$(cd "${WORKSPACE_DIR}" && git ls-files | grep -E '\.tfstate' || echo '')"
        
        if [[ -n "${state_in_git}" ]]; then
            log_error "State files found in Git repository:"
            echo "${state_in_git}" | while read -r file; do
                log_error "  - ${file}"
            done
        else
            log_pass "No state files in Git repository"
        fi
    fi

    # Rule 4: Check .gitignore
    local gitignore="${WORKSPACE_DIR}/.gitignore"
    if [[ -f "${gitignore}" ]]; then
        if ! grep -q '\.tfstate' "${gitignore}"; then
            log_warn ".gitignore does not include .tfstate patterns"
        else
            log_pass ".gitignore includes .tfstate patterns"
        fi
    else
        log_warn ".gitignore not found"
    fi

    # Rule 5: Check for hardcoded secrets in .tf files
    local secrets_found
    secrets_found="$(grep -r -E '(password|secret|key|token)\s*=\s*"[^"]+"' "${tf_dir}" --include="*.tf" 2>/dev/null | grep -v 'sensitive\s*=\s*true' || echo '')"
    
    if [[ -n "${secrets_found}" ]]; then
        log_warn "Potential hardcoded secrets found in .tf files:"
        echo "${secrets_found}" | while read -r line; do
            log_warn "  ${line}"
        done
    else
        log_pass "No obvious hardcoded secrets found"
    fi

    # Rule 6: Check for PKI material classification (if component is pki)
    if [[ "${COMPONENT}" == "pki" || -z "${COMPONENT}" ]]; then
        log_info "Checking PKI material classification..."
        
        # Check for Root CA keys in state
        if [[ -d "${tf_dir}/.terraform" ]]; then
            local root_ca_keys
            root_ca_keys="$(cd "${tf_dir}" && terraform state list 2>/dev/null | grep -i 'root.*ca\|ca.*root' || echo '')"
            
            if [[ -n "${root_ca_keys}" ]]; then
                log_warn "Root CA resources found in state. Ensure keys are HSM-protected:"
                echo "${root_ca_keys}" | while read -r resource; do
                    log_warn "  - ${resource}"
                done
            fi
        fi
    fi

    log_info "Safety check complete"
    return 0
}

# -----------------------------------------------------------------------------
# Generate Validation Report
# -----------------------------------------------------------------------------
generate_report() {
    local report_file="${WORKSPACE_DIR}/.work/agent-state/validation-${PROVIDER}-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S).md"
    
    mkdir -p "$(dirname "${report_file}")"

    cat > "${report_file}" << EOF
# State Validation Report

**Provider:** ${PROVIDER}
**Environment:** ${ENVIRONMENT}
**Customer:** ${CUSTOMER}
**Component:** ${COMPONENT:-all}
**Timestamp:** $(date -Iseconds)
**Strict Mode:** ${STRICT_MODE}

## Summary

| Check | Status | Errors | Warnings |
|-------|--------|--------|----------|
| Identity | $([ ${ERRORS} -eq 0 ] && echo "✅ PASS" || echo "❌ FAIL") | ${ERRORS} | ${WARNINGS} |
| Integrity | $([ ${ERRORS} -eq 0 ] && echo "✅ PASS" || echo "❌ FAIL") | - | - |
| Safety | $([ ${ERRORS} -eq 0 ] && echo "✅ PASS" || echo "❌ FAIL") | - | - |

## Overall Result

$([ ${ERRORS} -eq 0 ] && [ ${WARNINGS} -eq 0 ] && echo "✅ **VALIDATION PASSED**" || echo "")
$([ ${ERRORS} -eq 0 ] && [ ${WARNINGS} -gt 0 ] && echo "⚠️ **VALIDATION PASSED WITH WARNINGS**" || echo "")
$([ ${ERRORS} -gt 0 ] && echo "❌ **VALIDATION FAILED**" || echo "")

## Details

See console output for detailed validation results.

---
Generated by state-validate.sh
EOF

    log_info "Validation report generated: ${report_file}"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    log_info "Starting state validation"
    log_info "Provider: ${PROVIDER}"
    log_info "Environment: ${ENVIRONMENT}"
    log_info "Customer: ${CUSTOMER}"
    log_info "Component: ${COMPONENT:-all}"
    log_info "Strict mode: ${STRICT_MODE}"

    # Parse arguments
    parse_args "$@"

    # Run checks
    check_identity
    check_integrity
    check_safety

    # Generate report
    generate_report

    # Summary
    log_info "Validation complete: ${ERRORS} errors, ${WARNINGS} warnings"

    # Determine exit code
    if [[ ${ERRORS} -gt 0 ]]; then
        exit 1
    elif [[ ${WARNINGS} -gt 0 && "${STRICT_MODE}" == true ]]; then
        exit 1
    elif [[ ${WARNINGS} -gt 0 ]]; then
        exit 2
    else
        exit 0
    fi
}

# Run main
main "$@"
