#!/bin/bash

if [ -z "$1" ]; then
    echo "Error: Machine type argument is required."
    echo "Usage: $0 <MACHINE_TYPE>"
    exit 1
fi

NUMRECORDS=60000000
BOOTSTRAP_SERVERS="broker-0.kafka-perf.test:9092,broker-1.kafka-perf.test:9092,broker-2.kafka-perf.test:9092"
BOOTSTRAP_SINGLE="broker-0.kafka-perf.test:9092"

TEST_RESULTS=testresults.txt
TEST_RESULTS_CSV=testresults.csv

PD_FILE_SYSTEM="ext4"
MACHINE_TYPE=$1

# Topic name
TOPIC_NAME="test-topic"

echo "Kafka performance test" >$TEST_RESULTS
echo "Machine type: $MACHINE_TYPE" >>$TEST_RESULTS
echo "PD filesystem, $PD_FILE_SYSTEM" >>$TEST_RESULTS
echo "Test date and time: $(date '+%Y-%m-%d %H:%M:%S')" >>$TEST_RESULTS

echo "Machine type,$MACHINE_TYPE" >$TEST_RESULTS_CSV
echo "PD filesystem, $PD_FILE_SYSTEM" >>$TEST_RESULTS_CSV
echo "Test date and time, $(date '+%Y-%m-%d %H:%M:%S')" >>$TEST_RESULTS_CSV
echo >>$TEST_RESULTS_CSV

exec > >(tee -a "$TEST_RESULTS") 2>&1

for i in {1..3} 
do
echo
# Step 1: Create the topic
echo "=== Creating topic: $TOPIC_NAME ==="
/opt/kafka/bin/kafka-topics.sh --bootstrap-server=$BOOTSTRAP_SINGLE \
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
    --print-metrics \
    --num-records 1000000 \
    --record-size 1000 \
    --throughput -1 \
    --producer-props bootstrap.servers=$BOOTSTRAP_SERVERS \
    acks=1 \
    batch.size=1 \
    linger.ms=5 \
    compression.type=snappy 
echo "=== Non-batched Producer Performance Test ==="

# Step 4: Batched Producer Performance Test
echo "=== Starting batched Producer Performance Test ==="
/opt/kafka/bin/kafka-producer-perf-test.sh \
    --topic  $TOPIC_NAME \
    --print-metrics \
    --num-records $NUMRECORDS \
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
    --print-metrics \
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
    --bootstrap-server $BOOTSTRAP_SINGLE 

echo "=== Consumer Performance Test Complete ==="

# delete topic
echo "=== Deleting topic: $TOPIC_NAME ==="
  /opt/kafka/bin/kafka-topics.sh --bootstrap-server=$BOOTSTRAP_SINGLE --topic  $TOPIC_NAME --delete

    # Restart Kafka Broker Instances using gcloud CLI
    echo "Restarting Kafka brokers for a fresh state..."

    INSTANCE_IDS=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=broker-*" \
              "Name=instance-state-name,Values=running,stopped" \
        --query 'Reservations[].Instances[].InstanceId' \
        --output text)
    echo "Stopping instances: $INSTANCE_IDS"    
    aws ec2 stop-instances --instance-ids $INSTANCE_IDS
    echo "Waiting for instances to stop..."
    aws ec2 wait instance-stopped --instance-ids $INSTANCE_IDS
    echo "Starting instances: $INSTANCE_IDS"
    aws ec2 start-instances --instance-ids $INSTANCE_IDS
    sleep 90
done

echo "End-to-End Performance Test" >>$TEST_RESULTS_CSV
echo "Avg latency" >>$TEST_RESULTS_CSV
cat $TEST_RESULTS | grep "Avg latency" | sed 's/[^0-9.]/ /g' | tr -s ' '  >>$TEST_RESULTS_CSV
echo "Percentiles:" >>$TEST_RESULTS_CSV
echo "50th, 99th, 99.9th" >>$TEST_RESULTS_CSV
cat $TEST_RESULTS | grep "Percentiles:" | sed 's/50th//g; s/95th//g; s/99th//g; s/99\.9th//g'|sed 's/[^0-9.,]/ /g' |tr -s ' ' >>$TEST_RESULTS_CSV
echo >>$TEST_RESULTS_CSV

echo "non-batched Producer Performance Test" >>$TEST_RESULTS_CSV
echo "Records Sent,Records/sec,Throughput (MB/sec),Avg Latency (ms),Max Latency (ms),50th Percentile (ms),95th Percentile (ms),99th Percentile (ms),99.9th Percentile (ms)">>$TEST_RESULTS_CSV
cat $TEST_RESULTS | grep "1000000 records sent" | sed 's/50th//g; s/95th//g; s/99th//g; s/99\.9th//g'|sed 's/[^0-9.]/ /g' | tr -s ' ' ',' |sed 's/..$//'>>$TEST_RESULTS_CSV
echo >>$TEST_RESULTS_CSV

echo "Batched Producer Performance Test" >>$TEST_RESULTS_CSV
echo "Records Sent,Records/sec,Throughput (MB/sec),Avg Latency (ms),Max Latency (ms),50th Percentile (ms),95th Percentile (ms),99th Percentile (ms),99.9th Percentile (ms)">>$TEST_RESULTS_CSV
cat $TEST_RESULTS | grep "60000000 records sent" | sed 's/50th//g; s/95th//g; s/99th//g; s/99\.9th//g'|sed 's/[^0-9.]/ /g' | tr -s ' ' ',' |sed 's/..$//'>>$TEST_RESULTS_CSV
echo >>$TEST_RESULTS_CSV

echo "Throttled Producer Performance Test" >>$TEST_RESULTS_CSV
echo "Records Sent,Records/sec,Throughput (MB/sec),Avg Latency (ms),Max Latency (ms),50th Percentile (ms),95th Percentile (ms),99th Percentile (ms),99.9th Percentile (ms)">>$TEST_RESULTS_CSV
cat $TEST_RESULTS | grep "1500000 records sent" | sed 's/50th//g; s/95th//g; s/99th//g; s/99\.9th//g' |sed 's/[^0-9.]/ /g' | tr -s ' ' ',' |sed 's/..$//'>>$TEST_RESULTS_CSV
echo >>$TEST_RESULTS_CSV
# Consumer 

echo "Start Time,End Time,Data Consumed (MB),Throughput (MB/sec),Messages Consumed,Messages/sec,Rebalance Time (ms),Fetch Time (ms),Fetch MB/sec,Fetch Messages/sec" >>$TEST_RESULTS_CSV
cat $TEST_RESULTS | grep "start.time" -A1 |grep 2025 >>$TEST_RESULTS_CSV



aws s3 cp $TEST_RESULTS  s3://benchmark-results-wopt/kafka/ec2/$MACHINE_TYPE-ub$PD_FILE_SYSTEM-$(date +"%Y_%m_%d_%I_%M_%p").txt >/dev/null
aws s3 cp $TEST_RESULTS_CSV  s3://benchmark-results-wopt/kafka/ec2/csv/$MACHINE_TYPE-ub$PD_FILE_SYSTEM-$(date +"%Y_%m_%d_%I_%M_%p").csv >/dev/null