#/bin/sh

TEST_FILE=$1

echo "End-to-End Performance Test" 
echo "Avg latency" 
cat $TEST_FILE | grep "Avg latency" | sed 's/[^0-9.]/ /g' | tr -s ' '  
echo "Percentiles:" 
echo "50th, 99th, 99.9th" 
cat $TEST_FILE | grep "Percentiles:" | sed 's/50th//g; s/95th//g; s/99th//g; s/99\.9th//g'|sed 's/[^0-9.,]/ /g' |tr -s ' ' 
echo 

echo "non-batched Producer Performance Test" 
echo "Records Sent,Records/sec,Throughput (MB/sec),Avg Latency (ms),Max Latency (ms),50th Percentile (ms),95th Percentile (ms),99th Percentile (ms),99.9th Percentile (ms)"
cat $TEST_FILE | grep "1000000 records sent" | sed 's/50th//g; s/95th//g; s/99th//g; s/99\.9th//g'|sed 's/[^0-9.]/ /g' | tr -s ' ' ',' |sed 's/..$//'
echo 

echo "Batched Producer Performance Test" 
echo "Records Sent,Records/sec,Throughput (MB/sec),Avg Latency (ms),Max Latency (ms),50th Percentile (ms),95th Percentile (ms),99th Percentile (ms),99.9th Percentile (ms)"
cat $TEST_FILE | grep "$NUMRECORDS records sent" | sed 's/50th//g; s/95th//g; s/99th//g; s/99\.9th//g'|sed 's/[^0-9.]/ /g' | tr -s ' ' ',' |sed 's/..$//'
echo 

echo "Throttled Producer Performance Test" 
echo "Records Sent,Records/sec,Throughput (MB/sec),Avg Latency (ms),Max Latency (ms),50th Percentile (ms),95th Percentile (ms),99th Percentile (ms),99.9th Percentile (ms)"
cat $TEST_FILE | grep "1500000 records sent" | sed 's/50th//g; s/95th//g; s/99th//g; s/99\.9th//g' |sed 's/[^0-9.]/ /g' | tr -s ' ' ',' |sed 's/..$//'
echo 

# Consumer 

echo "Start Time,End Time,Data Consumed (MB),Throughput (MB/sec),Messages Consumed,Messages/sec,Rebalance Time (ms),Fetch Time (ms),Fetch MB/sec,Fetch Messages/sec"
cat $TEST_FILE | grep "start.time" -A1 |grep $(date +%Y)