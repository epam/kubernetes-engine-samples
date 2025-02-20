#/bin/sh

NUMRECORDS=5000000


for i in {1..3} 
do
    echo "Test run ${i}:" >>testresults.txt
    echo "Testing end-to-end latency:" >>testresults.txt
    
    /opt/kafka/bin/kafka-topics.sh --bootstrap-server=kafka-svc.kafka.svc.cluster.local:9092 --topic test-topic --create --partitions=3 --replication-factor=3
    sleep 10

    /opt/kafka/bin/kafka-run-class.sh \
        org.apache.kafka.tools.EndToEndLatency \
        kafka-svc.kafka.svc.cluster.local:9092 \
        test-topic 5000 1 1000| tee -a testresults.txt

    /opt/kafka/bin/kafka-producer-perf-test.sh \
    --topic test-topic \
    --num-records 1000000 \
    --record-size 1000 \
    --throughput -1 \
    --producer-props bootstrap.servers=kafka-svc.kafka.svc.cluster.local:9092 \
    acks=1 \
    batch.size=1 \
    linger.ms=100 \
    compression.type=snappy | tee -a testresults.txt

    echo "Maximum throughput test:" >>testresults.txt
    echo "Generating $NUMRECORDS records">>testresults.txt

    /opt/kafka/bin/kafka-producer-perf-test.sh \
    --topic test-topic \
    --num-records $NUMRECORDS \
    --record-size 1000 \
    --throughput -1 \
    --producer-props bootstrap.servers=kafka-svc.kafka.svc.cluster.local:9092 \
    acks=1 \
    batch.size=10000 \
    linger.ms=100 \
    compression.type=snappy | tee -a testresults.txt

    echo "Latency test with trottled to 50K messages per second throughput:" >>testresults.txt
    echo "Generating $NUMRECORDS records">>testresults.txt

    /opt/kafka/bin/kafka-producer-perf-test.sh \
    --topic test-topic \
    --num-records $NUMRECORDS \
    --record-size 1000 \
    --throughput 50000 \
    --producer-props bootstrap.servers=kafka-svc.kafka.svc.cluster.local:9092 \
    acks=1 \
    batch.size=10000 \
    linger.ms=100 \
    compression.type=snappy | tee -a testresults.txt

    /opt/kafka/bin/kafka-consumer-perf-test.sh \
    --topic test-topic \
    --messages $NUMRECORDS \
    --bootstrap-server kafka-svc.kafka.svc.cluster.local:9092 | tee -a testresults.txt

    #delete topic
    /opt/kafka/bin/kafka-topics.sh --bootstrap-server=kafka-svc.kafka.svc.cluster.local:9092 --topic test-topic --delete

    sleep 5m


    done
