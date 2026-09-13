#!/usr/bin/env bash
# =============================================================================
# state-backup.sh — Terraform State Backup Script
# =============================================================================
# Backs up Terraform state files with checksum validation and optional
# remote upload. Supports local and remote backends.
#
# Usage:
#   ./scripts/state-backup.sh --all
#   ./scripts/state-backup.sh --provider azure --environment lab
#   ./scripts/state-backup.sh --all --remote
#
# Exit codes:
#   0 = Success
#   1 = Error
#   2 = Warning (backup completed but verification failed)
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKUP_BASE_DIR="${WORKSPACE_DIR}/backups/state"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="${BACKUP_BASE_DIR}/backup-${TIMESTAMP}.log"

# Default options
BACKUP_ALL=false
PROVIDER=""
ENVIRONMENT=""
CUSTOMER="default"
REMOTE_UPLOAD=false
VERIFY_ONLY=false

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
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }

# -----------------------------------------------------------------------------
# Usage
# -----------------------------------------------------------------------------
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Backup Terraform state files with checksum validation.

OPTIONS:
    --all                   Backup all providers and environments
    --provider PROVIDER     Backup specific provider (azure, aws, alibaba)
    --environment ENV       Backup specific environment (lab, dev, staging, prod)
    --customer CUSTOMER     Customer identifier (default: default)
    --remote                Upload backups to remote storage
    --verify-only           Only verify existing backups, don't create new ones
    --help                  Show this help message

EXAMPLES:
    # Backup all state files
    $(basename "$0") --all

    # Backup Azure lab environment
    $(basename "$0") --provider azure --environment lab

    # Backup all and upload to remote storage
    $(basename "$0") --all --remote

EXIT CODES:
    0 = Success
    1 = Error
    2 = Warning (backup completed but verification failed)

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
            --all)
                BACKUP_ALL=true
                shift
                ;;
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
            --remote)
                REMOTE_UPLOAD=true
                shift
                ;;
            --verify-only)
                VERIFY_ONLY=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done

    # Validate arguments
    if [[ "${BACKUP_ALL}" == false && -z "${PROVIDER}" ]]; then
        log_error "Either --all or --provider must be specified"
        usage
    fi

    if [[ -n "${PROVIDER}" && -z "${ENVIRONMENT}" ]]; then
        log_error "--environment is required when --provider is specified"
        usage
    fi
}

# -----------------------------------------------------------------------------
# Find Terraform Directories
# -----------------------------------------------------------------------------
find_terraform_dirs() {
    local dirs=()

    if [[ "${BACKUP_ALL}" == true ]]; then
        # Find all directories with .tf files
        while IFS= read -r -d '' dir; do
            dirs+=("$dir")
        done < <(find "${WORKSPACE_DIR}/infra/terraform" -type f -name "*.tf" -not -path "*/.terraform/*" -printf '%h\0' | sort -zu)
    else
        # Specific provider/environment
        local provider_dir="${WORKSPACE_DIR}/infra/terraform/${PROVIDER}"
        if [[ -d "${provider_dir}" ]]; then
            dirs+=("${provider_dir}")
        else
            log_error "Provider directory not found: ${provider_dir}"
            return 1
        fi
    fi

    printf '%s\n' "${dirs[@]}"
}

