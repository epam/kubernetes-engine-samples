bin/kafka-producer-perf-test.sh \
--topic test-topic \
--num-records 5000000 \
--record-size 1000 \
--throughput -1 \
--producer-props bootstrap.servers=10.52.13.2:9092 \
  acks=1 \
  batch.size=10000 \
  linger.ms=100 \
  compression.type=snappy



bin/kafka-producer-perf-test.sh \
--topic test-topic \
--num-records 5000000 \
--record-size 1000 \
--throughput -1 \
--producer-props bootstrap.servers=10.10.0.26:9092 \
  acks=1 \
  batch.size=10000 \
  linger.ms=100 \
  compression.type=snappy


echo "Message from my-user" |kcat \
  -b my-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092 \
  -t my-topic -P
kcat -b my-cluster-kafka-bootstrap.kafka.svc.cluster.local:9092 \
  -t my-topic -C