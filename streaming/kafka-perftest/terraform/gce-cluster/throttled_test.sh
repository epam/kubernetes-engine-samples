#!/bin/bash

if [ -z "$1" ]; then
    echo "Error: Machine type argument is required."
    echo "Usage: $0 <MACHINE_TYPE>"
    exit 1
fi

NUMRECORDS=5000000
# Run for 3 brokers
# BOOTSTRAP_SERVERS="gce-kafka-broker-0:9092,gce-kafka-broker-1:9092,gce-kafka-broker-2:9092"

# Run for single broker
BOOTSTRAP_SERVERS="gce-kafka-broker-0:9092"

# Run for optimized settings
# BOOTSTRAP_SERVERS="gce-kafka-broker-opt-0:9092,gce-kafka-broker-opt-1:9092,gce-kafka-broker-opt-2:9092"
# BOOTSTRAP_SINGLE="gce-kafka-broker-opt-0:9092"

BOOTSTRAP_SINGLE="gce-kafka-broker-0:9092"
PROJECT_ID="hl2-gogl-wopt-t1iylu"

BUCKET_NAME="benchmark-results-hl2-gogl-wopt-t1iylu"
TEST_RESULTS=testresults.txt
TEST_RESULTS_CSV=testresults.csv

PD_FILE_SYSTEM="XFS"
MACHINE_TYPE=$1

# Topic name
TOPIC_NAME="test-topic"

echo "Kafka performance test" >$TEST_RESULTS
echo "Machine type: $MACHINE_TYPE" >>$TEST_RESULTS
# echo "load-generator-2" >>$TEST_RESULTS
echo "PD filesystem, $PD_FILE_SYSTEM" >>$TEST_RESULTS
echo "Test date and time: $(date '+%Y-%m-%d %H:%M:%S')" >>$TEST_RESULTS

echo "Machine type,$MACHINE_TYPE" >$TEST_RESULTS_CSV
echo "PD filesystem, $PD_FILE_SYSTEM" >>$TEST_RESULTS_CSV
echo "Test date and time, $(date '+%Y-%m-%d %H:%M:%S')" >>$TEST_RESULTS_CSV
echo >>$TEST_RESULTS_CSV

# Define brokers and their respective zones
BROKER_INSTANCES=(
  "gce-kafka-broker-0:us-central1-a"
#   "gce-kafka-broker-1:us-central1-a"
#   "gce-kafka-broker-2:us-central1-a"
)

# BROKER_INSTANCES=(
#   "gce-kafka-broker-opt-0:us-central1-a"
#   "gce-kafka-broker-opt-1:us-central1-a"
#   "gce-kafka-broker-opt-2:us-central1-a"
# )

gcloud config set user_output_enabled False

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
    --replication-factor=1

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
    --bootstrap-server $BOOTSTRAP_SINGLE \
    --timeout 60000

echo "=== Consumer Performance Test Complete ==="

# delete topic
echo "=== Deleting topic: $TOPIC_NAME ==="
  /opt/kafka/bin/kafka-topics.sh --bootstrap-server=$BOOTSTRAP_SINGLE --topic  $TOPIC_NAME --delete

    # Restart Kafka Broker Instances using gcloud CLI
    echo "Restarting Kafka brokers for a fresh state..."

    for entry in "${BROKER_INSTANCES[@]}"
    do
        broker=$(echo "$entry" | cut -d: -f1) # Extract broker name
        zone=$(echo "$entry" | cut -d: -f2)   # Extract broker zone

        echo "Stopping $broker in zone $zone..."
        gcloud compute instances stop "$broker" --zone="$zone" --project="$PROJECT_ID" >/dev/null

        echo "Starting $broker in zone $zone..."
        gcloud compute instances start "$broker" --zone="$zone" --project="$PROJECT_ID" >/dev/null
    done

    echo "Kafka brokers restarted. Waiting for cluster to stabilize..."
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
cat $TEST_RESULTS | grep "5000000 records sent" | sed 's/50th//g; s/95th//g; s/99th//g; s/99\.9th//g'|sed 's/[^0-9.]/ /g' | tr -s ' ' ',' |sed 's/..$//'>>$TEST_RESULTS_CSV
echo >>$TEST_RESULTS_CSV

echo "Throttled Producer Performance Test" >>$TEST_RESULTS_CSV
echo "Records Sent,Records/sec,Throughput (MB/sec),Avg Latency (ms),Max Latency (ms),50th Percentile (ms),95th Percentile (ms),99th Percentile (ms),99.9th Percentile (ms)">>$TEST_RESULTS_CSV
cat $TEST_RESULTS | grep "1500000 records sent" | sed 's/50th//g; s/95th//g; s/99th//g; s/99\.9th//g' |sed 's/[^0-9.]/ /g' | tr -s ' ' ',' |sed 's/..$//'>>$TEST_RESULTS_CSV
echo >>$TEST_RESULTS_CSV
# Consumer 

echo "Start Time,End Time,Data Consumed (MB),Throughput (MB/sec),Messages Consumed,Messages/sec,Rebalance Time (ms),Fetch Time (ms),Fetch MB/sec,Fetch Messages/sec" >>$TEST_RESULTS_CSV
cat $TEST_RESULTS | grep "start.time" -A1 |grep 2025 >>$TEST_RESULTS_CSV



gcloud storage cp $TEST_RESULTS  gs://$BUCKET_NAME/kafka/gce/$MACHINE_TYPE-ub$PD_FILE_SYSTEM-$(date +"%Y_%m_%d_%I_%M_%p").txt >/dev/null
gcloud storage cp $TEST_RESULTS_CSV  gs://$BUCKET_NAME/kafka/gce/csv/$MACHINE_TYPE-ub$PD_FILE_SYSTEM-$(date +"%Y_%m_%d_%I_%M_%p").csv >/dev/null