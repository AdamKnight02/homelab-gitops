#!/usr/bin/env python3
"""
RabbitMQ Consumer/Worker Demo
Processes tasks from the queue
"""
import pika
import json
import time
import requests
import os

def get_connection():
    """Connect to RabbitMQ"""
    credentials = pika.PlainCredentials('admin', 'admin123')
    parameters = pika.ConnectionParameters(
        host='rabbitmq.rabbitmq.svc.cluster.local',
        port=5672,
        credentials=credentials,
        connection_attempts=5,
        retry_delay=5
    )
    return pika.BlockingConnection(parameters)

def get_secret_from_openbao(secret_path):
    """
    Fetch a secret from OpenBao
    In real app, you'd use proper auth (Kubernetes auth, AppRole, etc.)
    """
    try:
        # This is simplified - real apps use proper Vault client with auth
        bao_addr = os.getenv('BAO_ADDR', 'https://openbao.openbao.svc.cluster.local:8200')
        
        # For demo, we'll just show the concept
        # Real implementation would authenticate and read secret
        print(f"    [OpenBao] Would fetch secret from: {bao_addr}/v1/secret/data/{secret_path}")
        return {'username': 'demo_user', 'password': 'demo_pass'}
    except Exception as e:
        print(f"    [OpenBao] Error: {e}")
        return None

def process_task(body):
    """Process a task"""
    message = json.loads(body)
    task_type = message['task_type']
    data = message['data']
    
    print(f" [→] Processing {task_type}: {data}")
    
    # Simulate work
    time.sleep(2)
    
    # Example: if task needs DB credentials, fetch from OpenBao
    if task_type == 'process_order':
        db_creds = get_secret_from_openbao('database/orders')
        print(f"    [DB] Connected with user: {db_creds['username']}")
        print(f"    [DB] Processing order {data['order_id']} for ${data['amount']}")
    
    elif task_type == 'send_email':
        print(f"    [Email] Sending {data['template']} email to {data['to']}")
    
    elif task_type == 'generate_report':
        print(f"    [Report] Generating {data['type']} report for {data['date']}")
    
    print(f" [✓] Completed {task_type}")

def callback(ch, method, properties, body):
    """Called when message received"""
    try:
        process_task(body)
        # Acknowledge = remove from queue (only if processed successfully)
        ch.basic_ack(delivery_tag=method.delivery_tag)
    except Exception as e:
        print(f" [✗] Error: {e}")
        # Negative ack = requeue message for retry
        ch.basic_nack(delivery_tag=method.delivery_tag, requeue=True)

def main():
    connection = get_connection()
    channel = connection.channel()
    
    channel.queue_declare(queue='task_queue', durable=True)
    
    # Fair dispatch = don't give more than 1 task at a time to a worker
    channel.basic_qos(prefetch_count=1)
    
    # Start consuming
    channel.basic_consume(queue='task_queue', on_message_callback=callback)
    
    print(' [*] Waiting for tasks. To exit press CTRL+C')
    channel.start_consuming()

if __name__ == '__main__':
    main()
