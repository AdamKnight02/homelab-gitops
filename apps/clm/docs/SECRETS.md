# CLM bootstrap secrets (manual, Argo-exempt)

Secrets are **never committed to Git**. They are transferred once from the
source cluster (cluster-4070) to the target (k8s01) during migration stage 4
via a cluster-to-cluster YAML pipe — values are never displayed or stored
outside the two clusters. Argo apps do not manage these objects; they are
pre-created before the first sync of `clm-platform` / `clm-ejbca` / `clm-app`.

## Namespace `clm`

| Secret | Keys | Consumed by |
|---|---|---|
| `clm-postgres-auth` | postgres-password, migrator-password, app-password, database-url, migration-database-url, **ejbca-password** (new on target; same value as `ejbca-db-auth/password`) | clm-postgres, clm-api, workers, scheduler |
| `clm-rabbitmq-auth` | username, password, erlang-cookie, amqp-url | clm-rabbitmq, api, workers, scheduler |
| `clm-api-auth` | platform-api-key | clm-api |
| `clm-internal-auth` | internal-token | clm-api **and** clm-ui |
| `clm-auth0` | domain, client-id, client-secret, session-secret | clm-ui |
| `clm-cloudflare-auth` | api-token | worker-issuance (ACME DNS-01) |
| `cloudflared-token` | token | cloudflared |
| `ejbca-clm-api` | client.p12, p12-password, ca-chain.pem | worker-issuance (EJBCA mTLS) |
| `clm-acme-account-key` | tls.key | LE **staging** account |
| `clm-acme-account-url` | tls.key | LE staging account URL |
| `clm-acme-account-prod-key` | tls.key | LE **prod** account |
| `clm-acme-account-prod-url` | tls.key | LE prod account URL |
| `clm-key-<uuid>` × ~36 | private key material for issued certificates | workers (keystore) |

## Namespace `ejbca`

| Secret | Keys | Consumed by |
|---|---|---|
| `ejbca-db-auth` | username, password | ejbca (DB login; value duplicated as `clm-postgres-auth/ejbca-password`) |

## Transfer method (values never printed)

```bash
# run from a shell with BOTH kubeconfigs available
SRC="kubectl --kubeconfig=<4070>"; DST="kubectl --kubeconfig=<k8s01>"
for s in clm-postgres-auth clm-rabbitmq-auth clm-api-auth clm-internal-auth \
         clm-auth0 clm-cloudflare-auth cloudflared-token ejbca-clm-api \
         clm-acme-account-key clm-acme-account-url \
         clm-acme-account-prod-key clm-acme-account-prod-url; do
  $SRC -n clm get secret "$s" -o json | jq 'del(.metadata.resourceVersion,.metadata.uid,.metadata.creationTimestamp,.metadata.ownerReferences,.metadata.annotations)' | $DST -n clm apply -f -
done
$SRC -n ejbca get secret ejbca-db-auth -o json | jq 'del(...same...)' | $DST -n ejbca apply -f -
# keystore secrets:
$SRC -n clm get secrets -o json | jq '.items[] | select(.metadata.name|startswith("clm-key-"))' ...
# then: add key ejbca-password to clm-postgres-auth (same value as ejbca-db-auth/password)
```

## Not migrated (re-derived by CLM)

- `app1-tls`, `api-smoke-*-tls`, `wildcard-ks-*-tls` — deployment-target state;
  the verification worker re-deploys from certificate instances after restore.
- RabbitMQ queues — topology is re-declared idempotently by the apps.
