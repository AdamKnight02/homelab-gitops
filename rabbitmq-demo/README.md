# RabbitMQ + OpenBao Integration Demo

## What This Shows

This demo demonstrates how your apps can:
1. **Queue tasks** in RabbitMQ (async processing)
2. **Process tasks** with scalable workers
3. **Fetch secrets** from OpenBao at runtime

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Producer   │────▶│   RabbitMQ  │────▶│   Worker    │
│  (Job)      │     │   Queue     │     │  (Deployment)│
└─────────────┘     └─────────────┘     └──────┬──────┘
                                                │
                                         ┌──────┴──────┐
                                         │   OpenBao   │
                                         │  (secrets)  │
                                         └─────────────┘
```

## Components

### Producer (`producer.py`)
- Sends 3 tasks to RabbitMQ queue
- Runs as a Kubernetes Job (one-time execution)
- Tasks are persistent (survive RabbitMQ restart)

### Consumer/Worker (`consumer.py`)
- Runs continuously, waiting for tasks
- Scales horizontally (replicas: 2)
- Fetches DB credentials from OpenBao conceptually
- Acknowledges messages only after successful processing

### Integration Points

| Feature | How It Works |
|---------|-------------|
| **RabbitMQ** | `rabbitmq.rabbitmq.svc.cluster.local:5672` |
| **OpenBao** | `https://openbao.openbao.svc.cluster.local:8200` |
| **Argo CD** | Watches Git repo, auto-deploys changes |
| **Scaling** | Increase `replicas` in worker Deployment |

## How It Works

### 1. Producer Sends Tasks
```python
message = {
    'task_type': 'process_order',
    'data': {'order_id': '12345', 'amount': 99.99},
    'timestamp': time.time()
}
```

### 2. RabbitMQ Stores Tasks
- Queue is `durable` (survives restart)
- Messages are `persistent` (survive restart)
- Fair dispatch: workers get 1 task at a time

### 3. Worker Processes Tasks
```python
def process_task(body):
    # 1. Parse message
    # 2. Fetch secret from OpenBao (conceptually)
    # 3. Do the work
    # 4. Acknowledge (remove from queue)
```

### 4. Error Handling
- Success: `basic_ack()` → message removed
- Failure: `basic_nack(requeue=True)` → retry later

## Deploy It

```bash
# Deploy everything
kubectl apply -f k8s-deployment.yaml

# Watch workers process tasks
kubectl logs -n rabbitmq-demo -l app=rabbitmq-worker -f

# Check queue status
kubectl exec -n rabbitmq rabbitmq-0 -- rabbitmqctl list_queues
```

## Scale Workers

```bash
# Scale to 5 workers
kubectl scale deployment rabbitmq-worker -n rabbitmq-demo --replicas=5
```

## Real-World Use Cases

1. **Certificate Requests**
   - App receives CSR → queues "issue-cert" task
   - Worker fetches EJBCA creds from OpenBao → issues cert
   - Worker publishes "cert-ready" event

2. **Email Notifications**
   - User signs up → queues "send-welcome-email" task
   - Worker sends email via SMTP
   - No delay for user

3. **Report Generation**
   - Admin requests report → queues task
   - Worker generates large PDF (takes minutes)
   - Admin gets notification when done

## Next Steps

- Add proper OpenBao Kubernetes auth
- Add Prometheus metrics
- Add dead-letter queue for failed tasks
- Use Argo CD to deploy from Git
