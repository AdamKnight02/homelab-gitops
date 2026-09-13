#!/usr/bin/env python3
"""
RabbitMQ Producer Demo
Sends tasks to a queue for workers to process
"""
import pika
import json
import sys
import time

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

def send_task(task_type, data):
    """Send a task to the queue"""
    connection = get_connection()
    channel = connection.channel()
    
    # Create queue if it doesn't exist (durable = survives restart)
    channel.queue_declare(queue='task_queue', durable=True)
    
    message = {
        'task_type': task_type,
        'data': data,
        'timestamp': time.time()
    }
    
    # persistent=True = message survives RabbitMQ restart
    channel.basic_publish(
        exchange='',
        routing_key='task_queue',
        body=json.dumps(message),
        properties=pika.BasicProperties(
            delivery_mode=2,  # persistent
        )
    )
    
    print(f" [x] Sent {task_type}: {data}")
    connection.close()

if __name__ == '__main__':
    # Example: send some tasks
    tasks = [
        ('process_order', {'order_id': '12345', 'amount': 99.99}),
        ('send_email', {'to': 'user@example.com', 'template': 'welcome'}),
        ('generate_report', {'type': 'daily', 'date': '2026-08-22'}),
    ]
    
    for task_type, data in tasks:
        send_task(task_type, data)
        time.sleep(1)
    
    print(" [+] All tasks sent!")
