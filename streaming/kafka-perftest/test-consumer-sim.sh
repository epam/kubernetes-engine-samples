#/bin/sh

[ "$#" -ne 3 ] && echo "USAGE $0 <BOOTSTRAP_SERVERS> <TOPIC> <NUMRECORDS>" && exit
# First argument 
BOOTSTRAP_SERVERS=$1

# Topic name
TOPIC_NAME=$2

NUMRECORDS=$3

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

