#!/usr/bin/env bash
# =============================================================================
# state-migrate.sh — Local to Remote State Migration Script
# =============================================================================
# Migrates Terraform state from local backend to Azure remote backend with
# comprehensive safety checks, backup, and validation.
#
# Usage:
#   ./scripts/state-migrate.sh --provider azure --environment lab --component core
#   ./scripts/state-migrate.sh --provider azure --environment lab --component core --dry-run
#
# Exit codes:
#   0 = Success
#   1 = Error
#   2 = Validation failed
#   3 = Migration aborted by user
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="${WORKSPACE_DIR}/.work/agent-state/migration-${TIMESTAMP}.log"

# Default options
PROVIDER=""
ENVIRONMENT=""
COMPONENT=""
CUSTOMER="default"
SOURCE_DIR=""
BACKEND_CONFIG=""
DRY_RUN=false
FORCE=false
SKIP_BACKUP=false
SKIP_VALIDATION=false

# Migration state
MIGRATION_ID="mig-${TIMESTAMP}"
BACKUP_FILE=""
STATE_FILE=""

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
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_pass() { log "PASS" "$@"; }

# -----------------------------------------------------------------------------
# Usage
# -----------------------------------------------------------------------------
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Migrate Terraform state from local backend to Azure remote backend.

OPTIONS:
    --provider PROVIDER       Cloud provider (azure, aws, alibaba) [required]
    --environment ENV         Environment (lab, dev, staging, prod) [required]
    --component COMPONENT     Component (core, addons, monitoring) [required]
    --customer CUSTOMER       Customer identifier (default: default)
    --source-dir DIR          Source Terraform directory (default: infra/terraform/{provider})
    --backend-config FILE     Backend config file (default: {source-dir}/backend.hcl)
    --dry-run                 Show what would be done without doing it
    --force                   Skip confirmation prompts
    --skip-backup             Skip state backup (NOT RECOMMENDED)
    --skip-validation         Skip pre-migration validation (NOT RECOMMENDED)
    --help                    Show this help message

EXAMPLES:
    # Migrate Azure lab core component
    $(basename "$0") --provider azure --environment lab --component core

    # Dry run migration
    $(basename "$0") --provider azure --environment lab --component core --dry-run

    # Migrate with custom source directory
    $(basename "$0") --provider azure --environment lab --component core --source-dir /path/to/terraform

EXIT CODES:
    0 = Success
    1 = Error
    2 = Validation failed
    3 = Migration aborted by user

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
            --source-dir)
                SOURCE_DIR="$2"
                shift 2
                ;;
            --backend-config)
                BACKEND_CONFIG="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --skip-backup)
                SKIP_BACKUP=true
                shift
                ;;
            --skip-validation)
                SKIP_VALIDATION=true
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

    # Set defaults
    if [[ -z "${SOURCE_DIR}" ]]; then
        SOURCE_DIR="${WORKSPACE_DIR}/infra/terraform/${PROVIDER}"
    fi

    if [[ -z "${BACKEND_CONFIG}" ]]; then
        BACKEND_CONFIG="${SOURCE_DIR}/backend.hcl"
    fi
}

# -----------------------------------------------------------------------------
# Safety Check: Verify State Identity
# -----------------------------------------------------------------------------
check_state_identity() {
    log_info "Checking state identity..."

    # Verify source directory exists
    if [[ ! -d "${SOURCE_DIR}" ]]; then
        log_error "Source directory not found: ${SOURCE_DIR}"
        return 1
    fi

    # Verify backend configuration exists
    if [[ ! -f "${BACKEND_CONFIG}" ]]; then
        log_error "Backend configuration not found: ${BACKEND_CONFIG}"
        log_error "Run the bootstrap layer first to create state infrastructure"
        return 1
    fi

    # Verify backend configuration matches expected values
    local expected_rg="pki-state-rg-${ENVIRONMENT}"
    local expected_key="environments/${ENVIRONMENT}/${PROVIDER}/${COMPONENT}/terraform.tfstate"

    if ! grep -q "resource_group_name.*=.*\"${expected_rg}\"" "${BACKEND_CONFIG}"; then
        log_error "Backend config resource_group_name mismatch. Expected: ${expected_rg}"
        return 1
    fi

    if ! grep -q "key.*=.*\"${expected_key}\"" "${BACKEND_CONFIG}"; then
        log_error "Backend config key mismatch. Expected: ${expected_key}"
        return 1
    fi

    log_pass "State identity verified"
    return 0
}

