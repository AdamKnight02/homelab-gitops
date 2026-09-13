-- Cryptographic Inventory Database Schema
-- PostgreSQL

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Certificates table
CREATE TABLE IF NOT EXISTS certificates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    hostname VARCHAR(255),
    application VARCHAR(255),
    service VARCHAR(255),
    environment VARCHAR(100),
    owner VARCHAR(255),
    
    certificate_subject TEXT NOT NULL,
    subject_alternative_names TEXT[],
    serial_number VARCHAR(255) NOT NULL UNIQUE,
    issuer TEXT NOT NULL,
    issuing_ca VARCHAR(255),
    
    key_algorithm VARCHAR(50),
    key_size INTEGER,
    signature_algorithm VARCHAR(100),
    
    not_before TIMESTAMP WITH TIME ZONE NOT NULL,
    not_after TIMESTAMP WITH TIME ZONE NOT NULL,
    days_remaining INTEGER GENERATED ALWAYS AS (
        EXTRACT(DAY FROM (not_after - CURRENT_TIMESTAMP))
    ) STORED,
    
    status VARCHAR(50) DEFAULT 'unknown',
    revocation_status VARCHAR(50),
    revocation_date TIMESTAMP WITH TIME ZONE,
    revocation_reason VARCHAR(255),
    
    source_ca VARCHAR(100),
    certificate_profile VARCHAR(255),
    discovery_method VARCHAR(255),
    last_seen TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    pqc_readiness VARCHAR(50) DEFAULT 'unknown',
    crypto_policy_compliant BOOLEAN,
    
    pem_certificate TEXT,
    metadata JSONB DEFAULT '{}',
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_cert_hostname ON certificates(hostname);
CREATE INDEX IF NOT EXISTS idx_cert_application ON certificates(application);
CREATE INDEX IF NOT EXISTS idx_cert_environment ON certificates(environment);
CREATE INDEX IF NOT EXISTS idx_cert_owner ON certificates(owner);
CREATE INDEX IF NOT EXISTS idx_cert_status ON certificates(status);
CREATE INDEX IF NOT EXISTS idx_cert_source_ca ON certificates(source_ca);
CREATE INDEX IF NOT EXISTS idx_cert_not_after ON certificates(not_after);
CREATE INDEX IF NOT EXISTS idx_cert_days_remaining ON certificates(days_remaining);
CREATE INDEX IF NOT EXISTS idx_cert_key_algorithm ON certificates(key_algorithm);
CREATE INDEX IF NOT EXISTS idx_cert_key_size ON certificates(key_size);
CREATE INDEX IF NOT EXISTS idx_cert_signature_algorithm ON certificates(signature_algorithm);
CREATE INDEX IF NOT EXISTS idx_cert_pqc_readiness ON certificates(pqc_readiness);
CREATE INDEX IF NOT EXISTS idx_cert_serial_number ON certificates(serial_number);
CREATE INDEX IF NOT EXISTS idx_cert_last_seen ON certificates(last_seen);

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_cert_env_status ON certificates(environment, status);
CREATE INDEX IF NOT EXISTS idx_cert_source_profile ON certificates(source_ca, certificate_profile);
CREATE INDEX IF NOT EXISTS idx_cert_expiring ON certificates(not_after) WHERE status = 'active';

-- Discovery jobs table
CREATE TABLE IF NOT EXISTS discovery_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    source VARCHAR(100) NOT NULL,
    enabled BOOLEAN DEFAULT TRUE,
    schedule VARCHAR(100) DEFAULT '0 */6 * * *',
    config JSONB DEFAULT '{}',
    last_run TIMESTAMP WITH TIME ZONE,
    last_status VARCHAR(50),
    last_error TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Discovery runs log
CREATE TABLE IF NOT EXISTS discovery_runs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID REFERENCES discovery_jobs(id),
    started_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(50),
    certificates_found INTEGER DEFAULT 0,
    certificates_added INTEGER DEFAULT 0,
    certificates_updated INTEGER DEFAULT 0,
    errors TEXT,
    metadata JSONB DEFAULT '{}'
);

-- Audit log for certificate changes
CREATE TABLE IF NOT EXISTS certificate_audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    certificate_id UUID REFERENCES certificates(id),
    action VARCHAR(100) NOT NULL,
    old_values JSONB,
    new_values JSONB,
    performed_by VARCHAR(255),
    performed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Views for common queries

-- Certificates expiring in 30 days
CREATE OR REPLACE VIEW v_certificates_expiring_30_days AS
SELECT * FROM certificates
WHERE status = 'active'
  AND not_after <= CURRENT_TIMESTAMP + INTERVAL '30 days'
ORDER BY not_after ASC;

-- RSA certificates under 2048 bits
CREATE OR REPLACE VIEW v_weak_rsa_keys AS
SELECT * FROM certificates
WHERE key_algorithm = 'RSA'
  AND (key_size IS NULL OR key_size < 2048)
ORDER BY key_size ASC;

-- Certificates with deprecated signature algorithms
CREATE OR REPLACE VIEW v_deprecated_signatures AS
SELECT * FROM certificates
WHERE signature_algorithm IN (
    'sha1WithRSAEncryption',
    'md5WithRSAEncryption'
)
ORDER BY not_after DESC;

-- Production certificates expiring soon
CREATE OR REPLACE VIEW v_prod_expiring_soon AS
SELECT * FROM certificates
WHERE environment = 'production'
  AND status = 'active'
  AND not_after <= CURRENT_TIMESTAMP + INTERVAL '30 days'
ORDER BY not_after ASC;

-- Certificates not observed recently (7 days)
CREATE OR REPLACE VIEW v_stale_certificates AS
SELECT * FROM certificates
WHERE last_seen < CURRENT_TIMESTAMP - INTERVAL '7 days'
  AND status = 'active'
ORDER BY last_seen ASC;

-- PQC vulnerable certificates (RSA/DSA under 3072 bits, ECDSA under P-384)
CREATE OR REPLACE VIEW v_pqc_vulnerable AS
SELECT * FROM certificates
WHERE (
    (key_algorithm = 'RSA' AND key_size < 3072)
    OR (key_algorithm = 'DSA')
    OR (key_algorithm = 'ECDSA' AND key_size < 384)
)
AND status = 'active'
ORDER BY not_after ASC;

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at
CREATE TRIGGER update_certificates_updated_at
    BEFORE UPDATE ON certificates
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_discovery_jobs_updated_at
    BEFORE UPDATE ON discovery_jobs
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