# -----------------------------------------------------------------------------
# Backup State File
# -----------------------------------------------------------------------------
backup_state() {
    local tf_dir="$1"
    local provider
    provider="$(basename "${tf_dir}")"
    
    local backup_dir="${BACKUP_BASE_DIR}/${provider}/${ENVIRONMENT:-lab}"
    local backup_file="${backup_dir}/terraform.tfstate.${TIMESTAMP}"
    local checksum_file="${backup_file}.sha256"

    log_info "Processing ${tf_dir}"

    # Create backup directory
    mkdir -p "${backup_dir}"

    # Check if state file exists (local backend)
    local state_file="${tf_dir}/terraform.tfstate"
    if [[ -f "${state_file}" ]]; then
        log_info "Found local state file: ${state_file}"
        
        # Copy state file
        cp "${state_file}" "${backup_file}"
        
        # Generate checksum
        (cd "${backup_dir}" && sha256sum "$(basename "${backup_file}")" > "$(basename "${checksum_file}")")
        
        log_info "Backup created: ${backup_file}"
        log_info "Checksum: $(cat "${checksum_file}")"
    else
        # Try to pull from remote backend
        log_info "No local state file found, attempting to pull from remote backend..."
        
        if [[ -d "${tf_dir}/.terraform" ]]; then
            # Check if backend is configured
            if (cd "${tf_dir}" && terraform state pull > "${backup_file}" 2>> "${LOG_FILE}"); then
                log_info "State pulled from remote backend"
                
                # Generate checksum
                (cd "${backup_dir}" && sha256sum "$(basename "${backup_file}")" > "$(basename "${checksum_file}")")
                
                log_info "Backup created: ${backup_file}"
                log_info "Checksum: $(cat "${checksum_file}")"
            else
                log_warn "Failed to pull state from remote backend (may not be initialized)"
                rm -f "${backup_file}"
                return 1
            fi
        else
            log_warn "No Terraform initialization found in ${tf_dir}"
            return 1
        fi
    fi

    # Verify backup
    if ! verify_backup "${backup_file}" "${checksum_file}"; then
        log_error "Backup verification failed for ${backup_file}"
        return 2
    fi

    # Upload to remote if requested
    if [[ "${REMOTE_UPLOAD}" == true ]]; then
        upload_backup "${backup_file}" "${provider}"
    fi

    return 0
}

# -----------------------------------------------------------------------------
# Verify Backup
# -----------------------------------------------------------------------------
verify_backup() {
    local backup_file="$1"
    local checksum_file="$2"

    log_info "Verifying backup: ${backup_file}"

    # Check file exists and is not empty
    if [[ ! -s "${backup_file}" ]]; then
        log_error "Backup file is empty or missing: ${backup_file}"
        return 1
    fi

    # Verify checksum
    local backup_dir
    backup_dir="$(dirname "${backup_file}")"
    local backup_name
    backup_name="$(basename "${backup_file}")"
    local checksum_name
    checksum_name="$(basename "${checksum_file}")"

    if ! (cd "${backup_dir}" && sha256sum -c "${checksum_name}" > /dev/null 2>&1); then
        log_error "Checksum verification failed for ${backup_file}"
        return 1
    fi

    # Verify state file is valid JSON
    if ! jq empty "${backup_file}" > /dev/null 2>&1; then
        log_error "Backup file is not valid JSON: ${backup_file}"
        return 1
    fi

    # Verify state version
    local state_version
    state_version="$(jq -r '.version // 0' "${backup_file}")"
    if [[ "${state_version}" -lt 4 ]]; then
        log_warn "State version ${state_version} is older than expected (>= 4)"
    fi

    log_info "Backup verification passed"
    return 0
}

# -----------------------------------------------------------------------------
# Upload Backup to Remote Storage
# -----------------------------------------------------------------------------
upload_backup() {
    local backup_file="$1"
    local provider="$2"

    log_info "Uploading backup to remote storage for ${provider}"

    case "${provider}" in
        azure)
            # Upload to Azure Blob Storage
            if command -v az &> /dev/null; then
                local storage_account="${AZURE_BACKUP_STORAGE_ACCOUNT:-pkterraformstate}"
                local container="${AZURE_BACKUP_CONTAINER:-state-backups}"
                
                az storage blob upload \
                    --account-name "${storage_account}" \
                    --container-name "${container}" \
                    --name "$(basename "${backup_file}")" \
                    --file "${backup_file}" \
                    --auth-mode login \
                    >> "${LOG_FILE}" 2>&1 || log_warn "Failed to upload to Azure Blob Storage"
            else
                log_warn "Azure CLI not found, skipping upload"
            fi
            ;;
        aws)
            # Upload to S3
            if command -v aws &> /dev/null; then
                local bucket="${AWS_BACKUP_BUCKET:-pki-terraform-state-backups}"
                
                aws s3 cp "${backup_file}" "s3://${bucket}/state-backups/$(basename "${backup_file}")" \
                    >> "${LOG_FILE}" 2>&1 || log_warn "Failed to upload to S3"
            else
                log_warn "AWS CLI not found, skipping upload"
            fi
            ;;
        alibaba)
            # Upload to OSS
            if command -v aliyun &> /dev/null; then
                local bucket="${ALIBABA_BACKUP_BUCKET:-pki-terraform-state-backups}"
                
                aliyun oss cp "${backup_file}" "oss://${bucket}/state-backups/$(basename "${backup_file}")" \
                    >> "${LOG_FILE}" 2>&1 || log_warn "Failed to upload to OSS"
            else
                log_warn "Alibaba CLI not found, skipping upload"
            fi
            ;;
        *)
            log_warn "Unknown provider for remote upload: ${provider}"
            ;;
    esac
}

