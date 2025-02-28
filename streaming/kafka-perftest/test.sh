#/bin/sh

[ "$#" -ne 1 ] && echo "USAGE $0 <BOOTSTRAP_SERVERS>" && exit
# First argument 
BOOTSTRAP_SERVERS=$1


NUMRECORDS=5000000

# Topic name
TOPIC_NAME="test-topic"

echo

# Step 1: Create the topic
echo "=== Creating topic: $TOPIC_NAME ==="
/opt/kafka/bin/kafka-topics.sh --bootstrap-server=$BOOTSTRAP_SERVERS \
    --topic $TOPIC_NAME \
    --create \
    --partitions=3 \
    --replication-factor=3

sleep 10

# Step 2: End-to-end test
echo "=== End-to-End test ==="
/opt/kafka/bin/kafka-run-class.sh \
    org.apache.kafka.tools.EndToEndLatency \
    $BOOTSTRAP_SERVERS \
     $TOPIC_NAME 10000 1 1000
echo "=== End-to-End test complete ==="

# Step 3: non-batched Producer Performance Test
echo "=== Starting non-batched Producer Performance Test ==="
    /opt/kafka/bin/kafka-producer-perf-test.sh \
    --topic  $TOPIC_NAME \
    --num-records 1000000 \
    --record-size 1000 \
    --throughput -1 \
    --producer-props bootstrap.servers=$BOOTSTRAP_SERVERS \
    acks=1 \
    batch.size=1 \
    linger.ms=100 \
    compression.type=snappy 
echo "=== Non-batched Producer Performance Test ==="

# Step 4: Batched Producer Performance Test
echo "=== Starting batched Producer Performance Test ==="
/opt/kafka/bin/kafka-producer-perf-test.sh \
    --topic  $TOPIC_NAME \
    --num-records 5000000 \
    --record-size 1000 \
    --throughput -1 \
    --producer-props bootstrap.servers=$BOOTSTRAP_SERVERS \
    acks=1 \
    batch.size=10000 \
    linger.ms=100 \
    compression.type=snappy 
echo "=== Batched Producer Performance Test Complete ==="


# Step 5: Throttled Producer Performance Test
echo "=== Starting Throttled Producer Performance Test ==="

/opt/kafka/bin/kafka-producer-perf-test.sh \
    --topic  $TOPIC_NAME \
    --num-records 1500000 \
    --record-size 1000 \
    --throughput 50000 \
    --producer-props bootstrap.servers=$BOOTSTRAP_SERVERS \
    acks=1 \
    batch.size=10000 \
    linger.ms=100 \
    compression.type=snappy

echo "=== Throttled Producer Run Complete ==="

# Step 6: Consume messages 3 times
echo "=== Starting Consumer Performance Test ==="

/opt/kafka/bin/kafka-consumer-perf-test.sh \
    --topic  $TOPIC_NAME \
    --messages $NUMRECORDS \
    --bootstrap-server $BOOTSTRAP_SERVERS 

echo "=== Consumer Performance Test Complete ==="

# delete topic
echo "=== Deleting topic: $TOPIC_NAME ==="
  /opt/kafka/bin/kafka-topics.sh --bootstrap-server=$BOOTSTRAP_SERVERS --topic  $TOPIC_NAME --delete