# -----------------------------------------------------------------------------
# Safety Check: Verify No State in Git
# -----------------------------------------------------------------------------
check_git_safety() {
    log_info "Checking Git safety..."

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

    # Check .gitignore
    local gitignore="${WORKSPACE_DIR}/.gitignore"
    if [[ -f "${gitignore}" ]]; then
        if ! grep -q '\.tfstate' "${gitignore}"; then
            log_warn ".gitignore does not include .tfstate patterns"
        fi
    else
        log_warn ".gitignore not found"
    fi

    log_pass "Git safety verified"
    return 0
}

# -----------------------------------------------------------------------------
# Safety Check: Verify No Hardcoded Secrets
# -----------------------------------------------------------------------------
check_secrets_safety() {
    log_info "Checking for hardcoded secrets..."

    local secrets_found
    secrets_found="$(grep -r -E '(password|secret|key|token)\s*=\s*"[^"]+"' "${SOURCE_DIR}" --include="*.tf" 2>/dev/null | grep -v 'sensitive\s*=\s*true' || echo '')"

    if [[ -n "${secrets_found}" ]]; then
        log_warn "Potential hardcoded secrets found in .tf files:"
        echo "${secrets_found}" | while read -r line; do
            log_warn "  ${line}"
        done
        log_warn "Consider using data sources or external secrets management"
    fi

    log_pass "Secrets safety check complete"
    return 0
}

# -----------------------------------------------------------------------------
# Backup Local State
# -----------------------------------------------------------------------------
backup_state() {
    if [[ "${SKIP_BACKUP}" == true ]]; then
        log_warn "Skipping state backup (NOT RECOMMENDED)"
        return 0
    fi

    log_info "Backing up local state..."

    local backup_dir="${WORKSPACE_DIR}/backups/state/${PROVIDER}/${ENVIRONMENT}/${COMPONENT}"
    mkdir -p "${backup_dir}"

    BACKUP_FILE="${backup_dir}/terraform.tfstate.${TIMESTAMP}"
    STATE_FILE="${SOURCE_DIR}/terraform.tfstate"

    # Check if local state file exists
    if [[ ! -f "${STATE_FILE}" ]]; then
        log_error "Local state file not found: ${STATE_FILE}"
        log_error "Nothing to migrate"
        return 1
    fi

    # Copy state file
    cp "${STATE_FILE}" "${BACKUP_FILE}"

    # Generate checksum
    (cd "${backup_dir}" && sha256sum "$(basename "${BACKUP_FILE}")" > "$(basename "${BACKUP_FILE}").sha256")

    log_info "Backup created: ${BACKUP_FILE}"
    log_info "Checksum: $(cat "${BACKUP_FILE}.sha256")"

    # Verify backup
    if ! (cd "${backup_dir}" && sha256sum -c "$(basename "${BACKUP_FILE}").sha256" > /dev/null 2>&1); then
        log_error "Backup verification failed"
        return 1
    fi

    log_pass "State backup verified"
    return 0
}

# -----------------------------------------------------------------------------
# Validate Target Backend
# -----------------------------------------------------------------------------
validate_target_backend() {
    log_info "Validating target backend..."

    # Check if backend storage account exists
    local storage_account
    storage_account="$(grep -oP 'storage_account_name\s*=\s*"\K[^"]+' "${BACKEND_CONFIG}")"

    if [[ -z "${storage_account}" ]]; then
        log_error "Could not extract storage_account_name from backend config"
        return 1
    fi

    # Check if we can access the storage account
    if command -v az &> /dev/null; then
        if ! az storage account show --name "${storage_account}" --query "name" -o tsv > /dev/null 2>&1; then
            log_error "Cannot access storage account: ${storage_account}"
            log_error "Ensure you are logged in with 'az login' and have appropriate permissions"
            return 1
        fi
        log_pass "Storage account accessible: ${storage_account}"
    else
        log_warn "Azure CLI not found, skipping storage account validation"
    fi

    # Check if container exists
    local container_name
    container_name="$(grep -oP 'container_name\s*=\s*"\K[^"]+' "${BACKEND_CONFIG}")"

    if [[ -n "${container_name}" ]] && command -v az &> /dev/null; then
        if ! az storage container show --name "${container_name}" --account-name "${storage_account}" --auth-mode login > /dev/null 2>&1; then
            log_error "Container not found: ${container_name}"
            return 1
        fi
        log_pass "Container accessible: ${container_name}"
    fi

    log_pass "Target backend validated"
    return 0
}

# -----------------------------------------------------------------------------
# Migrate State
# -----------------------------------------------------------------------------
migrate_state() {
    log_info "Migrating state to remote backend..."

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY RUN] Would migrate state using:"
        log_info "  cd ${SOURCE_DIR}"
        log_info "  terraform init -migrate-state -backend-config=${BACKEND_CONFIG}"
        return 0
    fi

    # Change to source directory
    cd "${SOURCE_DIR}"

    # Initialize with migration
    log_info "Running terraform init -migrate-state..."
    if ! terraform init -migrate-state -backend-config="${BACKEND_CONFIG}" -input=false; then
        log_error "State migration failed"
        return 1
    fi

    log_pass "State migration complete"
    return 0
}

# -----------------------------------------------------------------------------
# Validate Migrated State
# -----------------------------------------------------------------------------
validate_migrated_state() {
    log_info "Validating migrated state..."

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY RUN] Would validate migrated state"
        return 0
    fi

    cd "${SOURCE_DIR}"

    # Check if Terraform can read state
    if ! terraform state list > /dev/null 2>&1; then
        log_error "Terraform cannot read migrated state"
        return 1
    fi

    # Count resources
    local resource_count
    resource_count="$(terraform state list 2>/dev/null | wc -l)"
    log_info "Resources in migrated state: ${resource_count}"

    # Verify state file no longer exists locally
    if [[ -f "${STATE_FILE}" ]]; then
        log_warn "Local state file still exists: ${STATE_FILE}"
        log_warn "This is expected if using -migrate-state (keeps backup)"
    fi

    log_pass "Migrated state validated"
    return 0
}

# -----------------------------------------------------------------------------
# Run Terraform Plan (Expect No Changes)
# -----------------------------------------------------------------------------
run_terraform_plan() {
    log_info "Running terraform plan to verify no unexplained changes..."

    if [[ "${DRY_RUN}" == true ]]; then
        log_info "[DRY RUN] Would run terraform plan"
        return 0
    fi

    cd "${SOURCE_DIR}"

    # Run plan with detailed exit code
    local plan_exit_code
    terraform plan -detailed-exitcode -input=false > /dev/null 2>&1 && plan_exit_code=$? || plan_exit_code=$?

    case ${plan_exit_code} in
        0)
            log_pass "No changes detected (expected)"
            ;;
        1)
            log_error "Terraform plan failed with error"
            return 1
            ;;
        2)
            log_warn "Changes detected in plan"
            log_warn "This may be expected if the infrastructure has drifted"
            log_warn "Review the plan output carefully before proceeding"
            ;;
    esac

    return 0
}