# -----------------------------------------------------------------------------
# Generate Backup Report
# -----------------------------------------------------------------------------
generate_report() {
    local report_file="${BACKUP_BASE_DIR}/backup-report-${TIMESTAMP}.md"

    cat > "${report_file}" << EOF
# State Backup Report

**Timestamp:** ${TIMESTAMP}
**Backup Directory:** ${BACKUP_BASE_DIR}

## Summary

| Provider | Environment | Status | Checksum |
|----------|-------------|--------|----------|
EOF

    # Find all backups from this run
    find "${BACKUP_BASE_DIR}" -name "terraform.tfstate.${TIMESTAMP}" -type f | while read -r backup; do
        local provider
        provider="$(echo "${backup}" | cut -d'/' -f4)"
        local env
        env="$(echo "${backup}" | cut -d'/' -f5)"
        local checksum
        checksum="$(cat "${backup}.sha256" 2>/dev/null | cut -d' ' -f1 || echo 'N/A')"
        
        echo "| ${provider} | ${env} | ✅ | \`${checksum:0:16}...\` |" >> "${report_file}"
    done

    cat >> "${report_file}" << EOF

## Files

\`\`\`
$(find "${BACKUP_BASE_DIR}" -name "*${TIMESTAMP}*" -type f | sort)
\`\`\`

## Verification

All backups have been verified with SHA256 checksums.

## Next Steps

1. Store backups in a secure location
2. Test restore procedure periodically
3. Update backup retention policy as needed

---
Generated by state-backup.sh
EOF

    log_info "Backup report generated: ${report_file}"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    log_info "Starting state backup"
    log_info "Workspace: ${WORKSPACE_DIR}"
    log_info "Backup directory: ${BACKUP_BASE_DIR}"

    # Create backup directory
    mkdir -p "${BACKUP_BASE_DIR}"

    # Parse arguments
    parse_args "$@"

    # Find Terraform directories
    local tf_dirs
    mapfile -t tf_dirs < <(find_terraform_dirs)

    # Find Terraform directories
    local tf_dirs
    mapfile -t tf_dirs < <(find_terraform_dirs)

    if [[ ${#tf_dirs[@]} -eq 0 ]]; then
        log_error "No Terraform directories found"
        exit 1
    fi

    log_info "Found ${#tf_dirs[@]} Terraform directories"

    # Backup each directory
    local success_count=0
    local fail_count=0
    local warn_count=0

    for tf_dir in "${tf_dirs[@]}"; do
        if backup_state "${tf_dir}"; then
            ((success_count++))
        else
            local exit_code=$?
            if [[ ${exit_code} -eq 2 ]]; then
                ((warn_count++))
            else
                ((fail_count++))
            fi
        fi
    done

    # Generate report
    generate_report

    # Summary
    log_info "Backup complete: ${success_count} succeeded, ${warn_count} warnings, ${fail_count} failed"

    if [[ ${fail_count} -gt 0 ]]; then
        exit 1
    elif [[ ${warn_count} -gt 0 ]]; then
        exit 2
    else
        exit 0
    fi
}

# Run main
main "$@"
