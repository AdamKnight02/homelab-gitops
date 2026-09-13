#!/usr/bin/env bash
# =============================================================================
# state-guard.sh — Terraform State Safety Guard
# =============================================================================
# Pre-operation safety guard for Terraform state operations. Validates
# provider/customer/environment/component identity, state lock status,
# and safety rules before allowing plan/apply/destroy/import/migration.
#
# Usage:
#   ./scripts/state-guard.sh --provider azure --environment lab --component core --operation plan
#   ./scripts/state-guard.sh --provider azure --environment lab --component core --operation apply --strict
#
# Exit codes:
#   0 = Guard passed, operation allowed
#   1 = Guard failed, operation blocked
#   2 = Guard warnings (non-strict: pass, strict: fail)
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="${WORKSPACE_DIR}/.work/agent-state/guard-${TIMESTAMP}.log"

# Default options
PROVIDER=""
ENVIRONMENT=""
COMPONENT=""
CUSTOMER="default"
OPERATION=""
STRICT_MODE=false
SKIP_LOCK_CHECK=false
SKIP_IDENTITY_CHECK=false
SKIP_SAFETY_CHECK=false

# Guard results
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
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${LOG_FILE}"
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

Terraform State Safety Guard — validates before plan/apply/destroy/import/migration.

OPTIONS:
    --provider PROVIDER       Cloud provider (azure, aws, alibaba) [required]
    --environment ENV         Environment (lab, dev, staging, prod) [required]
    --component COMPONENT     Component (core, addons, monitoring) [required]
    --customer CUSTOMER       Customer identifier (default: default)
    --operation OP            Operation (plan, apply, destroy, import, migrate) [required]
    --strict                  Strict mode: warnings become errors
    --skip-lock-check         Skip state lock check
    --skip-identity-check     Skip identity check
    --skip-safety-check       Skip safety rules check
    --help                    Show this help message

EXAMPLES:
    # Guard before plan
    $(basename "$0") --provider azure --environment lab --component core --operation plan

    # Guard before apply in strict mode
    $(basename "$0") --provider azure --environment lab --component core --operation apply --strict

    # Guard before destroy
    $(basename "$0") --provider azure --environment lab --component core --operation destroy