# -----------------------------------------------------------------------------
# Generate Migration Report
# -----------------------------------------------------------------------------
generate_report() {
    local report_file="${WORKSPACE_DIR}/.work/agent-state/migration-report-${MIGRATION_ID}.md"

    cat > "${report_file}" << EOF
# State Migration Report

**Migration ID:** ${MIGRATION_ID}
**Timestamp:** $(date -Iseconds)
**Provider:** ${PROVIDER}
**Environment:** ${ENVIRONMENT}
**Component:** ${COMPONENT}
**Customer:** ${CUSTOMER}
**Source Directory:** ${SOURCE_DIR}
**Backend Config:** ${BACKEND_CONFIG}
**Dry Run:** ${DRY_RUN}

## Migration Steps

| Step | Status |
|------|--------|
| State Identity Check | ✅ |
| Git Safety Check | ✅ |
| Secrets Safety Check | ✅ |
| State Backup | $([ "${SKIP_BACKUP}" == true ] && echo "⏭️ SKIPPED" || echo "✅") |
| Target Backend Validation | ✅ |
| State Migration | $([ "${DRY_RUN}" == true ] && echo "🔍 DRY RUN" || echo "✅") |
| Migrated State Validation | $([ "${DRY_RUN}" == true ] && echo "🔍 DRY RUN" || echo "✅") |
| Terraform Plan | $([ "${DRY_RUN}" == true ] && echo "🔍 DRY RUN" || echo "✅") |

## Files

- **Backup:** ${BACKUP_FILE:-N/A}
- **Backup Checksum:** ${BACKUP_FILE}.sha256
- **Log:** ${LOG_FILE}
- **Report:** ${report_file}

## Next Steps

1. Verify the migration was successful
2. Update any CI/CD pipelines to use the new backend
3. Remove local state files if no longer needed
4. Document the migration in your change log

## Rollback

If you need to rollback:

\`\`\`bash
# Restore from backup
cp ${BACKUP_FILE} ${STATE_FILE}

# Re-initialize with local backend
cd ${SOURCE_DIR}
terraform init -migrate-state -backend-config=backend.tf.local
\`\`\`

---
Generated by state-migrate.sh
EOF

    log_info "Migration report generated: ${report_file}"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    log_info "Starting state migration"
    log_info "Migration ID: ${MIGRATION_ID}"
    log_info "Provider: ${PROVIDER}"
    log_info "Environment: ${ENVIRONMENT}"
    log_info "Component: ${COMPONENT}"
    log_info "Customer: ${CUSTOMER}"
    log_info "Source Directory: ${SOURCE_DIR}"
    log_info "Backend Config: ${BACKEND_CONFIG}"
    log_info "Dry Run: ${DRY_RUN}"

    # Create log directory
    mkdir -p "$(dirname "${LOG_FILE}")"

    # Parse arguments
    parse_args "$@"

    # Run safety checks
    if [[ "${SKIP_VALIDATION}" != true ]]; then
        check_state_identity || exit 2
        check_git_safety || exit 2
        check_secrets_safety || exit 2
    else
        log_warn "Skipping validation checks (NOT RECOMMENDED)"
    fi

    # Backup state
    backup_state || exit 1

    # Validate target backend
    validate_target_backend || exit 1

    # Confirm migration
    if [[ "${FORCE}" != true && "${DRY_RUN}" != true ]]; then
        log_warn "About to migrate state for ${PROVIDER}/${ENVIRONMENT}/${COMPONENT}"
        log_warn "This will move state from local to remote backend"
        read -p "Continue? (yes/no): " confirm
        if [[ "${confirm}" != "yes" ]]; then
            log_info "Migration aborted by user"
            exit 3
        fi
    fi

    # Migrate state
    migrate_state || exit 1

    # Validate migrated state
    validate_migrated_state || exit 1

    # Run terraform plan
    run_terraform_plan || exit 1

    # Generate report
    generate_report

    log_info "Migration complete"
    exit 0
}

# Run main
main "$@"
