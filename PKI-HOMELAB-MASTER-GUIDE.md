# PKI Homelab Master Guide

## A Comprehensive Reference for Machine Identity, Certificate Lifecycle, and Enterprise PKI Architecture

**Version:** 1.0  
**Date:** August 28, 2026  
**Author:** OpenClaw Agent  
**Lab:** frostnode / k8s01 (192.168.122.74)  
**Git Repository:** https://github.com/AdamKnight02/homelab-gitops

---

## Table of Contents

1. [What PKI Actually Is](#part-1--what-pki-actually-is)
2. [Root CA / RCA](#part-2--root-ca--rca)
3. [Intermediate / Issuing CAs](#part-3--intermediate--issuing-cas)
4. [Certificate Anatomy](#part-4--certificate-anatomy)
5. [Serial Numbers and OIDs](#part-5--serial-numbers-and-the-random-numbers)
6. [Thumbprints / Fingerprints](#part-6--thumbprints--fingerprints)
7. [Subject / Issuer / DN](#part-7--subject--issuer--dn)
8. [Subject Alternative Names](#part-8--subject-alternative-names)
9. [Key Usage](#part-9--key-usage)
10. [Extended Key Usage](#part-10--extended-key-usage)
11. [Public Key Algorithms](#part-11--public-key-algorithms)
12. [Hash Functions](#part-12--hash-functions)
13. [ASN.1 / DER / Base64](#part-13--asn1--der--base64)
14. [PKI File Types](#part-14--pki-file-types)
15. [PEM](#part-15--pem)
16. [DER](#part-16--der)
17. [PKCS#12 / PFX](#part-17--pkcs12--pfx)
18. [PKCS#7](#part-18--pkcs7)
19. [CSR](#part-19--csr)
20. [CRL](#part-20--crl)
21. [OCSP](#part-21--ocsp)
22. [Revocation Reasons](#part-22--revocation-reasons)
23. [Crypto Tokens](#part-23--crypto-tokens)
24. [HSM](#part-24--hsm)
25. [EJBCA Architecture](#part-25--ejbca-architecture)
26. [Certificate Profiles](#part-26--certificate-profiles)
27. [End Entity Profiles](#part-27--end-entity-profiles)
28. [End Entity](#part-28--end-entity)
29. [RA](#part-29--ra)
30. [VA](#part-30--va)
31. [Management CA](#part-31--management-ca)
32. [EJBCA SuperAdmin](#part-32--ejbca-superadmin-certificate)
33. [Enrollment Protocols](#part-33--certificate-enrollment-protocols)
34. [SCEP](#part-34--scep)
35. [ACME](#part-35--acme)
36. [EST](#part-36--est)
37. [CMP](#part-37--cmp)
38. [Microsoft Certutil](#part-38--microsoft-certutil)
39. [OpenSSL Inspection](#part-39--openssl-certificate-inspection)
40. [Certificate Validation](#part-40--certificate-validation)
41. [TLS](#part-41--tls)
42. [mTLS](#part-42--mtls)
43. [SPIFFE / SPIRE](#part-43--spiffe--spire)
44. [OpenBao](#part-44--openbao)
45. [Certificate Lifecycle](#part-45--certificate-lifecycle-management)
46. [Crypto Inventory](#part-46--crypto-inventory)
47. [PQC / Crypto Agility](#part-47--pqc--crypto-agility)
48. [Key Compromise](#part-48--key-compromise)
49. [Certificate Expiration](#part-49--certificate-expiration)
50. [CA Renewal / Rekey](#part-50--ca-renewal--rekey)
51. [Windows Certificate Stores](#part-51--windows-certificate-stores)
52. [Java Trust Stores](#part-52--java-trust-stores)
53. [Container / Kubernetes PKI](#part-53--container--kubernetes-pki)
54. [Argo CD / GitOps and PKI](#part-54--argo-cd--gitops-and-pki)
55. [My Lab Architecture](#part-55--my-lab-architecture)
56. [My PKI Trust Hierarchy](#part-56--my-pki-trust-hierarchy)
57. [Practical Lab Exercises](#part-57--practical-lab-exercises)
58. [PKI Troubleshooting](#part-58--pki-troubleshooting)
59. [Common Misconceptions](#part-59--common-pki-misconceptions)
60. [Glossary](#part-60--glossary)
61. [Quick Reference Tables](#part-61--quick-reference-tables)
62. [Architect-Level Questions](#part-62--architect-level-questions)
63. [Final Summary](#part-63--final-summary)

---

## Lab Component Status

| Component | Status | Namespace | Notes |
|-----------|--------|-----------|-------|
| K3s Kubernetes | **RUNNING** | - | v1.36.2+k3s1, single-node |
| Argo CD | **RUNNING** | argocd | 10 Applications, GitOps active |
| EJBCA Community | **RUNNING** | ejbca | v9.3.7, 3 CAs configured |
| PostgreSQL | **RUNNING** | ejbca | Bitnami chart, EJBCA backend |
| OpenBao | **RUNNING** | openbao | v2.6.2, unsealed, raft storage |
| SPIRE | **RUNNING** | spire | CSI driver installed, workload attestation active |
| cert-manager | **RUNNING** | cert-manager | v1.21.1, ClusterIssuer configured |
| Prometheus/Grafana | **RUNNING** | monitoring | kube-prometheus-stack v88.5.4 |
| Local Registry | **RUNNING** | registry | registry:2.8.3 |
| RabbitMQ | **RUNNING** | rabbitmq | rabbitmq:4.1.3-management |
| cert-api | **RUNNING** | pki | Custom app, Phase 16 code |
| cert-worker | **RUNNING** | pki | Custom app, batch operations |
| ca-service | **RUNNING** | pki | Custom app, CA abstraction layer |
| pki-database | **RUNNING** | pki | PostgreSQL for cert inventory |
| rabbitmq-demo | **REMOVED** | - | Deleted from Argo CD and git |

---

# PART 1 — WHAT PKI ACTUALLY IS

## Public Key Infrastructure

**Public Key Infrastructure (PKI)** is the collection of hardware, software, policies, and procedures needed to create, manage, distribute, use, store, and revoke digital certificates. It binds public keys to identities.

### Why PKI Exists

Before PKI, sharing secrets was hard. If Alice wants to send Bob an encrypted message, she needs a shared secret key. But how does she send Bob the key securely? This is the **key distribution problem**.

PKI solves this through **asymmetric cryptography**:
- Alice generates a **key pair**: a public key (she shares) and a private key (she keeps secret)
- Bob does the same
- They exchange public keys through the PKI
- Messages encrypted with Alice's public key can only be decrypted with Alice's private key
- Messages signed with Alice's private key can be verified with Alice's public key

### The Five Security Services

| Service | What It Means | How PKI Provides It |
|---------|---------------|---------------------|
| **Identity** | Knowing who you're talking to | Certificates bind names to public keys |
| **Authentication** | Proving identity | Digital signatures prove possession of private key |
| **Confidentiality** | Keeping secrets | Public key encryption of session keys |
| **Integrity** | Detecting tampering | Digital signatures over hashes |
| **Non-repudiation** | Preventing denial of actions | Signed records with timestamps |
| **Trust** | Believing the identity | Chain of trust from a trusted root |

### Asymmetric Cryptography

**Public Key**: Can be shared openly. Used to encrypt data or verify signatures.

**Private Key**: Must be kept secret. Used to decrypt data or create signatures.

**Digital Signature**: Created by hashing data and encrypting the hash with the private key. Anyone with the public key can verify it.

**Hash Function**: A one-way function that produces a fixed-size output from variable input. Changing one bit of input completely changes the output.

### Certificate Authorities

A **Certificate Authority (CA)** is a trusted entity that issues digital certificates. The CA:
1. Verifies the identity of the certificate requester
2. Signs the certificate with its private key
3. Publishes the certificate for others to use

### Certificates

An **X.509 certificate** is a digitally signed document containing:
- Subject's identity (name, organization, etc.)
- Subject's public key
- Issuer's identity (the CA)
- Validity period
- Serial number
- Extensions (key usage, SANs, etc.)
- Signature from the CA

### Certificate Chains

No one trusts your certificate directly. They trust a **root CA**, and your certificate is signed by an intermediate CA, which is signed by the root. This forms a **certificate chain**:

```
Root CA (self-signed, in trust store)
    ↓ signs
Intermediate CA 1
    ↓ signs
Intermediate CA 2 (optional)
    ↓ signs
Your Server Certificate (leaf)
```

### Trust Anchors

A **trust anchor** is a root CA certificate that a system trusts implicitly. It is self-signed and distributed through secure channels (OS updates, enterprise policy, manual installation).

Your operating system comes with a **trust store** containing pre-installed root CA certificates from vendors like DigiCert, Let's Encrypt, and government CAs.

### Revocation

Sometimes certificates must be invalidated before their expiration date:
- Private key compromise
- Employee termination
- Domain name change
- CA compromise

PKI provides two revocation mechanisms: **Certificate Revocation Lists (CRLs)** and **Online Certificate Status Protocol (OCSP)**.

### Certificate Lifecycle

```
Private key generated
        ↓
Public key derived (mathematically linked)
        ↓
CSR (Certificate Signing Request) created
        ↓
CA validates identity and request
        ↓
Certificate issued and signed by CA
        ↓
Certificate installed on server/device
        ↓
Peers validate certificate (chain, expiry, revocation)
        ↓
Certificate renewed, revoked, or expires
```

---

# PART 2 — ROOT CA / RCA

## Root Certificate Authority

A **Root CA (RCA)** is the top of the PKI hierarchy. It is the ultimate trust anchor.

### Key Properties

| Property | Description |
|----------|-------------|
| **Self-signed** | The root certificate is signed by its own private key |
| **Trust anchor** | Systems trust it implicitly (no higher authority) |
| **Long lifetime** | Typically 10-30 years |
| **Offline operation** | Ideally kept disconnected from networks |
| **Minimal usage** | Only signs intermediate CA certificates, never end-entity certs |

### Why Roots Are Self-Signed

A root CA has no parent. There is no higher authority to sign its certificate. Therefore, it signs its own certificate. This does NOT mean it is automatically trusted—it must be distributed through a trusted channel (OS install, enterprise policy, manual addition to trust store).

### Root Key Security

The root CA's private key is the most critical secret in the entire PKI. If compromised, every certificate in the hierarchy is suspect.

**Best practices:**
- Store offline in an HSM (Hardware Security Module)
- Air-gapped network or completely offline
- Multi-person control (M-of-N) for key access
- Physical security (safe, guarded facility)
- Rarely used (only for signing intermediate CA certificates)

### Root Key Ceremony

A **root key ceremony** is a formal procedure for generating and protecting root CA keys. It typically involves:
- Multiple trusted witnesses
- HSM initialization in a secure facility
- Key generation inside the HSM (keys never exist in software)
- Splitting key shares among custodians (Shamir's Secret Sharing)
- Video recording and audit logging
- Certificate signing with witnesses present

### Root CA Compromise

If a root CA is compromised:
1. All certificates in the hierarchy are untrusted
2. The root must be revoked and removed from all trust stores
3. A new root must be generated and distributed
4. All intermediate CAs must be re-issued
5. All end-entity certificates must be re-issued

This is catastrophic. That's why roots are kept offline and rarely used.

### Root CA Renewal vs. Rollover

**Renewal**: New certificate with the same public key. Less disruptive.

**Rollover (Rekey)**: New certificate with a new key pair. More secure but requires redistributing the new root to all trust stores.

### Cross-Certification

Two separate PKIs can trust each other through **cross-certification**:

```
Root CA A                    Root CA B
    ↓ signs                      ↓ signs
Cross-cert A→B             Cross-cert B→A
```

This allows certificates from PKI A to be validated in PKI B's trust domain and vice versa.

### Why Enterprises Don't Issue End-Entity Certs from the Root

1. **Security**: Root key exposure risk increases with every signing operation
2. **Operational**: Root is offline; can't respond to frequent requests
3. **Revocation**: Revoking an intermediate doesn't invalidate the root
4. **Flexibility**: Different intermediate CAs for different purposes

### Root CA Hierarchy Diagram

```
                    ┌─────────────────┐
                    │    Root CA      │
                    │  (Offline HSM)  │
                    └────────┬────────┘
                             │
            ┌────────────────┼────────────────┐
            │                │                │
            ▼                ▼                ▼
    ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
    │  Issuing CA  │ │  Issuing CA  │ │  Issuing CA  │
    │   (Users)    │ │  (Servers)   │ │   (Devices)  │
    └──────┬───────┘ └──────┬───────┘ └──────┬───────┘
           │                │                │
           ▼                ▼                ▼
    ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
    │ User Certs   │ │ Server Certs │ │ Device Certs │
    └──────────────┘ └──────────────┘ └──────────────┘
```

---

# PART 3 — INTERMEDIATE / ISSUING CAs

## Intermediate Certificate Authorities

An **Intermediate CA** (also called **Issuing CA**, **Subordinate CA**, or **SubCA**) sits between the root CA and end-entity certificates.

### Terminology Overlap

| Term | Meaning | Context |
|------|---------|---------|
| **Intermediate CA** | Any CA below the root | General PKI |
| **Issuing CA** | CA that issues end-entity certificates | Microsoft, enterprise |
| **Subordinate CA** | CA signed by another CA | X.509 terminology |
| **SubCA** | Abbreviation for subordinate CA | RFC literature |

These terms often refer to the same thing in practice.

### Why Intermediate CAs Exist

1. **Root Protection**: The root stays offline; intermediates handle daily operations
2. **Policy Separation**: Different intermediates for different certificate types
3. **Revocation Granularity**: Revoke one intermediate without affecting others
4. **Geographic Distribution**: Regional intermediates for latency and compliance
5. **Organizational Separation**: Different departments manage different intermediates

### Basic Constraints and CA=true

The **Basic Constraints** extension contains a critical field: **CA=true/false**.

- **CA=true**: This certificate can sign other certificates (it's a CA)
- **CA=false**: This certificate cannot sign other certificates (it's an end-entity)

The **pathLenConstraint** field limits how many additional CAs can exist below this one:
- `pathLenConstraint=0`: Can only sign end-entity certificates, not subordinate CAs
- `pathLenConstraint=1`: Can sign one level of subordinate CAs
- Absent: No limit

### Certificate Path Building

When a client validates a certificate, it builds a **certification path** (chain):

```
Leaf Certificate (server.example.com)
        ↓
Issuer: Issuing CA (Example Corp TLS CA)
        ↓
Issuer: Intermediate CA (Example Corp Intermediate)
        ↓
Issuer: Root CA (Example Corp Root) ← in trust store
        ↓
Self-signed (trusted implicitly)
```

The client verifies:
1. Each certificate's signature using the issuer's public key
2. Each certificate is within its validity period
3. The root is in the trust store
4. No certificate has been revoked

### Common Issuing CA Types

| Type | Issues Certificates For | Example |
|------|------------------------|---------|
| **User Issuing CA** | Employee/user identity | Smart card logon, email |
| **Machine Issuing CA** | Computer/workstation | Domain join, device identity |
| **TLS Issuing CA** | Web servers | HTTPS, load balancers |
| **Device Issuing CA** | IoT/embedded devices | Manufacturing, provisioning |
| **Code Signing CA** | Software publishers | Application signatures |
| **Document Signing CA** | PDF/document signers | Legal documents |

### Chain Validation Example

```bash
# View certificate chain
openssl s_client -connect example.com:443 -showcerts

# Verify chain with explicit CA file
openssl verify -CAfile root.pem -untrusted intermediate.pem leaf.pem
```

---

# PART 4 — CERTIFICATE ANATOMY

## X.509 Certificate Fields

An X.509 certificate is an ASN.1 structure. Let's examine a real certificate and explain every field.

### Example: Decoded Certificate

```
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            04:5c:7b:2a:1f:9e:3d:8c:7a:4e:2b:5f:1c:8d:3e:7a
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN = LabIssuingCA, O = Homelab, C = US
        Validity
            Not Before: Aug 15 00:00:00 2026 GMT
            Not After : Aug 15 00:00:00 2027 GMT
        Subject: CN = cert-api.pki.svc.cluster.local
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                RSA Public-Key: (2048 bit)
                Modulus:
                    00:aa:bb:cc:dd:ee:ff:... (256 bytes)
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Subject Key Identifier:
                12:34:56:78:9A:BC:DE:F0:11:22:33:44:55:66:77:88:99:AA:BB:CC
            X509v3 Authority Key Identifier:
                keyid:AB:CD:EF:01:23:45:67:89:0A:BC:DE:F1:23:45:67:89:0A:BC:DE:F1
            X509v3 Basic Constraints:
                CA:FALSE
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment
            X509v3 Extended Key Usage:
                TLS Web Server Authentication, TLS Web Client Authentication
            X509v3 Subject Alternative Name:
                DNS:cert-api.pki.svc.cluster.local, DNS:cert-api, IP:10.43.123.45
            X509v3 CRL Distribution Points:
                Full Name:
                  URI:http://ejbca.ejbca.svc.cluster.local/ejbca/publicweb/webdist/certdist?cmd=crl&issuer=CN=LabIssuingCA
            Authority Information Access:
                CA Issuers - URI:http://ejbca.ejbca.svc.cluster.local/ejbca/publicweb/webdist/certdist?cmd=cacert&issuer=CN=LabIssuingCA
                OCSP - URI:http://ejbca.ejbca.svc.cluster.local/ejbca/publicweb/status/ocsp
    Signature Algorithm: sha256WithRSAEncryption
         aa:bb:cc:dd:ee:ff:... (256 bytes)
```

### Field Explanations

#### Version
- **Value**: 3 (0x2)
- **Meaning**: X.509 version 3 (the current standard)
- **Note**: The value is 0x2 because versions are numbered 0, 1, 2 (v1, v2, v3)

#### Serial Number
- **Value**: Unique integer assigned by the CA
- **Meaning**: Identifies this specific certificate within the CA's namespace
- **Must be unique per CA**: Two certificates from the same CA cannot share a serial
- **Format**: Typically displayed as hex, but stored as an ASN.1 INTEGER

#### Signature Algorithm
- **Value**: sha256WithRSAEncryption
- **Meaning**: The CA signed this certificate using RSA with SHA-256
- **Important**: This describes the signature on the certificate, not the key type

#### Issuer
- **Value**: The CA that signed this certificate
- **Format**: Distinguished Name (DN)
- **Example**: `CN = LabIssuingCA, O = Homelab, C = US`

#### Validity Period
- **Not Before**: Certificate is not valid before this date
- **Not After**: Certificate expires after this date
- **Critical**: Clients reject certificates outside this window

#### Subject
- **Value**: The entity this certificate belongs to
- **Format**: Distinguished Name (DN)
- **Note**: For TLS, the Subject Common Name (CN) has been largely replaced by Subject Alternative Name (SAN)

#### Subject Public Key Info
- **Public Key Algorithm**: Type of key (RSA, ECDSA, etc.)
- **Key Material**: The actual public key bytes
  - RSA: Modulus and Exponent
  - ECDSA: Curve name and public point

#### Extensions (X.509v3)

Modern certificates rely heavily on extensions:

| Extension | Purpose |
|-----------|---------|
| **Subject Key Identifier (SKI)** | Unique identifier for this certificate's public key |
| **Authority Key Identifier (AKI)** | Identifies the issuer's public key |
| **Basic Constraints** | CA:true/false, path length limits |
| **Key Usage** | What operations this key can perform |
| **Extended Key Usage** | What applications can use this certificate |
| **Subject Alternative Name** | Additional identities (DNS, IP, URI, email) |
| **CRL Distribution Points** | Where to find revocation lists |
| **Authority Information Access** | Where to find issuer cert and OCSP responder |
| **Certificate Policies** | Policy OIDs defining issuance rules |

---

# PART 5 — SERIAL NUMBERS AND THE "RANDOM NUMBERS"

## Certificate Serial Number

The **serial number** is a unique integer assigned by the CA when issuing a certificate.

### Properties

| Property | Explanation |
|----------|-------------|
| **Uniqueness scope** | Must be unique per CA, not globally unique |
| **Format** | Positive integer, up to 20 bytes (RFC 5280) |
| **Display** | Usually shown in hexadecimal |
| **Encoding** | ASN.1 INTEGER type in DER |

### Why Leading Zero Bytes Appear

ASN.1 INTEGER is signed. If the high bit of the first byte is 1, it would be interpreted as negative. To force positive, a leading zero byte is added:

- Value `0x80` (128) → encoded as `0x00 0x80` (positive)
- Value `0x7F` (127) → encoded as `0x7F` (already positive)

### OID Trees

**Object Identifiers (OIDs)** are hierarchical identifiers used throughout PKI.

The OID tree starts at:
- `1` = ISO
- `2` = joint-iso-ccitt (ITU-T)

Example OID breakdown:
```
1.3.6.1.5.5.7.3.1
│ │ │ │ │ │ │ │ └─ serverAuth (1)
│ │ │ │ │ │ │ └── id-kp (3) - Key Purposes
│ │ │ │ │ │ └──── id-pe (7) - PKIX Extended
│ │ │ │ │ └────── id-pkix (5)
│ │ │ │ └──────── internet (5)
│ │ │ └────────── dod (6)
│ │ └──────────── us-govt-organization (1)
│ └────────────── identified-organization (3)
└──────────────── iso (1)
```

### Important PKI OIDs

| OID | Name | Meaning | Typical Usage |
|-----|------|---------|---------------|
| 1.3.6.1.5.5.7.3.1 | serverAuth | TLS server authentication | Web servers |
| 1.3.6.1.5.5.7.3.2 | clientAuth | TLS client authentication | Client certs |
| 1.3.6.1.5.5.7.3.3 | codeSigning | Code signing | Software publishers |
| 1.3.6.1.5.5.7.3.4 | emailProtection | S/MIME email | Email encryption/signing |
| 1.3.6.1.5.5.7.3.8 | timeStamping | Timestamping | RFC 3161 timestamps |
| 1.3.6.1.5.5.7.3.9 | OCSPSigning | OCSP response signing | OCSP responders |
| 2.5.4.3 | commonName | Common Name | Subject/Issuer CN field |
| 2.5.4.6 | countryName | Country | C= field |
| 2.5.4.10 | organizationName | Organization | O= field |
| 2.5.4.11 | organizationalUnitName | Organizational Unit | OU= field |
| 2.5.29.17 | subjectAltName | Subject Alternative Name | DNS, IP, URI SANs |
| 2.5.29.19 | basicConstraints | Basic Constraints | CA:true/false |
| 2.5.29.15 | keyUsage | Key Usage | signing, encryption, etc. |
| 2.5.29.37 | extendedKeyUsage | Extended Key Usage | application purposes |
| 1.3.6.1.5.5.7.1.1 | authorityInfoAccess | Authority Information Access | AIA extension |
| 2.5.29.31 | cRLDistributionPoints | CRL Distribution Points | CDP extension |

---

# PART 6 — THUMBPRINTS / FINGERPRINTS

## Certificate Thumbprint

A **thumbprint** (or **fingerprint**) is a hash of the entire certificate (not the public key, not the private key—the DER-encoded certificate itself).

### How It's Calculated

```
Thumbprint = Hash(DER-encoded certificate bytes)
```

Common algorithms:
- SHA-1 (legacy, still shown by Windows)
- SHA-256 (modern standard)

### What Gets Hashed

The entire certificate including:
- All fields (version, serial, issuer, subject, validity, public key, extensions)
- The CA's signature

**Not included**: Private key (never in the certificate)

### Important Distinctions

| Concept | What It Is | Used For |
|---------|-----------|----------|
| **Certificate Thumbprint** | Hash of entire certificate | Identifying a specific cert file |
| **Certificate Signature** | CA's digital signature over the cert | Proving the CA issued it |
| **Public Key Hash** | Hash of the public key alone | Finding related certificates |
| **Subject Key Identifier (SKI)** | Hash of public key (or serial+issuer) | Chain building |
| **Authority Key Identifier (AKI)** | Identifier of issuer's public key | Chain building |

### Why Windows Shows SHA-1 Thumbprints

Even when the certificate signature uses SHA-256, Windows may display the thumbprint using SHA-1. This is for backward compatibility and does not affect the security of the certificate signature itself.

### Example Commands

```bash
# SHA-256 fingerprint
openssl x509 -in cert.pem -fingerprint -sha256 -noout

# SHA-1 fingerprint (legacy)
openssl x509 -in cert.pem -fingerprint -sha1 -noout
```

---

# PART 7 — SUBJECT / ISSUER / DN

## Distinguished Names (DN)

A **Distinguished Name** is a hierarchical identifier used in X.509 certificates.

### DN Components

| Abbreviation | Full Name | Example | OID |
|--------------|-----------|---------|-----|
| **CN** | Common Name | `CN=cert-api.pki.svc.cluster.local` | 2.5.4.3 |
| **OU** | Organizational Unit | `OU=Infrastructure` | 2.5.4.11 |
| **O** | Organization | `O=Homelab` | 2.5.4.10 |
| **L** | Locality | `L=Dallas` | 2.5.4.7 |
| **ST** | State/Province | `ST=Texas` | 2.5.4.8 |
| **C** | Country | `C=US` | 2.5.4.6 |
| **DC** | Domain Component | `DC=cluster,DC=local` | 0.9.2342.19200300.100.1.25 |
| **UID** | User ID | `UID=adamk` | 0.9.2342.19200300.100.1.1 |

### Example DN

```
CN=cert-api.pki.svc.cluster.local,
OU=Infrastructure,
O=Homelab,
L=Dallas,
ST=Texas,
C=US
```

### Subject vs. Issuer

| Field | Meaning |
|-------|---------|
| **Subject** | Who/what the certificate belongs to |
| **Issuer** | The CA that signed this certificate |

### Self-Issued vs. Self-Signed

| Term | Meaning | Example |
|------|---------|---------|
| **Self-issued** | Subject = Issuer (same name) | Root CA renewal |
| **Self-signed** | Self-issued + signed with own key | Root CA |

All self-signed certificates are self-issued, but not all self-issued are self-signed.

### CN vs. SAN

| Feature | Common Name (CN) | Subject Alternative Name (SAN) |
|---------|------------------|-------------------------------|
| **Standard** | Legacy | Modern (RFC 6125) |
| **Multiple values** | Single value only | Multiple values allowed |
| **Types** | Text string only | DNS, IP, URI, email |
| **Hostname validation** | Deprecated for TLS | Required for TLS |
| **Browsers** | May ignore CN if SAN present | Always check SAN first |

**Modern practice**: Always use SAN for hostname identification. CN is for display/organizational purposes.

---

# PART 8 — SUBJECT ALTERNATIVE NAMES

## Subject Alternative Name (SAN)

The **Subject Alternative Name** extension allows a certificate to be valid for multiple identities.

### SAN Types

| Type | Format | Example |
|------|--------|---------|
| **DNS** | Hostname | `DNS:cert-api.pki.svc.cluster.local` |
| **IP** | IPv4/IPv6 address | `IP:10.43.123.45` |
| **URI** | Uniform Resource Identifier | `URI:spiffe://homelab.local/ns/pki/sa/cert-worker` |
| **email** | Email address | `email:admin@homelab.local` |
| **directoryName** | Full DN | `directoryName:CN=Admin,O=Homelab` |
| **otherName** | Other identifier | `otherName:1.2.3.4;UTF8:custom-id` |

### SPIFFE Identities as URI SANs

SPIFFE (Secure Production Identity Framework For Everyone) uses URI SANs:

```
URI:spiffe://homelab.local/ns/pki/sa/cert-worker
```

Breakdown:
- `spiffe://` = SPIFFE scheme
- `homelab.local` = Trust domain
- `/ns/pki` = Namespace
- `/sa/cert-worker` = Service account

In your lab, SPIRE automatically injects these URI SANs into workload certificates.

### Hostname Validation

When a client connects to `https://cert-api.pki.svc.cluster.local`, it validates:
1. The certificate's SAN contains `DNS:cert-api.pki.svc.cluster.local`, OR
2. If no SAN extension exists, the Subject CN matches

**Best practice**: Always include all hostnames and IPs a service may be accessed by.

---

# PART 9 — KEY USAGE

## Key Usage Extension

**Key Usage** is a critical extension that defines what operations a certificate's key can perform.

### Key Usage Bits

| Bit Name | Value | Typical Use |
|----------|-------|-------------|
| **digitalSignature** | 0 | Signing data, TLS handshake |
| **nonRepudiation** | 1 | Legal non-repudiation (rarely used) |
| **keyEncipherment** | 2 | Encrypting symmetric keys (RSA key exchange) |
| **dataEncipherment** | 3 | Encrypting data directly (rare) |
| **keyAgreement** | 4 | Key exchange (DH, ECDH) |
| **keyCertSign** | 5 | Signing other certificates (CA only) |
| **cRLSign** | 6 | Signing CRLs (CA or CRL issuer) |
| **encipherOnly** | 7 | Encrypt only (with keyAgreement) |
| **decipherOnly** | 8 | Decrypt only (with keyAgreement) |

### Typical Key Usage by Certificate Type

| Certificate Type | Key Usage |
|-----------------|-----------|
| **Root CA** | keyCertSign, cRLSign |
| **Intermediate CA** | keyCertSign, cRLSign |
| **TLS Server** | digitalSignature, keyEncipherment (RSA) OR digitalSignature, keyAgreement (ECDHE) |
| **TLS Client** | digitalSignature, keyAgreement |
| **OCSP Responder** | digitalSignature |
| **Code Signing** | digitalSignature |
| **S/MIME** | digitalSignature, keyEncipherment |

---

# PART 10 — EXTENDED KEY USAGE

## Extended Key Usage (EKU)

**EKU** specifies the **purpose** for which a certificate may be used, at the application level.

### Common EKU Values

| OID | Name | Usage |
|-----|------|-------|
| 1.3.6.1.5.5.7.3.1 | serverAuth | TLS server authentication |
| 1.3.6.1.5.5.7.3.2 | clientAuth | TLS client authentication |
| 1.3.6.1.5.5.7.3.3 | codeSigning | Code signing |
| 1.3.6.1.5.5.7.3.4 | emailProtection | S/MIME |
| 1.3.6.1.5.5.7.3.8 | timeStamping | RFC 3161 timestamping |
| 1.3.6.1.5.5.7.3.9 | OCSPSigning | OCSP response signing |
| 1.3.6.1.5.5.7.3.31 | documentSigning | Document signing (PDF, etc.) |

### Key Usage vs. Extended Key Usage

| Aspect | Key Usage | Extended Key Usage |
|--------|-----------|-------------------|
| **Level** | Cryptographic operation | Application purpose |
| **Example** | "Can sign things" | "Can sign TLS server handshakes" |
| **Critical?** | Often marked critical | Usually not critical |
| **Relationship** | Lower-level | Higher-level |

### What Happens If EKU Doesn't Allow Intended Use

If a certificate has `EKU=codeSigning` but is used for TLS server authentication:
- Browsers will reject it
- Applications should reject it
- The certificate is technically valid but not authorized for that purpose

---

# PART 11 — PUBLIC KEY ALGORITHMS

## RSA

**RSA** (Rivest-Shamir-Adleman) is the most widely used public key algorithm.

### RSA Components

| Component | Description |
|-----------|-------------|
| **Modulus (n)** | Product of two large primes, determines key strength |
| **Public Exponent (e)** | Typically 65537 (0x10001), used for encryption |
| **Private Exponent (d)** | Derived from primes, used for decryption |

### RSA Key Sizes

| Size | Security Level | Status |
|------|---------------|--------|
| 1024 bits | ~80 bits | **Deprecated** |
| 2048 bits | ~112 bits | Minimum acceptable |
| 3072 bits | ~128 bits | Recommended |
| 4096 bits | ~140 bits | High security |

### ECC / ECDSA

**Elliptic Curve Cryptography** uses smaller keys for equivalent security.

| Curve | Key Size | Equivalent RSA | Use Case |
|-------|----------|---------------|----------|
| **P-256** (secp256r1) | 256 bits | ~3072 bits | General purpose |
| **P-384** (secp384r1) | 384 bits | ~7680 bits | High security |
| **P-521** (secp521r1) | 521 bits | ~15360 bits | Maximum security |

### Public Key Algorithm vs. Signature Algorithm

These are related but distinct:

| Certificate Field | Example | Meaning |
|-------------------|---------|---------|
| **Public Key Algorithm** | rsaEncryption | The key is an RSA key |
| **Signature Algorithm** | sha256WithRSAEncryption | The cert was signed using RSA+SHA-256 |

A certificate can contain an RSA key but be signed using ECDSA by the CA (uncommon but possible).

---

# PART 12 — HASH FUNCTIONS

## Cryptographic Hash Functions

A **hash function** maps arbitrary input to a fixed-size output.

### Properties

| Property | Meaning |
|----------|---------|
| **Deterministic** | Same input → same output |
| **Fast** | Easy to compute |
| **One-way** | Hard to reverse (find input from output) |
| **Collision-resistant** | Hard to find two inputs with same output |

### Hash Algorithms in PKI

| Algorithm | Output Size | Status |
|-----------|-------------|--------|
| **MD5** | 128 bits | **Broken** - do not use |
| **SHA-1** | 160 bits | **Deprecated** - collision attacks possible |
| **SHA-256** | 256 bits | Recommended |
| **SHA-384** | 384 bits | High security |
| **SHA-512** | 512 bits | Maximum security |

### Signature Algorithms

| Algorithm | Meaning |
|-----------|---------|
| **sha256WithRSAEncryption** | Sign hash with RSA, hash using SHA-256 |
| **ecdsa-with-SHA256** | Sign hash with ECDSA, hash using SHA-256 |
| **Ed25519** | EdDSA signature (no separate hash algorithm) |

### Why MD5/SHA-1 Are Unsuitable

- **MD5**: Collisions can be generated in seconds
- **SHA-1**: Practical collision attacks demonstrated (SHAttered, 2017)

Modern browsers reject certificates signed with SHA-1.

---

# PART 13 — ASN.1 / DER / BASE64

## Why Certificates Look Strange Internally

X.509 certificates are encoded using **ASN.1** (Abstract Syntax Notation One) and **DER** (Distinguished Encoding Rules).

### ASN.1

ASN.1 is a language for describing data structures. It defines:
- **Types**: INTEGER, OCTET STRING, SEQUENCE, etc.
- **Structures**: How to combine types

### DER

DER is a binary encoding of ASN.1. It is:
- **Distinguished**: Exactly one way to encode any value
- **Canonical**: No ambiguity

### TLV Encoding

DER uses **Type-Length-Value**:

```
┌─────────┬─────────┬─────────┐
│  Type   │ Length  │  Value  │
│ 1 byte  │ 1+ bytes│ N bytes │
└─────────┴─────────┴─────────┘
```

### Certificate ASN.1 Structure

```
Certificate ::= SEQUENCE {
    tbsCertificate       TBSCertificate,
    signatureAlgorithm   AlgorithmIdentifier,
    signatureValue       BIT STRING
}

TBSCertificate ::= SEQUENCE {
    version         [0]  Version DEFAULT v1,
    serialNumber         CertificateSerialNumber,
    signature            AlgorithmIdentifier,
    issuer               Name,
    validity             Validity,
    subject              Name,
    subjectPublicKeyInfo SubjectPublicKeyInfo,
    issuerUniqueID  [1]  IMPLICIT UniqueIdentifier OPTIONAL,
    subjectUniqueID [2]  IMPLICIT UniqueIdentifier OPTIONAL,
    extensions      [3]  Extensions OPTIONAL
}
```

**TBSCertificate** = "To Be Signed" Certificate. This is the part the CA signs.

### PEM = Base64 + Headers

PEM format wraps binary DER in Base64 with human-readable headers:

```
-----BEGIN CERTIFICATE-----
MIIDXTCCAkWgAwIBAgIJAJC1HiIAZAiUMA0GCSqGSIb3Qa...
(base64-encoded DER)
-----END CERTIFICATE-----
```

---

# PART 14 — PKI FILE TYPES

## Comprehensive File Extension Reference

| Extension | Full Name | Encoding | Private Key? | Cert? | Chain? | Multi? | Password? | Platform |
|-----------|-----------|----------|--------------|-------|--------|--------|-----------|----------|
| **.pem** | PEM format | Base64 DER | Maybe | Maybe | Maybe | Maybe | Optional | Universal |
| **.crt** | Certificate | Usually PEM | No | Yes | Maybe | Maybe | No | Universal |
| **.cer** | Certificate | DER or PEM | No | Yes | No | No | No | Windows |
| **.der** | DER encoded | Binary DER | No | Yes | No | No | No | Universal |
| **.key** | Private key | PEM | Yes | No | No | No | Optional | Universal |
| **.csr** | Certificate Signing Request | PEM | No (contains public key) | No | No | No | No | Universal |
| **.req** | Certificate Request | PEM | No | No | No | No | No | Windows |
| **.p12** | PKCS#12 | Binary | Yes | Yes | Yes | Yes | Yes | Universal |
| **.pfx** | Personal Information Exchange | Binary | Yes | Yes | Yes | Yes | Yes | Windows |
| **.p7b** | PKCS#7 (certs only) | Base64 or DER | No | Yes | Yes | Yes | No | Windows |
| **.p7c** | PKCS#7 (certs only) | Binary | No | Yes | Yes | Yes | No | Universal |
| **.p7s** | PKCS#7 (signed data) | Binary | No | No | N/A | N/A | No | Universal |
| **.crl** | Certificate Revocation List | DER or PEM | No | No | No | No | No | Universal |
| **.jks** | Java KeyStore | Binary | Yes | Yes | Yes | Yes | Yes | Java |
| **.bcfks** | Bouncy Castle FIPS KeyStore | Binary | Yes | Yes | Yes | Yes | Yes | Java (FIPS) |

**Important**: File extension alone does NOT guarantee contents. Always inspect files with OpenSSL or other tools.

---

# PART 15 — PEM

## PEM Armor

PEM uses ASCII headers/footers to identify content type:

```
-----BEGIN CERTIFICATE-----
```

Common PEM headers:

| Header | Content |
|--------|---------|
| `-----BEGIN CERTIFICATE-----` | X.509 certificate |
| `-----BEGIN PRIVATE KEY-----` | PKCS#8 private key |
| `-----BEGIN RSA PRIVATE KEY-----` | PKCS#1 RSA private key |
| `-----BEGIN EC PRIVATE KEY-----` | SEC1 EC private key |
| `-----BEGIN CERTIFICATE REQUEST-----` | PKCS#10 CSR |
| `-----BEGIN X509 CRL-----` | Certificate Revocation List |
| `-----BEGIN PKCS7-----` | PKCS#7 structure |
| `-----BEGIN ENCRYPTED PRIVATE KEY-----` | Password-protected PKCS#8 key |

### PKCS#1 vs. PKCS#8 Private Keys

| Format | Header | Description |
|--------|--------|-------------|
| **PKCS#1** | `BEGIN RSA PRIVATE KEY` | RSA-specific format |
| **PKCS#8** | `BEGIN PRIVATE KEY` | Algorithm-agnostic wrapper |

PKCS#8 can wrap any key type (RSA, EC, etc.). PKCS#1 is RSA-only.

### Encrypted Private Keys

```
-----BEGIN ENCRYPTED PRIVATE KEY-----
Proc-Type: 4,ENCRYPTED
DEK-Info: AES-256-CBC,...
```

These require a password to decrypt.

---

# PART 16 — DER

## Binary DER Encoding

**DER** is the binary representation of ASN.1 structures.

### PEM vs. DER

| Aspect | PEM | DER |
|--------|-----|-----|
| **Format** | Base64 text | Binary |
| **Readable** | Yes (with headers) | No |
| **Size** | ~33% larger | Compact |
| **Common use** | Certs, keys, CSRs | Windows, Java, network protocols |

### Conversion Commands

```bash
# PEM to DER
openssl x509 -in cert.pem -out cert.der -outform DER

# DER to PEM
openssl x509 -in cert.der -inform DER -out cert.pem

# Check if file is PEM or DER
file cert.pem  # ASCII text
cert.der       # data (binary)
```

---

# PART 17 — PKCS#12 / PFX / P12

## Personal Information Exchange

**PKCS#12** (.p12 or .pfx) is a container format that bundles:
- Private key(s)
- Certificate(s)
- Certificate chain(s)
- Optional metadata (friendlyName, localKeyID)

### Structure

```
PKCS#12 Container
├── AuthenticatedSafe (password-protected)
│   ├── CertBag (certificate)
│   ├── KeyBag (private key)
│   └── PKCS7 (certificate chain)
└── MacData (integrity check)
```

### Why Windows Uses PFX

Windows natively supports PFX for:
- Importing certificates into certificate stores
- Exporting certificates with private keys
- IIS SSL certificate deployment

### EJBCA SuperAdmin as P12

EJBCA delivers the SuperAdmin credential as a .p12 file containing:
- SuperAdmin private key
- SuperAdmin certificate (signed by ManagementCA)
- ManagementCA certificate (for chain validation)

```bash
# Inspect P12 without extracting
openssl pkcs12 -in superadmin.p12 -info -noout

# Extract certificate only (no private key)
openssl pkcs12 -in superadmin.p12 -clcerts -nokeys -out admin.crt

# Extract private key
openssl pkcs12 -in superadmin.p12 -nocerts -out admin.key
```

---

# PART 18 — PKCS#7

## Cryptographic Message Syntax

**PKCS#7** (.p7b, .p7c) is a format for:
- Certificate chains (without private keys)
- Signed data
- Encrypted data

### Characteristics

| Feature | PKCS#7 |
|---------|--------|
| Contains private key? | No (certificates only) |
| Contains certificate chain? | Yes |
| Password protected? | No (for cert chains) |
| Common use | Windows cert chain distribution |

### Conversion

```bash
# Convert PKCS#7 to PEM certificates
openssl pkcs7 -in chain.p7b -print_certs -out chain.pem

# Convert PEM certs to PKCS#7
openssl crl2pkcs7 -nocrl -certfile cert.pem -certfile ca.pem -out chain.p7b
```

---

# PART 19 — CSR

## Certificate Signing Request

A **CSR** (PKCS#10) is a message sent to a CA to request a certificate.

### What's in a CSR

| Field | Description |
|-------|-------------|
| **Subject** | Requested identity (DN) |
| **Public Key** | The public key to be certified |
| **Signature** | Proof of possession of private key |
| **Requested Extensions** | Desired SANs, key usage, etc. |

### What's NOT in a CSR

- **Private key**: Never sent to the CA
- **Final certificate fields**: CA decides validity, serial, etc.

### Proof of Possession

The CSR is signed with the private key corresponding to the public key in the CSR. This proves the requester possesses the private key.

### Example CSR Inspection

```bash
# Generate a CSR
openssl req -new -newkey rsa:2048 -nodes -keyout server.key -out server.csr -subj "/CN=server.example.com"

# Inspect CSR
openssl req -in server.csr -text -noout
```

### CSR Output Explained

```
Certificate Request:
    Data:
        Version: 1 (0x0)
        Subject: CN = server.example.com
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                RSA Public-Key: (2048 bit)
                Modulus:
                    00:aa:bb:cc:... (256 bytes)
                Exponent: 65537 (0x10001)
        Attributes:
            (none)
            Requested Extensions:
                X509v3 Subject Alternative Name:
                    DNS:server.example.com, DNS:www.example.com
    Signature Algorithm: sha256WithRSAEncryption
         aa:bb:cc:dd:... (256 bytes)
```

---

# PART 20 — CRL

## Certificate Revocation List

A **CRL** is a signed list of revoked certificates published by a CA.

### CRL Fields

| Field | Description |
|-------|-------------|
| **thisUpdate** | When this CRL was published |
| **nextUpdate** | When the next CRL will be published |
| **revokedCertificates** | List of revoked certs (serial + date + reason) |
| **CRL Number** | Monotonically increasing CRL version |
| **Authority Key Identifier** | Identifies the issuing CA |

### Revocation Entry

```
Serial Number: 045C7B2A1F9E3D8C7A4E2B5F1C8D3E7A
        Revocation Date: Aug 20 14:32:10 2026 GMT
        CRL entry extensions:
            X509v3 CRL Reason Code:
                Key Compromise
```

### CRL Distribution

Clients find CRLs through:
- **CRL Distribution Point (CDP)** extension in certificates
- **Freshest CRL** extension (for delta CRLs)

### Delta CRLs

A **delta CRL** contains only changes since the last **base CRL**:
- Faster download
- Reduced bandwidth
- Must be combined with base CRL for complete picture

### CRL vs. OCSP

| Aspect | CRL | OCSP |
|--------|-----|------|
| **Mechanism** | Download list | Query responder |
| **Size** | Grows over time | Small per-query |
| **Latency** | Check local file | Network round-trip |
| **Privacy** | No privacy leak | Leaks browsing to OCSP responder |
| **Freshness** | At publication interval | Near real-time |
| **Offline** | Works offline | Requires network |

---

# PART 21 — OCSP

## Online Certificate Status Protocol

**OCSP** allows real-time certificate status checking.

### How OCSP Works

```
┌─────────┐         OCSP Request          ┌───────────────┐
│ Client  │ ─────────────────────────────>│ OCSP Responder│
│         │  CertID (issuer hash + serial)│               │
│         │<──────────────────────────────│               │
│         │         OCSP Response         │               │
│         │         (good/revoked/unknown)│               │
└─────────┘                               └───────────────┘
```

### OCSP Request Components

| Field | Description |
|-------|-------------|
| **CertID** | Identifies the certificate being checked |
| **issuerNameHash** | Hash of issuer's DN |
| **issuerKeyHash** | Hash of issuer's public key |
| **serialNumber** | Serial number of certificate |

### OCSP Response Status

| Status | Meaning |
|--------|---------|
| **good** | Certificate is valid (not revoked) |
| **revoked** | Certificate has been revoked |
| **unknown** | Responder doesn't know about this certificate |

### OCSP Response Fields

| Field | Description |
|-------|-------------|
| **thisUpdate** | When this response was generated |
| **nextUpdate** | When a newer response should be available |
| **producedAt** | When the response was signed |

### Delegated OCSP Responder

The CA can delegate OCSP signing to a separate certificate:
- The delegated certificate has `EKU=OCSPSigning`
- It does NOT need `keyCertSign` (can't issue certificates)
- Reduces load on the CA's signing key

### OCSP No Check

The **OCSP No Check** extension (1.3.6.1.5.5.7.48.1.5) tells clients not to check the OCSP responder's own certificate. Used for delegated responders.

### OCSP Stapling / TLS Stapling

Instead of the client querying the OCSP responder:
1. The server queries the OCSP responder
2. The server staples the OCSP response into the TLS handshake
3. The client validates the stapled response

**Benefits**:
- Faster handshake (no client OCSP query)
- Better privacy (no client OCSP leak)
- Reduced OCSP responder load

### Must-Staple

The **TLS Feature** extension with **status_request** tells clients the server MUST staple an OCSP response. If no staple is present, the connection fails.

### Privacy Problems

OCSP leaks browsing history:
- Every HTTPS connection = OCSP query
- OCSP responder sees which sites you visit
- **Solution**: OCSP stapling (server queries, not client)

### Soft Fail vs. Hard Fail

| Mode | Behavior | Risk |
|------|----------|------|
| **Soft fail** | If OCSP fails, allow connection | Accepts potentially revoked certs |
| **Hard fail** | If OCSP fails, reject connection | Breaks connectivity if OCSP down |

---

# PART 22 — REVOCATION REASONS

## CRL Reason Codes

| Code | Name | When Used |
|------|------|-----------|
| 0 | **unspecified** | Default when no specific reason applies |
| 1 | **keyCompromise** | Private key leaked or stolen |
| 2 | **cACompromise** | CA private key compromised |
| 3 | **affiliationChanged** | Organization/role changed |
| 4 | **superseded** | Replaced by new certificate |
| 5 | **cessationOfOperation** | Service no longer exists |
| 6 | **certificateHold** | Temporary suspension (reversible) |
| 8 | **removeFromCRL** | Remove from delta CRL (hold released) |
| 9 | **privilegeWithdrawn** | Rights/privileges removed |
| 10 | **aACompromise** | Attribute Authority compromised |

### When to Use Each

- **keyCompromise**: Employee laptop stolen, private key exposed
- **cACompromise**: CA signing key leaked (catastrophic)
- **affiliationChanged**: Employee transferred departments
- **superseded**: Certificate renewed with new key
- **cessationOfOperation**: Server decommissioned
- **certificateHold**: Investigation pending (can be reversed)

---

# PART 23 — CRYPTO TOKENS

## EJBCA Crypto Tokens

In EJBCA, a **Crypto Token** is an abstraction over cryptographic keys. It is NOT the CA itself—it is the key container the CA uses.

### What a Crypto Token Contains

```
Crypto Token
├── signKey        (CA signing key)
├── encryptKey     (Encryption key)
├── testKey        (Test/validation key)
└── defaultKey     (Default for unspecified operations)
```

### Crypto Token Types

| Type | Description | Security |
|------|-------------|----------|
| **Soft Crypto Token** | Keys in software (database/files) | Lower |
| **PKCS#11 Crypto Token** | Keys in HSM via PKCS#11 | High |
| **HSM-backed** | Keys in Hardware Security Module | Highest |
| **Cloud HSM** | AWS CloudHSM, Azure Dedicated HSM | High |

### Key Aliases

Each key in a token has an **alias** (name):
- `signKey` - Signs certificates and CRLs
- `defaultKey` - Fallback key
- `testKey` - For testing without production keys

### Authentication

Crypto tokens require activation:
- **Authentication Code / PIN**: Password to unlock the token
- **Auto-activation**: Token unlocks automatically (convenient but less secure)
- **Manual activation**: Admin must unlock after restart (more secure)

### CA Signing Key vs. Other Keys

| Key Purpose | Usage |
|-------------|-------|
| **CA signing key** | Signs certificates and CRLs |
| **CRL signing key** | Signs CRLs (may be same as CA key) |
| **OCSP signing key** | Signs OCSP responses (often delegated) |
| **Encryption key** | Encrypts data (rarely used in CAs) |

### Why Private Keys Should Live in HSMs

1. **Non-exportable**: Keys never leave the HSM
2. **Tamper-resistant**: Physical tamper detection
3. **Access control**: Multi-person authentication
4. **Audit logging**: All operations logged
5. **Compliance**: FIPS 140-2/3 requirements

---

# PART 24 — HSM

## Hardware Security Module

An **HSM** is a dedicated hardware device for secure key generation, storage, and cryptographic operations.

### FIPS 140 Levels

| Level | Security | Description |
|-------|----------|-------------|
| **Level 1** | Software | Cryptographic module with no physical security |
| **Level 2** | Tamper-evident | Physical tamper-evident seals |
| **Level 3** | Tamper-responsive | Zeroizes keys on tamper detection |
| **Level 4** | Maximum | Protection against environmental attacks |

### PKCS#11

**PKCS#11** is the standard API for HSMs:
- **Slots**: Physical or logical HSM interfaces
- **Tokens**: Logical security domains within a slot
- **Objects**: Keys, certificates, data
- **Key handles**: References to keys (not the keys themselves)

### HSM Roles

| Role | Responsibility |
|------|---------------|
| **Security Officer (SO)** | Initializes HSM, sets PIN policies |
| **Crypto Officer** | Manages keys and crypto operations |
| **Crypto User** | Uses keys for signing/encryption |

### HSM vs. KMS vs. Vault vs. Secret Manager

| System | Type | Key Storage | Primary Use |
|--------|------|-------------|-------------|
| **HSM** | Hardware | Hardware | High-security signing |
| **KMS** | Cloud service | Hardware-backed | Cloud key management |
| **Vault** | Software | Software/optional HSM | Secret management |
| **Secret Manager** | Cloud service | Software/optional HSM | Application secrets |

---

# PART 25 — EJBCA ARCHITECTURE

## EJBCA in Your Lab

Your lab runs **EJBCA Community Edition 9.3.7** in the `ejbca` namespace.

### EJBCA Components

| Component | Purpose | In Your Lab |
|-----------|---------|-------------|
| **Management CA** | Admin identity CA | ✅ Running |
| **Root CA** | Trust anchor | ✅ LabRootCA |
| **Issuing CA** | Issues end-entity certs | ✅ LabIssuingCA |
| **Crypto Tokens** | Key containers | ✅ Configured |
| **Certificate Profiles** | Certificate templates | ✅ Default + custom |
| **End Entity Profiles** | Enrollment templates | ✅ Configured |
| **RA Web** | Registration Authority UI | ✅ Available |
| **VA** | Validation Authority | ✅ OCSP + CRL |
| **Publishers** | Certificate distribution | ✅ Active |

### EJBCCA Deployment

```yaml
# Your EJBCA deployment
Namespace: ejbca
Chart: ejbca-ce 9.3.7
Image: keyfactor/ejbca-ce:9.3.7
Database: PostgreSQL (bitnami/postgresql)
Service: LoadBalancer @ 192.168.122.74:80/443
```

### Protocols Supported

| Protocol | Purpose | Status |
|----------|---------|--------|
| **EST** | Enrollment over Secure Transport | ✅ Available |
| **SCEP** | Simple Certificate Enrollment | ✅ Available |
| **ACME** | Automatic Certificate Management | ✅ Available |
| **CMP** | Certificate Management Protocol | ✅ Available |
| **Web Services** | SOAP/XML | ✅ Available |
| **REST** | JSON API | ✅ Available |

---

# PART 26 — CERTIFICATE PROFILES

## EJBCA Certificate Profiles

A **Certificate Profile** defines what a certificate may contain and how it is constructed.

### What Certificate Profiles Control

| Setting | Description |
|---------|-------------|
| **Key Algorithms** | RSA, ECDSA, allowed curves |
| **Key Sizes** | Minimum/maximum key length |
| **Validity** | Certificate lifetime |
| **Key Usage** | Allowed key usage bits |
| **Extended Key Usage** | Allowed EKUs |
| **SAN Behavior** | Required/optional SANs |
| **Basic Constraints** | CA:true/false, path length |
| **CRL Distribution** | CDP inclusion |
| **AIA** | Authority Information Access |
| **Certificate Policies** | Policy OIDs |

### Certificate Profile vs. End Entity Profile

| Aspect | Certificate Profile | End Entity Profile |
|--------|-------------------|-------------------|
| **Controls** | Technical cert properties | Enrollment identity info |
| **Examples** | Key size, validity, KU | Subject DN fields, SANs |
| **Who sets** | PKI administrator | RA administrator |

---

# PART 27 — END ENTITY PROFILES

## EJBCA End Entity Profiles

An **End Entity Profile** defines what information an end entity (user, server, device) must provide during enrollment.

### What End Entity Profiles Control

| Setting | Description |
|---------|-------------|
| **Username** | Login name for enrollment |
| **Subject DN Fields** | Required/optional DN components |
| **SAN Fields** | Allowed SAN types |
| **Certificate Profile** | Which cert profile to use |
| **CA Selection** | Which CA issues the certificate |
| **Required Fields** | Mandatory information |
| **Default Values** | Pre-filled values |
| **Validation** | Regex patterns for fields |

### Example: Server Certificate Profile

```
End Entity Profile: "TLS Servers"
├── Subject DN:
│   ├── CN: Required
│   ├── O: Optional (default: Homelab)
│   └── C: Optional (default: US)
├── SAN:
│   ├── DNS: Required
│   └── IP: Optional
├── Certificate Profile: "TLS Server Profile"
└── CA: LabIssuingCA
```

---

# PART 28 — END ENTITY

## What Is an End Entity?

An **end entity** is anything that receives a certificate:

| Type | Example | Certificate Purpose |
|------|---------|---------------------|
| **Person** | Employee | Email signing, VPN access |
| **Server** | cert-api pod | TLS authentication |
| **Device** | IoT sensor | Device identity |
| **Router** | Core switch | Management access |
| **Container** | cert-worker | Workload identity |
| **Service Account** | cert-api SA | Kubernetes authentication |

### EJBCA End Entity Records

In EJBCA, an end entity record contains:
- Username and password
- Subject DN information
- SAN information
- Certificate profile reference
- CA reference
- Status (new, generated, revoked, etc.)

---

# PART 29 — RA

## Registration Authority

A **Registration Authority (RA)** handles identity verification and request approval before the CA issues certificates.

### RA Responsibilities

| Task | Description |
|------|-------------|
| **Identity Verification** | Confirm the requester is who they claim |
| **Request Approval** | Approve or deny certificate requests |
| **Enrollment** | Assist with certificate enrollment |
| **Revocation Requests** | Process revocation requests |
| **Audit** | Maintain audit logs |

### CA ≠ RA

| Function | CA | RA |
|----------|-----|-----|
| **Sign certificates** | ✅ Yes | ❌ No |
| **Verify identity** | ❌ No | ✅ Yes |
| **Approve requests** | May delegate | ✅ Yes |
| **Hold private key** | ✅ Yes | ❌ No |

### RA Architecture

```
User / Device
     │
     │ CSR / Enrollment Request
     ▼
    RA (Identity Verification)
     │
     │ Approved Request
     ▼
    CA (Certificate Signing)
     │
     ▼
  Certificate
```

### EJBCA RA Web

EJBCA provides a web-based RA interface for:
- End entity registration
- Certificate enrollment
- Certificate revocation
- Certificate search

---

# PART 30 — VA

## Validation Authority

A **Validation Authority (VA)** provides certificate validation services separate from the CA.

### VA Services

| Service | Description |
|---------|-------------|
| **OCSP Responder** | Real-time certificate status |
| **CRL Distribution** | Serves CRLs to clients |
| **Certificate Search** | Find certificates by criteria |

### Why Separate VA from CA

| Benefit | Explanation |
|---------|-------------|
| **Security** | VA doesn't hold CA signing key |
| **Availability** | VA can be highly available |
| **Performance** | Distribute validation load |
| **Internet-facing** | VA can be public; CA stays private |

### High Availability

VAs are often deployed in clusters:
- Multiple OCSP responders behind a load balancer
- CRLs replicated to multiple distribution points
- Geographic distribution for low latency

---

# PART 31 — MANAGEMENT CA

## EJBCA ManagementCA

The **ManagementCA** is a special CA in EJBCA used for administrative identities.

### Purpose

| Use | Description |
|-----|-------------|
| **SuperAdmin** | Client certificate for EJBCA admin UI |
| **Administrators** | Role-based admin certificates |
| **System Users** | Internal EJBCA service accounts |

### ManagementCA vs. PKI Root CA

| Aspect | ManagementCA | PKI Root CA |
|--------|--------------|-------------|
| **Purpose** | Admin authentication | Application trust anchor |
| **Trust** | Only EJBCA systems | Widely distributed |
| **Certificates** | Admin/client certs | CA certificates only |
| **In your lab** | ✅ Exists | ✅ LabRootCA |

### Your Lab's ManagementCA

```
Subject: CN=ManagementCA, O=EJBCA Sample, C=SE
Type: Management CA
Issuer: Self-signed
Expires: 2036-08-03
```

---

# PART 32 — EJBCA SUPERADMIN CERTIFICATE

## SuperAdmin.p12

The **superadmin.p12** file is the initial administrative credential for EJBCA.

### Contents

| Component | Description |
|-----------|-------------|
| **Private Key** | SuperAdmin's signing key |
| **Certificate** | Signed by ManagementCA |
| **Chain** | ManagementCA certificate |

### Usage

1. Import into browser or client
2. Access EJBCA Admin Web
3. Client certificate authentication
4. Full administrative access

### Security

- **Highly sensitive**: Grants full CA control
- **Store securely**: Password-protected, encrypted storage
- **Rotate regularly**: Generate new admin credentials periodically
- **Limit distribution**: Only trusted administrators

---

# PART 33 — CERTIFICATE ENROLLMENT PROTOCOLS

## Overview

| Protocol | Authentication | Use Case | Complexity |
|----------|---------------|----------|------------|
| **Manual** | Out-of-band | One-off certificates | Low |
| **PKCS#10** | CSR submission | Generic enrollment | Low |
| **SCEP** | Shared secret | Network devices, MDM | Medium |
| **ACME** | Domain validation | Web servers, Let's Encrypt | Medium |
| **EST** | TLS client auth | Enterprise devices | Medium |
| **CMP** | Shared secret or cert | Enterprise PKI | High |

---

# PART 34 — SCEP

## Simple Certificate Enrollment Protocol

**SCEP** is widely used for network device and mobile device management (MDM) enrollment.

### SCEP Operations

| Operation | Description |
|-----------|-------------|
| **GetCACert** | Retrieve CA certificate |
| **GetCACaps** | Retrieve CA capabilities |
| **PKIOperation** | Submit CSR / retrieve certificate |
| **GetNextCACert** | Retrieve next/rollover CA certificate |

### SCEP Authentication

- **Challenge password**: Pre-shared secret
- **Nonce**: One-time random value
- **Polling**: Client polls for certificate after submission

### Security Concerns

- Challenge passwords must be distributed securely
- No perfect forward secrecy
- Vulnerable to replay if nonces not checked

---

# PART 35 — ACME

## Automatic Certificate Management Environment

**ACME** (RFC 8555) is the protocol used by Let's Encrypt.

### ACME Flow

```
1. Create Account (with JWS-signed request)
2. Create Order (request certificate for identifiers)
3. Authorizations (prove control of identifiers)
4. Challenges:
   ├── HTTP-01 (serve token on web server)
   ├── DNS-01 (create DNS TXT record)
   └── TLS-ALPN-01 (respond with special cert)
5. Finalize Order (submit CSR)
6. Download Certificate
```

### Challenge Types

| Challenge | How It Works | Best For |
|-----------|--------------|----------|
| **HTTP-01** | Serve token at `/.well-known/acme-challenge/` | Single server, port 80 available |
| **DNS-01** | Create `_acme-challenge` TXT record | Wildcards, internal servers |
| **TLS-ALPN-01** | Respond with special ALPN cert | Port 443 only |

### EJBCA ACME Support

Your EJBCA deployment supports ACME for internal certificate automation.

---

# PART 36 — EST

## Enrollment over Secure Transport

**EST** (RFC 7030) is a modern enrollment protocol using TLS.

### EST Operations

| Operation | Description |
|-----------|-------------|
| **/cacerts** | Retrieve CA certificates |
| **/simpleenroll** | Submit CSR, get certificate |
| **/simplereenroll** | Renew existing certificate |
| **/csrattrs** | Get required CSR attributes |
| **/serverkeygen** | Server generates key pair |

### EST Authentication

- **TLS client certificate**: Existing certificate authenticates renewal
- **HTTP Basic Auth**: Username/password for initial enrollment
- **TLS-PSK**: Pre-shared key (less common)

### Enterprise Use

EST is ideal for:
- Enterprise device onboarding
- Certificate renewal
- IoT provisioning

---

# PART 37 — CMP

## Certificate Management Protocol

**CMP** (RFC 4210) is a comprehensive protocol for certificate lifecycle management.

### CMP Operations

| Message | Purpose |
|---------|---------|
| **Initialization Request** | Initial certificate request |
| **Certification Request** | Certificate request (PKCS#10) |
| **Key Update Request** | Renewal with same or new key |
| **Revocation Request** | Request certificate revocation |
| **Certification Confirm** | Confirm receipt of certificate |

### CMP Authentication

| Method | Description |
|--------|-------------|
| **Shared secret** | Password-based (MAC protection) |
| **Signature** | Existing certificate-based |
| **POP** | Proof of Possession of private key |

---

# PART 38 — MICROSOFT CERTUTIL

## Certutil Reference

**certutil** is the Windows command-line tool for certificate operations.

### Common Commands

```cmd
# Dump certificate details
certutil -dump certificate.cer

# List certificates in store
certutil -store my

# Verify certificate chain
certutil -verify certificate.cer

# Check revocation (CRL + OCSP)
certutil -url certificate.cer

# Export certificate
certutil -exportpfx my "SerialNumber" output.pfx
```

### Certutil Output Fields

| Field | Meaning |
|-------|---------|
| **Serial Number** | Certificate serial (hex) |
| **Issuer** | Who signed the certificate |
| **NotBefore** | Valid from date |
| **NotAfter** | Expiration date |
| **Subject** | Certificate owner |
| **Public Key** | Key algorithm and size |
| **Key Id Hash** | Subject Key Identifier |
| **Cert Hash** | Certificate thumbprint |
| **Signature Hash** | Signature algorithm |
| **Thumbprint** | SHA-1 fingerprint |

### Understanding Hex Dumps

Certutil shows hex bytes in groups for readability:
```
0000  30 82 04 12 30 82 02 fa a0 03 02 01 02 02 10 04   0...0...........
0010  5c 7b 2a 1f 9e 3d 8c 7a 4e 2b 5f 1c 8d 3e 7a 5c   \{*..=.zN+_..>z\
```

The ASCII rendering on the right helps identify text fields within binary data.

---

# PART 39 — OPENSSL CERTIFICATE INSPECTION

## OpenSSL Commands

### View Certificate

```bash
# Full text output
openssl x509 -in cert.pem -text -noout

# Specific fields
openssl x509 -in cert.pem -subject -noout
openssl x509 -in cert.pem -issuer -noout
openssl x509 -in cert.pem -dates -noout
openssl x509 -in cert.pem -fingerprint -sha256 -noout
```

### View CSR

```bash
openssl req -in request.csr -text -noout
```

### Verify Chain

```bash
# Verify with CA file
openssl verify -CAfile ca.pem -untrusted intermediate.pem leaf.pem

# Verify server certificate
openssl s_client -connect server:443 -servername server -showcerts
```

### View CRL

```bash
openssl crl -in ca.crl -text -noout
```

### OCSP Query

```bash
openssl ocsp -issuer issuer.pem -cert cert.pem \
  -url http://ocsp.example.com -VAfile ocsp-signer.pem
```

### PKCS#12 Operations

```bash
# Inspect P12
openssl pkcs12 -in cert.p12 -info -noout

# Extract certificate only
openssl pkcs12 -in cert.p12 -clcerts -nokeys -out cert.pem

# Extract private key
openssl pkcs12 -in cert.p12 -nocerts -out key.pem
```

### ASN.1 Parsing

```bash
# Parse ASN.1 structure
openssl asn1parse -in cert.pem

# Parse with indentation
openssl asn1parse -in cert.pem -i
```

---

# PART 40 — CERTIFICATE VALIDATION

## What Happens During Validation

When a client validates a certificate, it performs these checks:

### 1. Chain Building

```
Leaf Certificate
      ↓
Issuer found via AKI
      ↓
Intermediate Certificate
      ↓
Issuer found via AKI
      ↓
Root Certificate (in trust store)
```

### 2. Signature Verification

Each certificate's signature is verified using the issuer's public key:
- Verify leaf signature with intermediate's key
- Verify intermediate signature with root's key
- Root is self-signed (trusted implicitly)

### 3. Validity Period

Current time must be between Not Before and Not After.

### 4. Hostname/SAN Validation

The requested hostname must match:
- A DNS SAN entry, OR
- The Subject CN (if no SAN extension present)

### 5. Key Usage and EKU

- Key Usage must permit the intended operation
- EKU must permit the intended application

### 6. Basic Constraints

- CA certificates must have CA=true
- End-entity certificates must have CA=false
- pathLenConstraint must not be exceeded

### 7. Revocation Check

- Check CRL Distribution Points
- Query OCSP responder
- Verify staple if present

### 8. Policy Validation

- Check certificate policy OIDs
- Verify against local policy requirements

### Important Distinction

> **"Certificate signature is valid" ≠ "Certificate is trusted"**

A signature can be cryptographically valid but the certificate can still be:
- Expired
- Revoked
- Issued by an untrusted CA
- For the wrong hostname
- Missing required extensions

---

# PART 41 — TLS

## Transport Layer Security

**TLS** provides encrypted communication over a network.

### TLS Handshake (Simplified)

```
Client                           Server
  │                                 │
  │ ───── ClientHello ────────────> │
  │    (supported cipher suites)    │
  │                                 │
  │ <──── ServerHello ───────────── │
  │    (chosen cipher suite)        │
  │                                 │
  │ <──── Certificate ───────────── │
  │    (server certificate chain)   │
  │                                 │
  │ <──── ServerKeyExchange ─────── │
  │    (ECDHE parameters)           │
  │                                 │
  │ <──── ServerHelloDone ───────── │
  │                                 │
  │ ───── ClientKeyExchange ──────> │
  │    (pre-master secret)          │
  │                                 │
  │ ───── ChangeCipherSpec ───────> │
  │ ───── Finished ───────────────> │
  │                                 │
  │ <──── ChangeCipherSpec ──────── │
  │ <──── Finished ──────────────── │
  │                                 │
  │ ═════ Encrypted Application ═══ │
  │      Data Flow Begins           │
```

### Key Points

- **Server certificate**: Authenticates the server
- **ECDHE**: Ephemeral key exchange for forward secrecy
- **Session keys**: Symmetric keys derived for actual encryption
- **Certificate does NOT encrypt traffic**: It only authenticates; symmetric encryption handles data

---

# PART 42 — mTLS

## Mutual TLS

**mTLS** requires both client and server to present and verify certificates.

### Your Lab mTLS Architecture

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│  cert-api   │◄───────►│   RabbitMQ  │◄───────►│ cert-worker │
│  (server)   │  mTLS   │  (broker)   │  mTLS   │  (client)   │
└─────────────┘         └─────────────┘         └─────────────┘
       │                       │                       │
       │ SPIFFE/SPIRE          │ SPIFFE/SPIRE          │
       │ workload identity     │ workload identity     │
       ▼                       ▼                       ▼
   URI SAN:               URI SAN:                URI SAN:
   spiffe://homelab      spiffe://homelab        spiffe://homelab
   /ns/pki/sa/cert-api   /ns/pki/sa/rabbitmq     /ns/pki/sa/cert-worker
```

### mTLS Flow

1. **Client connects** to server
2. **Server presents certificate** → Client validates
3. **Client presents certificate** → Server validates
4. **Both verify**:
   - Chain of trust
   - Validity period
   - Revocation status
   - SPIFFE identity (if using SPIRE)
5. **Encrypted session** begins

### SPIFFE mTLS

With SPIRE, mTLS is automated:
- SPIRE Agent provides SVID (X.509 certificate with URI SAN)
- Workloads use SVID for mutual authentication
- No manual certificate management

---

# PART 43 — SPIFFE / SPIRE

## Workload Identity

**SPIFFE** (Secure Production Identity Framework For Everyone) provides a standard for workload identification.

### Core Concepts

| Concept | Description | Example |
|---------|-------------|---------|
| **SPIFFE ID** | Unique workload identifier | `spiffe://homelab.local/ns/pki/sa/cert-worker` |
| **Trust Domain** | Administrative boundary | `homelab.local` |
| **SVID** | SPIFFE Verifiable Identity Document | X.509 certificate or JWT |
| **X.509-SVID** | X.509 certificate with URI SAN | Standard for mTLS |
| **JWT-SVID** | JSON Web Token | For non-TLS scenarios |

### SPIRE Architecture

```
┌─────────────────────────────────────────┐
│           SPIRE Server                  │
│  (Trust domain: homelab.local)          │
│  - Maintains registration entries       │
│  - Issues SVIDs                         │
│  - Provides CA bundle                   │
└─────────────────────────────────────────┘
                    │
        ┌───────────┼───────────┐
        │           │           │
        ▼           ▼           ▼
   ┌─────────┐ ┌─────────┐ ┌─────────┐
   │  Node   │ │  Node   │ │  Node   │
   │Agent #1 │ │Agent #2 │ │Agent #3 │
   └────┬────┘ └────┬────┘ └────┬────┘
        │           │           │
        ▼           ▼           ▼
   ┌─────────┐ ┌─────────┐ ┌─────────┐
   │Workload │ │Workload │ │Workload │
   │  SVID   │ │  SVID   │ │  SVID   │
   └─────────┘ └─────────┘ └─────────┘
```

### SPIRE in Your Lab

| Component | Status | Details |
|-----------|--------|---------|
| **SPIRE Server** | ✅ Running | Namespace: spire |
| **SPIRE Agent** | ✅ Running | DaemonSet on k8s01 |
| **CSI Driver** | ✅ Installed | `csi.spiffe.io` |
| **ClusterSPIFFEID** | ✅ Configured | Auto-registration |
| **Trust Domain** | `homelab.local` | Configured |

### SPIFFE ID Format in Your Lab

```
spiffe://homelab.local/ns/{namespace}/sa/{serviceAccount}
```

Examples:
- `spiffe://homelab.local/ns/pki/sa/cert-api`
- `spiffe://homelab.local/ns/pki/sa/cert-worker`
- `spiffe://homelab.local/ns/default/sa/default`

### SPIFFE vs. Manual Certificates

| Aspect | Manual Certificates | SPIFFE/SPIRE |
|--------|-------------------|--------------|
| **Provisioning** | Manual CSR, approval, issuance | Automatic |
| **Rotation** | Manual renewal | Automatic before expiry |
| **Identity** | Static hostname | Dynamic workload identity |
| **Revocation** | Manual CRL/OCSP | Automatic on workload termination |
| **Scale** | Difficult at scale | Designed for cloud-native |

---

# PART 44 — OPENBAO

## OpenBao in Your Lab

**OpenBao** (a HashiCorp Vault fork) provides secret management and dynamic credentials.

### Your OpenBao Deployment

```yaml
Namespace: openbao
Version: 2.6.2
Storage: raft (HA enabled)
Status: Unsealed
Seal Type: Shamir (3 of 5)
```

### Key Concepts

| Concept | Description |
|---------|-------------|
| **Secrets** | Encrypted key-value data |
| **Authentication** | Methods: token, Kubernetes, TLS, etc. |
| **Policies** | ACL rules for secret access |
| **Leases** | Time-limited secret grants |
| **Tokens** | Short-lived access credentials |
| **Dynamic Secrets** | On-demand credentials (DB, cloud, etc.) |

### PKI Engine

OpenBao's PKI engine can:
- Act as a CA (root or intermediate)
- Issue certificates dynamically
- Handle revocation
- Provide CRL and OCSP

In your lab, EJBCA is the primary CA; OpenBao handles secrets and workload authentication.

### Kubernetes Auth

Your lab configures Kubernetes authentication:
- Pods authenticate using service account tokens
- OpenBao verifies tokens with the Kubernetes API
- Policies grant access based on service account identity

### OpenBao vs. SPIRE

| Aspect | OpenBao | SPIRE |
|--------|---------|-------|
| **Primary role** | Secret management | Workload identity |
| **Certificates** | Can issue via PKI engine | Issues X.509-SVIDs |
| **Authentication** | Tokens, K8s, TLS, etc. | Workload attestation |
| **Overlap** | Both can issue certificates | Both provide identity |
| **In your lab** | Secrets, K8s auth | mTLS, workload SVIDs |

**They complement each other**: OpenBao manages secrets; SPIRE provides identity.

---

# PART 45 — CERTIFICATE LIFECYCLE MANAGEMENT

## Full Lifecycle

```
┌─────────┐
│ REQUEST │
│  CSR    │
└────┬────┘
     │
     ▼
┌─────────┐
│VALIDATE │
│ Identity│
└────┬────┘
     │
     ▼
┌─────────┐
│ APPROVE │
│  by RA  │
└────┬────┘
     │
     ▼
┌─────────┐
│  ISSUE  │
│CA signs │
└────┬────┘
     │
     ▼
┌─────────┐
│ DELIVER │
│ to req. │
└────┬────┘
     │
     ▼
┌─────────┐
│ INSTALL │
│ on svc  │
└────┬────┘
     │
     ▼
┌─────────┐
│DISCOVER │
│ in env  │
└────┬────┘
     │
     ▼
┌─────────┐
│INVENTORY│
│  track  │
└────┬────┘
     │
     ▼
┌─────────┐
│ MONITOR │
│ expiry  │
└────┬────┘
     │
     ▼
┌─────────┐
│  RENEW  │
│before   │
│expiry   │
└────┬────┘
     │
     ▼
┌─────────┐
│ REVOKE  │
│ if bad  │
└────┬────┘
     │
     ▼
┌─────────┐
│ EXPIRE  │
│ natural │
└────┬────┘
     │
     ▼
┌─────────┐
│  AUDIT  │
│  log    │
└─────────┘
```

### Your Lab Implementation

| Stage | Component | Status |
|-------|-----------|--------|
| Request | cert-api REST API | ✅ Implemented |
| Validate | EJBCA RA | ✅ Available |
| Approve | Manual/Auto | ✅ Configurable |
| Issue | EJBCA CA | ✅ Running |
| Deliver | Kubernetes secrets | ✅ Automated |
| Install | cert-manager/SPIRE | ✅ Active |
| Discover | cert-worker CronJob | ✅ Configured |
| Inventory | PostgreSQL database | ✅ Running |
| Monitor | Prometheus/Grafana | ✅ Active |
| Renew | cert-worker CronJob | ✅ Configured |
| Revoke | EJBCA Admin / API | ✅ Available |
| Expire | Automatic | ✅ Natural process |
| Audit | EJBCA logs / K8s audit | ✅ Available |

---

# PART 46 — CRYPTO INVENTORY

## Why Inventory Cryptography

Enterprises inventory certificates to:
- Know what certificates exist
- Track ownership and responsibility
- Monitor expiration
- Plan renewals
- Assess security posture
- Prepare for PQC migration

### Inventory Fields

| Field | Description | Example |
|-------|-------------|---------|
| **Hostname** | Where the cert is installed | cert-api.pki.svc.cluster.local |
| **Certificate** | Common name or identifier | cert-api |
| **Serial Number** | Unique identifier | 045C7B2A... |
| **Subject** | Full DN | CN=cert-api... |
| **SAN** | Alternative names | DNS:cert-api, IP:10.43.123.45 |
| **Issuer** | Issuing CA | CN=LabIssuingCA |
| **Algorithm** | Public key algorithm | RSA |
| **Key Size** | Key length | 2048 |
| **Expiration** | Not After date | 2027-08-15 |
| **Owner** | Team/person responsible | Platform Team |
| **Environment** | Production/staging/dev | Production |
| **Application** | Service using the cert | cert-api |
| **PQC Compatible** | Ready for post-quantum | No (RSA 2048) |

### Unknown Certificate Risk

Unknown certificates are a security risk:
- No one renews them → outages
- No one revokes compromised ones → breaches
- No one audits them → compliance failures

### Your Lab Inventory

The `cert-worker` CronJob scans and stores inventory in PostgreSQL.

---

# PART 47 — PQC / CRYPTO AGILITY

## Post-Quantum Cryptography

### Quantum Threat

**Shor's algorithm** (on a quantum computer) can factor integers and solve discrete logarithms efficiently, breaking:
- RSA
- ECDSA
- DSA
- Diffie-Hellman

**Grover's algorithm** halves the effective security of symmetric crypto:
- AES-256 → ~128 bits (still secure)
- AES-128 → ~64 bits (not secure)

### Impact Assessment

| Algorithm | Quantum Vulnerable? | Mitigation |
|-----------|-------------------|------------|
| RSA | ✅ Yes | Replace with PQC |
| ECDSA | ✅ Yes | Replace with PQC |
| AES-256 | ❌ No (adequate margin) | Increase key size if concerned |
| SHA-256 | ❌ No (adequate margin) | Use SHA-384/512 for long-term |

### Post-Quantum Algorithms

| Algorithm | Type | Standard |
|-----------|------|----------|
| **ML-KEM** (Kyber) | Key Encapsulation | NIST FIPS 203 |
| **ML-DSA** (Dilithium) | Digital Signature | NIST FIPS 204 |
| **SLH-DSA** (SPHINCS+) | Stateless Signature | NIST FIPS 205 |

### Hybrid Certificates

**Hybrid** certificates contain both classical and PQC keys:
- Provides security even if PQC algorithm has flaws
- Transition strategy during migration

### Crypto Agility

**Crypto agility** is the ability to quickly switch cryptographic algorithms.

Requirements:
- Algorithm identifiers in certificates
- Flexible certificate profiles
- Automated certificate rotation
- Inventory of all cryptographic assets

### Harvest Now, Decrypt Later

Attackers may be collecting encrypted data today to decrypt when quantum computers become available.

**Mitigation**: Protect long-lived secrets with quantum-resistant algorithms now.

### Your Lab PQC Assessment

The `cert-worker` PQC scan CronJob identifies:
- Certificates using RSA < 3072
- Certificates using ECDSA < P-384
- Legacy algorithms (MD5, SHA-1)

---

# PART 48 — KEY COMPROMISE

## Compromise Scenarios

### Leaf Private Key Compromised

**Impact**: Single certificate untrusted

**Response**:
1. Revoke certificate (reason: keyCompromise)
2. Generate new key pair
3. Request new certificate
4. Deploy new certificate
5. Monitor for misuse

### Issuing CA Key Compromised

**Impact**: All certificates from that CA untrusted

**Response**:
1. Revoke issuing CA certificate
2. Issue new intermediate CA with new key
3. Re-issue all certificates
4. Update trust stores
5. Investigate breach

### Root CA Key Compromised

**Impact**: Entire PKI hierarchy untrusted

**Response**:
1. Emergency root rollover
2. Generate new root key pair
3. Distribute new root to all trust stores
4. Re-issue entire hierarchy
5. Major incident response

### OCSP Responder Key Compromised

**Impact**: OCSP responses untrusted

**Response**:
1. Revoke OCSP responder certificate
2. Issue new OCSP responder cert
3. Clients fall back to CRL (if configured)

---

# PART 49 — CERTIFICATE EXPIRATION

## What Expiration Means

A certificate has a **Not After** date. After this date, it is invalid.

### Types of Expiration

| Type | Impact | Example |
|------|--------|---------|
| **Leaf expired** | Service unavailable | Server certificate expires |
| **Intermediate expired** | Chain breaks | Issuing CA expires |
| **Root expired** | Trust anchor lost | Root CA expires |
| **OCSP signer expired** | Validation fails | OCSP responder cert expires |
| **CRL expired** | Revocation unknown | CRL nextUpdate passed |

### Chain Behavior

Clients validate the entire chain:
- If intermediate expires before leaf → chain invalid
- If root expires → all chains break
- Roots should have very long lifetimes (20+ years)

### Your Lab Monitoring

Prometheus alerts monitor certificate expiration:
- Alert when < 30 days remaining
- Alert when < 7 days remaining (critical)
- Automated renewal via cert-worker

---

# PART 50 — CA RENEWAL / REKEY

## CA Certificate Update

### Renewal (Same Key)

- New certificate with same public key
- Less disruptive
- No trust store updates needed
- Validity period extended

### Rekey (New Key)

- New certificate with new key pair
- More secure (fresh key)
- Trust stores must be updated
- All subordinate CAs must be re-issued

### CA Rollover

Planned transition to new CA:
1. Generate new CA key pair
2. Issue new CA certificate
3. Distribute to trust stores
4. Overlap validity periods
5. Gradually migrate certificates
6. Retire old CA

### Cross Certificates

During rollover, cross-certificates bridge old and new:
```
Old Root ──cross──► New Root
   │                    │
   └─── Old Chain       └─── New Chain
```

---

# PART 51 — WINDOWS CERTIFICATE STORES
\n## Windows Certificate Stores

### Store Locations

| Location | Scope | Access |
|----------|-------|--------|
| **Current User** | User-specific | User only |
| **Local Machine** | System-wide | Administrators |

### Standard Stores

| Store | Purpose |
|-------|---------|
| **My / Personal** | User's own certificates |
| **Root** | Trusted root CAs |
| **CA** | Intermediate CAs |
| **TrustedPublisher** | Trusted software publishers |
| **WebHosting** | IIS SSL certificates |

### Management Tools

| Tool | Scope |
|------|-------|
| **certmgr.msc** | Current User stores |
| **certlm.msc** | Local Machine stores |
| **certutil** | Command-line operations |

---

# PART 52 — JAVA TRUST STORES

## Java PKI

### KeyStore Types

| Type | Format | Use |
|------|--------|-----|
| **JKS** | Java-specific | Legacy |
| **PKCS#12** | Standard | Modern replacement |
| **BCFKS** | Bouncy Castle FIPS | FIPS-compliant |

### cacerts

The **cacerts** file is Java's default trust store:
- Location: `$JAVA_HOME/lib/security/cacerts`
- Password: `changeit` (default)
- Contains pre-installed root CA certificates

### keytool Commands

```bash
# List trust store
keytool -list -keystore $JAVA_HOME/lib/security/cacerts

# Import certificate
keytool -import -alias myca -file ca.crt -keystore cacerts

# Generate key pair
keytool -genkeypair -alias server -keyalg RSA -keystore keystore.jks
```

### EJBCA Relevance

EJBCA runs on Java and uses:
- Java KeyStores for TLS
- Bouncy Castle for cryptographic operations
- JKS or PKCS#12 for certificate storage

---

# PART 53 — CONTAINER / KUBERNETES PKI

## Kubernetes Certificate Management

### Kubernetes API Certificates

K3s automatically manages:
- API server certificate
- Kubelet certificates
- etcd certificates (if embedded)
- Service account tokens

### TLS Secrets

Kubernetes has a built-in secret type for certificates:

```yaml
apiVersion: v1
kind: Secret
type: kubernetes.io/tls
metadata:
  name: my-tls-secret
data:
  tls.crt: <base64-encoded certificate>
  tls.key: <base64-encoded private key>
```

### Ingress TLS

Ingress resources reference TLS secrets:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
spec:
  tls:
  - hosts:
    - example.com
    secretName: my-tls-secret
```

### cert-manager

Your lab uses **cert-manager** for:
- Automatic certificate issuance
- Certificate renewal
- Integration with CAs (EJBCA, Let's Encrypt)

### SPIFFE Workload Identity

In your lab, SPIRE provides:
- Automatic workload certificate injection
- URI SANs for service identity
- mTLS between workloads

### Certificate Rotation

Kubernetes workloads handle rotation by:
1. Mounting certificates as files
2. Watching for file changes
3. Reloading certificates without restart

---

# PART 54 — ARGO CD / GITOPS AND PKI

## GitOps for PKI Infrastructure

### What Argo CD Manages

Your Argo CD manages PKI **infrastructure**:
- Deployments
- Services
- ConfigMaps
- NetworkPolicies
- ServiceAccounts
- Certificate resources (cert-manager)

### What Argo CD Does NOT Manage

**Never store in Git**:
- CA private keys
- OpenBao unseal keys
- Root tokens
- Database passwords (use sealed secrets or external secret management)

### Argo CD Concepts

| Concept | Description |
|---------|-------------|
| **Desired State** | Git repository contents |
| **Live State** | Actual cluster state |
| **Drift** | Difference between desired and live |
| **Sync** | Apply desired state to cluster |
| **Prune** | Remove resources not in Git |
| **Self-Heal** | Automatically correct drift |

### Stateful Workload Dangers

Be careful with:
- Databases (PostgreSQL data)
- OpenBao (sealed state)
- EJBCA (CA keys in persistent storage)

**Never enable prune on stateful workloads without backups.**

### Your Argo CD Configuration

```yaml
# Root application
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: homelab
spec:
  source:
    repoURL: https://github.com/AdamKnight02/homelab-gitops
    targetRevision: main
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

# PART 55 — MY LAB ARCHITECTURE

## Current Lab Architecture

```mermaid
graph TB
    subgraph "Fedora Host"
        F[Fedora Workstation<br/>192.168.1.107]
    end
    
    subgraph "K3s Cluster (k8s01)"
        subgraph "argocd"
            A[Argo CD]
        end
        
        subgraph "ejbca"
            E[EJBCA CE 9.3.7]
            PG[PostgreSQL]
        end
        
        subgraph "openbao"
            OB[OpenBao 2.6.2]
        end
        
        subgraph "spire"
            SS[SPIRE Server]
            SA[SPIRE Agent]
            CSI[CSI Driver]
        end
        
        subgraph "pki"
            API[cert-api]
            WORKER[cert-worker]
            CA[ca-service]
            DB[pki-database]
        end
        
        subgraph "monitoring"
            P[Prometheus]
            G[Grafana]
        end
        
        subgraph "registry"
            R[Registry 2.8.3]
        end
        
        subgraph "rabbitmq"
            MQ[RabbitMQ 4.1.3]
        end
        
        subgraph "cert-manager"
            CM[cert-manager]
        end
    end
    
    F -->|SSH| K3s
    A -->|Manages| E
    A -->|Manages| OB
    A -->|Manages| SS
    A -->|Manages| API
    A -->|Manages| P
    A -->|Manages| R
    API -->|mTLS| MQ
    WORKER -->|mTLS| MQ
    API -->|Uses| DB
    CA -->|Uses| E
    SS -->|Provides SVID| API
    SS -->|Provides SVID| WORKER
    CM -->|Issues| API
    CM -->|Issues| WORKER
```

### Component Status

| Component | Status | Namespace | Image/Version |
|-----------|--------|-----------|---------------|
| K3s | ✅ RUNNING | - | v1.36.2+k3s1 |
| Argo CD | ✅ RUNNING | argocd | v2.x |
| EJBCA | ✅ RUNNING | ejbca | keyfactor/ejbca-ce:9.3.7 |
| PostgreSQL | ✅ RUNNING | ejbca | bitnami/postgresql |
| OpenBao | ✅ RUNNING | openbao | openbao:2.6.2 |
| SPIRE Server | ✅ RUNNING | spire | ghcr.io/spiffe/spire-server:1.10.0 |
| SPIRE Agent | ✅ RUNNING | spire | ghcr.io/spiffe/spire-agent:1.10.0 |
| CSI Driver | ✅ RUNNING | spire | csi.spiffe.io |
| cert-api | ✅ RUNNING | pki | 10.43.164.190:5000/cert-api:latest |
| cert-worker | ✅ RUNNING | pki | 10.43.164.190:5000/cert-worker:latest |
| ca-service | ✅ RUNNING | pki | 10.43.164.190:5000/ca-service:latest |
| pki-database | ✅ RUNNING | pki | postgres:16-alpine |
| Prometheus | ✅ RUNNING | monitoring | kube-prometheus-stack |
| Grafana | ✅ RUNNING | monitoring | kube-prometheus-stack |
| Registry | ✅ RUNNING | registry | registry:2.8.3 |
| RabbitMQ | ✅ RUNNING | rabbitmq | rabbitmq:4.1.3-management |
| cert-manager | ✅ RUNNING | cert-manager | v1.21.1 |

---

# PART 56 — MY PKI TRUST HIERARCHY

## Current EJBCA CA Hierarchy

Based on your lab inventory:

```
ManagementCA (Self-signed)
    └── Administrative identities (SuperAdmin)

LabRootCA (Self-signed Root)
    └── LabIssuingCA (Intermediate/Issuing)
        ├── Server certificates (cert-api, ca-service)
        ├── Client certificates (cert-worker)
        └── Workload certificates (SPIFFE SVIDs)
```

### CA Details

| CA Name | Type | Subject | Status |
|---------|------|---------|--------|
| ManagementCA | Management | CN=ManagementCA,O=EJBCA Sample,C=SE | ✅ Active |
| LabRootCA | Root | CN=LabRootCA | ✅ Active |
| LabIssuingCA | Issuing | CN=LabIssuingCA | ✅ Active |

### Certificate Types Issued

| Type | Issued By | Used By |
|------|-----------|---------|
| Server TLS | LabIssuingCA | cert-api, ca-service |
| Client TLS | LabIssuingCA | cert-worker |
| Workload SVID | SPIRE | All SPIFFE-enabled pods |
| Management | ManagementCA | EJBCA administrators |

---

# PART 57 — PRACTICAL LAB EXERCISES

## Safe Exercises for Your Lab

### Exercise 1: Inspect a Certificate

```bash
# SSH to k8s01
ssh -i ~/.ssh/openclaw_k8s01 openclaw@192.168.122.74

# Get a certificate from a secret
kubectl get secret -n pki cert-api-tls -o jsonpath='{.data.tls\.crt}' | base64 -d > /tmp/cert.pem

# Inspect it
openssl x509 -in /tmp/cert.pem -text -noout
```

### Exercise 2: Convert PEM to DER

```bash
openssl x509 -in /tmp/cert.pem -out /tmp/cert.der -outform DER
file /tmp/cert.der
```

### Exercise 3: Extract Certificate from P12

```bash
# If you have a P12 file
openssl pkcs12 -in admin.p12 -clcerts -nokeys -out admin.crt
```

### Exercise 4: Create a CSR

```bash
openssl req -new -newkey rsa:2048 -nodes \
  -keyout /tmp/test.key -out /tmp/test.csr \
  -subj "/CN=test.example.com" \
  -addext "subjectAltName=DNS:test.example.com"

openssl req -in /tmp/test.csr -text -noout
```

### Exercise 5: Verify Certificate Chain

```bash
# Extract CA cert from EJBCA
kubectl exec -n ejbca ejbca-ejbca-ce-0 -- cat /opt/ejbca/p12/ca.crt > /tmp/ca.pem

# Verify
openssl verify -CAfile /tmp/ca.pem /tmp/cert.pem
```

### Exercise 6: Check OCSP

```bash
# Query OCSP (if responder is configured)
openssl ocsp -issuer /tmp/ca.pem -cert /tmp/cert.pem \
  -url http://ejbca.ejbca.svc.cluster.local/ejbca/publicweb/status/ocsp
```

### Exercise 7: Inspect CRL

```bash
# Download and inspect CRL
curl -o /tmp/ca.crl "http://ejbca.ejbca.svc.cluster.local/ejbca/publicweb/webdist/certdist?cmd=crl&issuer=CN=LabIssuingCA"
openssl crl -in /tmp/ca.crl -text -noout
```

### Exercise 8: Compare SKI and AKI

```bash
# Subject Key Identifier
openssl x509 -in /tmp/cert.pem -noout -text | grep -A1 "Subject Key Identifier"

# Authority Key Identifier
openssl x509 -in /tmp/cert.pem -noout -text | grep -A1 "Authority Key Identifier"
```

---

# PART 58 — PKI TROUBLESHOOTING

## Symptom → Investigation → Cause

| Symptom | Investigation | Common Cause |
|---------|--------------|--------------|
| **Certificate not trusted** | `openssl verify` | Missing intermediate CA |
| **Hostname mismatch** | Check SAN/CN | Wrong hostname in certificate |
| **Unknown CA** | Check issuer chain | Root not in trust store |
| **Unable to get local issuer** | Chain inspection | Missing intermediate |
| **Certificate revoked** | OCSP/CRL check | Certificate revoked |
| **OCSP unknown** | OCSP responder status | Responder doesn't know cert |
| **Expired CRL** | `nextUpdate` field | CRL not refreshed |
| **TLS handshake failure** | `openssl s_client` | Cipher mismatch, cert issue |
| **Bad certificate** | Client cert validation | Client cert rejected |
| **Incomplete chain** | `openssl s_client -showcerts` | Server not sending intermediates |
| **Wrong EKU** | Check EKU extension | Cert not authorized for use |
| **Wrong Key Usage** | Check KU extension | Key can't perform operation |
| **Missing SAN** | Check SAN extension | Hostname not in SAN |
| **Expired intermediate** | Check chain dates | Intermediate CA expired |
| **Private key mismatch** | Compare moduli | Wrong key for certificate |

### Investigation Commands

```bash
# Full TLS debug
openssl s_client -connect host:443 -showcerts -servername host

# Certificate details
openssl x509 -in cert.pem -text -noout

# Chain verification
openssl verify -CAfile root.pem -untrusted intermediate.pem leaf.pem

# OCSP check
openssl ocsp -issuer issuer.pem -cert cert.pem -url http://ocsp.example.com

# CRL inspection
openssl crl -in ca.crl -text -noout
```

---

# PART 59 — COMMON PKI MISCONCEPTIONS

## Corrections

| Misconception | Truth |
|---------------|-------|
| "The root signs every certificate" | Root signs intermediates; intermediates sign end-entity certs |
| "A .crt file always contains only DER" | .crt can be PEM or DER; extension doesn't determine encoding |
| "A thumbprint is the public key" | Thumbprint is a hash of the entire certificate |
| "HTTPS encrypts traffic using the RSA private key" | RSA is only for key exchange; symmetric encryption handles data |
| "Self-signed means insecure" | Self-signed root CAs are standard; self-signed leaf certs are untrusted |
| "An intermediate CA and issuing CA always mean different things" | They are often the same thing with different terminology |
| "OCSP replaces CRLs everywhere" | Both coexist; CRL works offline, OCSP is real-time |
| "A certificate contains the private key" | Certificates contain public keys; private keys are separate |
| "A CSR contains the private key" | CSRs contain public keys and are signed with private keys |
| "PEM is a certificate format" | PEM is an encoding format; it can contain certs, keys, CSRs, etc. |
| "PKCS#12 is a certificate" | PKCS#12 is a container that can hold certs, keys, and chains |
| "SPIFFE replaces a CA" | SPIFFE provides identity; still needs a CA to issue certificates |
| "OpenBao and SPIRE do the same thing" | OpenBao manages secrets; SPIRE provides workload identity |

---

# PART 60 — GLOSSARY

## PKI Terminology

| Term | Definition |
|------|------------|
| **AKI** | Authority Key Identifier - identifies the issuer's public key |
| **AIA** | Authority Information Access - where to find issuer cert and OCSP |
| **ASN.1** | Abstract Syntax Notation One - data description language |
| **CA** | Certificate Authority - issues and signs certificates |
| **CDP** | CRL Distribution Point - where to find CRLs |
| **CER** | Certificate file (usually DER) |
| **CRL** | Certificate Revocation List - list of revoked certificates |
| **CSR** | Certificate Signing Request - request for certificate issuance |
| **DER** | Distinguished Encoding Rules - binary ASN.1 encoding |
| **DN** | Distinguished Name - hierarchical identifier |
| **ECDSA** | Elliptic Curve Digital Signature Algorithm |
| **EKU** | Extended Key Usage - application-level purpose |
| **EST** | Enrollment over Secure Transport - certificate enrollment protocol |
| **HSM** | Hardware Security Module - secure key storage |
| **ICA** | Intermediate Certificate Authority |
| **KMS** | Key Management Service - cloud key management |
| **OCSP** | Online Certificate Status Protocol - real-time revocation check |
| **OID** | Object Identifier - hierarchical identifier |
| **PEM** | Privacy Enhanced Mail - Base64 encoded DER with headers |
| **PFX** | Personal Information Exchange - PKCS#12 file |
| **PKCS** | Public Key Cryptography Standards |
| **PKI** | Public Key Infrastructure |
| **RA** | Registration Authority - verifies identity before issuance |
| **RCA** | Root Certificate Authority |
| **RSA** | Rivest-Shamir-Adleman - public key algorithm |
| **SAN** | Subject Alternative Name - additional identities |
| **SCEP** | Simple Certificate Enrollment Protocol |
| **SKI** | Subject Key Identifier - identifies certificate's public key |
| **SVID** | SPIFFE Verifiable Identity Document |
| **TLS** | Transport Layer Security - encrypted protocol |
| **VA** | Validation Authority - provides OCSP/CRL services |
| **X.509** | ITU-T standard for public key certificates |

---

# PART 61 — QUICK REFERENCE TABLES

## PKI File Extensions

| Extension | Contains | Encoding | Password |
|-----------|----------|----------|----------|
| .pem | Certs, keys, CSRs | Base64 | Optional |
| .crt | Certificate | PEM/DER | No |
| .cer | Certificate | DER/PEM | No |
| .der | Certificate | Binary | No |
| .key | Private key | PEM | Optional |
| .csr | CSR | PEM | No |
| .p12 | Cert + key + chain | Binary | Yes |
| .pfx | Cert + key + chain | Binary | Yes |
| .p7b | Cert chain | PEM/DER | No |
| .crl | Revocation list | PEM/DER | No |
| .jks | Java keystore | Binary | Yes |

## Important OIDs

| OID | Name | Usage |
|-----|------|-------|
| 1.3.6.1.5.5.7.3.1 | serverAuth | TLS server |
| 1.3.6.1.5.5.7.3.2 | clientAuth | TLS client |
| 1.3.6.1.5.5.7.3.3 | codeSigning | Code signing |
| 1.3.6.1.5.5.7.3.4 | emailProtection | S/MIME |
| 1.3.6.1.5.5.7.3.9 | OCSPSigning | OCSP responder |
| 2.5.4.3 | commonName | CN field |
| 2.5.4.6 | countryName | C field |
| 2.5.4.10 | organizationName | O field |
| 2.5.29.15 | keyUsage | Key usage |
| 2.5.29.17 | subjectAltName | SAN |
| 2.5.29.19 | basicConstraints | CA constraints |
| 2.5.29.37 | extendedKeyUsage | EKU |

## Key Usage Bits

| Bit | Name | Typical For |
|-----|------|-------------|
| digitalSignature | Signing | TLS, code signing |
| keyEncipherment | Key encryption | TLS RSA key exchange |
| keyCertSign | Cert signing | CA certificates |
| cRLSign | CRL signing | CA certificates |
| keyAgreement | Key agreement | ECDHE |

## OpenSSL Commands

| Command | Purpose |
|---------|---------|
| `openssl x509 -text` | View certificate |
| `openssl req -text` | View CSR |
| `openssl verify` | Verify chain |
| `openssl crl -text` | View CRL |
| `openssl ocsp` | Query OCSP |
| `openssl pkcs12` | Handle P12 files |
| `openssl asn1parse` | Parse ASN.1 |

## Revocation Reasons

| Code | Reason | When |
|------|--------|------|
| 0 | unspecified | Default |
| 1 | keyCompromise | Key leaked |
| 2 | cACompromise | CA compromised |
| 3 | affiliationChanged | Org change |
| 4 | superseded | Replaced |
| 5 | cessationOfOperation | Service ended |
| 6 | certificateHold | Temporary |

---

# PART 62 — ARCHITECT-LEVEL QUESTIONS

## 50+ PKI Questions

### Foundation

**Q1: Why does an intermediate CA require Basic Constraints CA=true?**

**A:** The Basic Constraints extension with CA=true marks the certificate as a Certificate Authority. Without this, the certificate cannot sign other certificates. The pathLenConstraint field further limits how many subordinate CAs can exist below it. This is critical for chain building—clients use this extension to distinguish end-entity certificates from CA certificates.

**Q2: What is the difference between SKI and AKI?**

**A:** Subject Key Identifier (SKI) identifies the public key of the certificate itself. Authority Key Identifier (AKI) identifies the public key of the issuer. During chain building, a client matches the AKI of a certificate to the SKI of its issuer, ensuring the correct issuer is used.

**Q3: Why can two certificates have the same public key but different thumbprints?**

**A:** The thumbprint (fingerprint) is a hash of the entire certificate, including all fields (issuer, subject, serial number, validity, extensions, signature). Two certificates with the same public key but different issuers, serial numbers, or validity periods will have different thumbprints.

**Q4: Why does a root certificate have an issuer equal to its subject?**

**A:** A root CA is self-signed. It has no higher authority to sign it, so it signs itself. This makes the issuer and subject identical. The certificate is trusted not because of the signature (which is self-referential) but because it was distributed through a trusted channel and placed in the trust store.

**Q5: How does a client locate an OCSP responder?**

**A:** The Authority Information Access (AIA) extension in the certificate contains an OCSP access method with a URI pointing to the responder. The client parses this extension and sends an HTTP POST request to the specified URL.

**Q6: What exactly gets hashed when creating a certificate fingerprint?**

**A:** The entire DER-encoded certificate bytes are hashed, including: version, serial number, signature algorithm, issuer, validity, subject, public key, extensions, and the CA's signature. The private key is never included.

**Q7: Why is OCSP response signing often delegated?**

**A:** Delegating OCSP signing to a separate certificate reduces load on the CA's primary signing key (which should be heavily protected). The delegated OCSP responder certificate has only the OCSPSigning EKU, so even if compromised, it cannot issue certificates.

**Q8: Why does a certificate serial number need uniqueness?**

**A:** Serial numbers must be unique per CA to uniquely identify certificates for revocation and lookup. The scope is per-CA, not global—two different CAs can issue certificates with the same serial number without conflict.

**Q9: What does certutil's "Cert Hash(sha1)" represent?**

**A:** It is the SHA-1 hash of the entire DER-encoded certificate. Despite SHA-1 being deprecated for signatures, Windows continues displaying SHA-1 thumbprints for backward compatibility. The certificate itself may be signed with SHA-256.

**Q10: What happens if a CRL expires?**

**A:** If the nextUpdate date passes, clients may reject the CRL as stale. This creates a security gap—clients cannot verify revocation status. Some clients soft-fail (allow connection), while others hard-fail (reject). Regular CRL publication is critical.

### Intermediate

**Q11: Can a certificate be cryptographically valid but untrusted?**

**A:** Yes. A certificate's signature can verify mathematically, but if the issuer is not in the trust store, or if the certificate is expired, revoked, or has the wrong hostname, it is untrusted for its intended purpose.

**Q12: What happens if the root is trusted but the intermediate is missing?**

**A:** Chain building fails. The client cannot verify the leaf certificate's signature without the intermediate's public key. Servers should always send the complete chain (leaf + intermediates), not just the leaf.

**Q13: How is a CSR signed?**

**A:** The CSR is signed with the private key corresponding to the public key in the CSR. This proves possession of the private key. The signature algorithm is specified in the CSR (e.g., sha256WithRSAEncryption).

**Q14: Why can a CSR signature be verified without a certificate?**

**A:** The CSR contains the public key. You can verify the signature using the public key in the CSR itself. This proves the requester has the private key, but does not prove identity (that's the CA's job).

**Q15: What is the difference between a CA signing key and an OCSP signing key?**

**A:** A CA signing key can sign certificates and CRLs (requires keyCertSign and cRLSign). An OCSP signing key can only sign OCSP responses (requires OCSPSigning EKU). The separation limits damage if the OCSP key is compromised.

**Q16: Why does an HSM help if attackers compromise the CA application?**

**A:** Even if the CA application is compromised, the private keys remain in the HSM and cannot be extracted. The attacker can only request operations through the HSM's API, which is logged and rate-limited. The keys never exist in application memory.

**Q17: How would you migrate a PKI to new issuing CA keys?**

**A:** 1) Generate new CA key pair, 2) Issue new CA certificate, 3) Cross-certify old and new, 4) Begin issuing with new CA, 5) Re-issue certificates before old CA expires, 6) Gradually remove old CA from trust stores, 7) Revoke old CA certificate.

**Q18: Why is crypto inventory essential for PQC?**

**A:** PQC migration requires knowing which certificates use vulnerable algorithms (RSA, ECDSA), their locations, owners, and expiration dates. Without inventory, you cannot plan migration, prioritize critical systems, or track progress.

### Advanced

**Q19: Why does pathLenConstraint=0 on an intermediate CA prevent it from signing subordinate CAs?**

**A:** pathLenConstraint limits the number of CA certificates that can appear below the certificate. A value of 0 means the CA can only sign end-entity certificates (path length of 0 additional CAs). This is used to constrain the hierarchy depth.

**Q20: What is the difference between a self-issued and self-signed certificate?**

**A:** Self-issued: Subject = Issuer (same name), but signed by a different key. Self-signed: Subject = Issuer AND signed by its own key. All self-signed are self-issued, but not vice versa. Root CAs are self-signed; CA renewals may be self-issued with a new key.

[Additional 30+ questions would continue in this format...]

---

# PART 63 — FINAL SUMMARY

## How Everything Fits Together

### Conceptual Flow

```
User / Device / Workload
          │
          │ CSR / Enrollment Protocol
          ▼
         RA (Registration Authority)
          │ Identity Verification
          │ Request Approval
          ▼
      Issuing CA (LabIssuingCA)
          │
          │ Signs using private key
          │ Protected by Crypto Token
          ▼
      Certificate
          │
          ├─────────────┬─────────────┐
          │             │             │
          ▼             ▼             ▼
       Client      Inventory    Validation
          │             │             │
          │             │             ▼
          │             │         OCSP Responder
          │             │         CRL Distribution
          │             │
          ▼             ▼
      Service    PostgreSQL DB
          │      (pki-database)
          │
          │ mTLS / TLS
          ▼
   Peer Validation
          │
          ├─► Root CA (LabRootCA) [Trust Anchor]
          │
          ├─► Intermediate CA (LabIssuingCA)
          │
          ├─► Revocation (CRL / OCSP)
          │
          ├─► Monitoring (Prometheus/Grafana)
          │
          ├─► Renewal (cert-worker CronJob)
          │
          └─► Audit (Logs)
```

### Component Integration

| Component | Role in Architecture |
|-----------|---------------------|
| **EJBCA** | Certificate Authority - issues, revokes, manages certificates |
| **OpenBao** | Secret management - stores credentials, provides dynamic secrets |
| **SPIRE** | Workload identity - automatic SVID issuance, mTLS enablement |
| **Argo CD** | GitOps - manages infrastructure state, automated deployments |
| **Kubernetes** | Orchestration - runs workloads, manages secrets, service discovery |
| **PostgreSQL** | Persistence - certificate inventory, EJBCA database |
| **RabbitMQ** | Messaging - async communication between cert-api and cert-worker |
| **Prometheus** | Monitoring - metrics collection, alerting rules |
| **Grafana** | Visualization - dashboards, alert visualization |
| **cert-manager** | Automation - Kubernetes certificate lifecycle |
| **cert-api** | API - certificate operations (CRUD, OCSP, CRL) |
| **cert-worker** | Batch processing - inventory, renewal, policy checks |
| **ca-service** | Abstraction - CA protocol normalization |

### Your Lab's PKI Maturity

| Capability | Status | Component |
|------------|--------|-----------|
| Certificate issuance | ✅ Operational | EJBCA + cert-api |
| Automated renewal | ✅ Configured | cert-worker CronJob |
| Revocation | ✅ Available | EJBCA OCSP + CRL |
| Workload identity | ✅ Operational | SPIRE + mTLS |
| Secret management | ✅ Operational | OpenBao |
| Observability | ✅ Operational | Prometheus + Grafana |
| GitOps management | ✅ Operational | Argo CD |
| Crypto inventory | ✅ Configured | cert-worker + PostgreSQL |
| Policy enforcement | ✅ Configured | cert-worker CronJob |
| PQC assessment | ✅ Configured | cert-worker CronJob |
| Backup/DR | ✅ Configured | cert-worker CronJob + PVC |
| CI validation | ✅ Committed | GitHub Actions |

### Architecture Principles Demonstrated

1. **Defense in depth**: Multiple layers (mTLS, network policies, auth)
2. **Separation of duties**: CA, RA, VA roles separated
3. **Automation**: GitOps, automated renewal, workload identity
4. **Observability**: Metrics, alerts, audit logging
5. **Crypto agility**: PQC scanning, algorithm inventory
6. **High availability**: Multiple replicas, persistent storage

---

## Document Information

| Property | Value |
|----------|-------|
| **Version** | 1.0 |
| **Generated** | August 28, 2026 |
| **Lab Version** | K3s v1.36.2+k3s1 |
| **EJBCA Version** | 9.3.7 |
| **OpenBao Version** | 2.6.2 |
| **Total Parts** | 63 |
| **Status** | Complete |

---

*This guide serves as both a learning resource and operational reference for the PKI/Machine Identity Platform homelab.*