EXIT CODES:
    0 = Guard passed, operation allowed
    1 = Guard failed, operation blocked
    2 = Guard warnings (non-strict: pass, strict: fail)

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
            --component)
                COMPONENT="$2"
                shift 2
                ;;
            --customer)
                CUSTOMER="$2"
                shift 2
                ;;
            --operation)
                OPERATION="$2"
                shift 2
                ;;
            --strict)
                STRICT_MODE=true
                shift
                ;;
            --skip-lock-check)
                SKIP_LOCK_CHECK=true
                shift
                ;;
            --skip-identity-check)
                SKIP_IDENTITY_CHECK=true
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

    if [[ -z "${COMPONENT}" ]]; then
        log_error "--component is required"
        usage
    fi

    if [[ -z "${OPERATION}" ]]; then
        log_error "--operation is required"
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

    # Validate component
    if [[ ! "${COMPONENT}" =~ ^(core|addons|monitoring)$ ]]; then
        log_error "Invalid component: ${COMPONENT}. Must be core, addons, or monitoring."
        exit 1
    fi

    # Validate operation
    if [[ ! "${OPERATION}" =~ ^(plan|apply|destroy|import|migrate)$ ]]; then
        log_error "Invalid operation: ${OPERATION}. Must be plan, apply, destroy, import, or migrate."
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Check State Identity
# -----------------------------------------------------------------------------
check_identity() {
    if [[ "${SKIP_IDENTITY_CHECK}" == true ]]; then
        log_info "Skipping identity check"
        return 0
    fi

    log_info "Checking state identity..."

    local tf_dir="${WORKSPACE_DIR}/infra/terraform/${PROVIDER}"
    local backend_config="${tf_dir}/backend.hcl"

    # Check if backend config exists
    if [[ ! -f "${backend_config}" ]]; then
        log_error "Backend configuration not found: ${backend_config}"
        log_error "Run the bootstrap layer first to create state infrastructure"
        return 1
    fi

    # Verify backend configuration matches expected values
    local expected_rg="pki-state-rg-${ENVIRONMENT}"
    local expected_key="environments/${ENVIRONMENT}/${PROVIDER}/${COMPONENT}/terraform.tfstate"

    if ! grep -q "resource_group_name.*=.*\"${expected_rg}\"" "${backend_config}"; then
        log_error "Backend config resource_group_name mismatch. Expected: ${expected_rg}"
        log_error "This may indicate you're using the wrong environment's state"
        return 1
    fi

    if ! grep -q "key.*=.*\"${expected_key}\"" "${backend_config}"; then
        log_error "Backend config key mismatch. Expected: ${expected_key}"
        log_error "This may indicate you're using the wrong component's state"
        return 1
    fi

    # Check if Terraform is initialized
    if [[ ! -d "${tf_dir}/.terraform" ]]; then
        log_warn "Terraform not initialized in ${tf_dir}. Run 'terraform init' first."
    fi

    # Verify state environment matches (if state exists)
    if [[ -d "${tf_dir}/.terraform" ]]; then
        local state_env
        state_env="$(cd "${tf_dir}" && terraform output -raw environment 2>/dev/null || echo '')"

        # Skip if no outputs found (state not applied yet)
        if [[ "${state_env}" == *"No outputs found"* ]]; then
            state_env=""
        fi

        if [[ -n "${state_env}" && "${state_env}" != "${ENVIRONMENT}" ]]; then
            log_error "State environment mismatch: state has '${state_env}', expected '${ENVIRONMENT}'"
            log_error "You may be about to modify the wrong environment's infrastructure"
            return 1
        fi

        local state_provider
        state_provider="$(cd "${tf_dir}" && terraform output -raw cloud_provider 2>/dev/null || echo '')"

        # Skip if no outputs found
        if [[ "${state_provider}" == *"No outputs found"* ]]; then
            state_provider=""
        fi

        if [[ -n "${state_provider}" && "${state_provider}" != "${PROVIDER}" ]]; then
            log_error "State provider mismatch: state has '${state_provider}', expected '${PROVIDER}'"
            return 1
        fi
    fi

    log_pass "State identity verified"
    return 0
}

# -----------------------------------------------------------------------------
# Check State Lock
# -----------------------------------------------------------------------------
check_lock() {
    if [[ "${SKIP_LOCK_CHECK}" == true ]]; then
        log_info "Skipping lock check"
        return 0
    fi

    log_info "Checking state lock..."

    local tf_dir="${WORKSPACE_DIR}/infra/terraform/${PROVIDER}"

    if [[ ! -d "${tf_dir}/.terraform" ]]; then
        log_info "Terraform not initialized, skipping lock check"
        return 0
    fi

    # Try to acquire lock with short timeout
    if ! (cd "${tf_dir}" && terraform plan -lock=true -lock-timeout=5s -input=false > /dev/null 2>&1); then
        log_error "State is locked by another process"
        log_error "Wait for the other operation to complete or force-unlock if safe"
        log_error "Force unlock: terraform force-unlock <LOCK_ID>"
        return 1
    fi

    log_pass "State lock can be acquired"
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

    # Rule 1: Check for pending changes (for apply/destroy)
    if [[ "${OPERATION}" == "apply" || "${OPERATION}" == "destroy" ]]; then
        if [[ -d "${tf_dir}/.terraform" ]]; then
            local plan_exit_code
            (cd "${tf_dir}" && terraform plan -detailed-exitcode -input=false > /dev/null 2>&1) && plan_exit_code=$? || plan_exit_code=$?

            case ${plan_exit_code} in
                0)
                    log_pass "No pending changes"
                    ;;
                1)
                    log_error "Terraform plan failed with error"
                    return 1
                    ;;
                2)
                    log_warn "Pending changes detected. Review before proceeding."
                    ;;
            esac
        fi
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
            log_error "Remove state files from Git before proceeding"
            return 1
        fi
    fi

    # Rule 4: Check .gitignore
    local gitignore="${WORKSPACE_DIR}/.gitignore"
    if [[ -f "${gitignore}" ]]; then
        if ! grep -q '\.tfstate' "${gitignore}"; then
            log_warn ".gitignore does not include .tfstate patterns"
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
    fi

    # Rule 6: Operation-specific checks
    case "${OPERATION}" in
        destroy)
            log_warn "DESTROY operation requested for ${PROVIDER}/${ENVIRONMENT}/${COMPONENT}"
            log_warn "This will DELETE all infrastructure managed by this state"
            ;;
        import)
            log_info "IMPORT operation requested"
            log_info "Ensure you have the correct resource IDs"
            ;;
        migrate)
            log_info "MIGRATE operation requested"
            log_info "Ensure you have backed up state before migration"
            ;;
    esac

    log_pass "Safety rules check complete"
    return 0
}

