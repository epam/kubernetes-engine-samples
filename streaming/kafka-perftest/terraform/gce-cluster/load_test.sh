#!/bin/bash
set -e  

export PATH=$PATH:/opt/kafka/bin
BOOTSTRAP_SERVERS="gce-kafka-broker-0:9092,gce-kafka-broker-1:9092,gce-kafka-broker-2:9092"

# Topic name
TOPIC_NAME="test-topic"

# Ensure script is executed in a clean directory for logs
LOG_DIR="/tmp/kafka-logs-perf"
mkdir -p $LOG_DIR

echo "========== Starting Kafka Performance Test Script =========="

# Step 1: Create the topic
echo "=== Creating topic: $TOPIC_NAME ==="
kafka-topics.sh --bootstrap-server=gce-kafka-broker-0:9092 \
    --topic $TOPIC_NAME \
    --create \
    --partitions=3 \
    --replication-factor=3
echo "=== Topic $TOPIC_NAME created ==="

# Step 2: Produce messages 3 times
echo "=== Starting Producer Performance Test (3 Runs) ==="
for run in {1..3}; do
    echo "=== Producer Run $run ==="
    kafka-producer-perf-test.sh \
        --topic $TOPIC_NAME \
        --num-records 50000000 \
        --record-size 1000 \
        --throughput -1 \
        --producer-props bootstrap.servers=$BOOTSTRAP_SERVERS \
            acks=1 \
            batch.size=10000 \
            linger.ms=100 \
            compression.type=snappy \
        > "$LOG_DIR/producer-run-$run.log" 2>&1
    echo "=== Producer Run $run Complete ==="
done

# Step 3: Consume messages 3 times
echo "=== Starting Consumer Performance Test (3 Runs) ==="
for run in {1..3}; do
    echo "=== Consumer Run $run ==="
    kafka-consumer-perf-test.sh \
        --topic $TOPIC_NAME \
        --messages 50000000 \
        --bootstrap-server gce-kafka-broker-0:9092 \
        > "$LOG_DIR/consumer-run-$run.log" 2>&1
    echo "=== Consumer Run $run Complete ==="
done

# Step 4: Delete the topic
echo "=== Deleting topic: $TOPIC_NAME ==="
kafka-topics.sh --bootstrap-server=gce-kafka-broker-0:9092 \
    --topic $TOPIC_NAME \
    --delete
echo "=== Topic $TOPIC_NAME deleted ==="

# Step 5: Sleep for 3 minutes before proceeding
echo "=== Sleeping for 3 minutes... ==="
sleep 3m
echo "=== Sleep complete. ==="

# Step 6: Recreate the topic
echo "=== Recreating topic: $TOPIC_NAME ==="
kafka-topics.sh --bootstrap-server=gce-kafka-broker-0:9092 \
    --topic $TOPIC_NAME \
    --create \
    --partitions=3 \
    --replication-factor=3
echo "=== Topic $TOPIC_NAME recreated ==="

# Step 7: Run producer 1 last time
echo "=== Starting Producer Performance Test (1 Final Run) ==="
kafka-producer-perf-test.sh \
    --topic $TOPIC_NAME \
    --num-records 50000000 \
    --record-size 1000 \
    --throughput -1 \
    --producer-props bootstrap.servers=$BOOTSTRAP_SERVERS \
        acks=1 \
        batch.size=10000 \
        linger.ms=100 \
        compression.type=snappy \
    > "$LOG_DIR/producer-final-run.log" 2>&1
echo "=== Final Producer Run Complete ==="

echo "========== Kafka Performance Test Script Complete =========="