# -----------------------------------------------------------------------------
# Generate Guard Report
# -----------------------------------------------------------------------------
generate_report() {
    local report_file="${WORKSPACE_DIR}/.work/agent-state/guard-report-${PROVIDER}-${ENVIRONMENT}-${COMPONENT}-${OPERATION}-${TIMESTAMP}.md"

    mkdir -p "$(dirname "${report_file}")"

    cat > "${report_file}" << EOF
# State Guard Report

**Provider:** ${PROVIDER}
**Environment:** ${ENVIRONMENT}
**Component:** ${COMPONENT}
**Customer:** ${CUSTOMER}
**Operation:** ${OPERATION}
**Timestamp:** $(date -Iseconds)
**Strict Mode:** ${STRICT_MODE}

## Summary

| Check | Status | Errors | Warnings |
|-------|--------|--------|----------|
| Identity | $([ ${ERRORS} -eq 0 ] && echo "✅ PASS" || echo "❌ FAIL") | ${ERRORS} | ${WARNINGS} |
| Lock | $([ ${ERRORS} -eq 0 ] && echo "✅ PASS" || echo "❌ FAIL") | - | - |
| Safety | $([ ${ERRORS} -eq 0 ] && echo "✅ PASS" || echo "❌ FAIL") | - | - |

## Overall Result

$([ ${ERRORS} -eq 0 ] && [ ${WARNINGS} -eq 0 ] && echo "✅ **GUARD PASSED** — Operation allowed" || echo "")
$([ ${ERRORS} -eq 0 ] && [ ${WARNINGS} -gt 0 ] && echo "⚠️ **GUARD PASSED WITH WARNINGS** — Operation allowed with caution" || echo "")
$([ ${ERRORS} -gt 0 ] && echo "❌ **GUARD FAILED** — Operation blocked" || echo "")

## Details

See console output for detailed guard results.

---
Generated by state-guard.sh
EOF

    log_info "Guard report generated: ${report_file}"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    log_info "Starting state guard"
    log_info "Provider: ${PROVIDER}"
    log_info "Environment: ${ENVIRONMENT}"
    log_info "Component: ${COMPONENT}"
    log_info "Customer: ${CUSTOMER}"
    log_info "Operation: ${OPERATION}"
    log_info "Strict mode: ${STRICT_MODE}"

    # Create log directory
    mkdir -p "$(dirname "${LOG_FILE}")"

    # Parse arguments
    parse_args "$@"

    # Run checks
    check_identity || exit 1
    check_lock || exit 1
    check_safety || exit 1

    # Generate report
    generate_report

    # Summary
    log_info "Guard complete: ${ERRORS} errors, ${WARNINGS} warnings"

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
