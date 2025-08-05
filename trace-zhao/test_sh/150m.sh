
#!/bin/sh

bench_value="1000"
bench_compression="snappy"  # "snappy,none"
bench_key="24"
bench_benchmarks="fillrandomzip,stats,readrandomzip,stats"
bench_nums=(150000000)
# bench_nums=(10000000 50000000 100000000 150000000)
# bench_readnum="100000"
max_background_jobs="2"
unis=(1)
use_rtc=(0 1)
number_of_runs=1

bench_db_base="/mnt/new1/db_path"
output_dir="/mnt/new1/cpu/"
mkdir -p "$output_dir"

current_time=$(date "+%Y%m%d-%H%M%S")
cpu_mem_log_file="${output_dir}cpu_mem_usage_${current_time}.log"
echo "Time(s),use_rtc,CPU_Usage(%),Memory_Usage(KB)" > "$cpu_mem_log_file"


bench_file_path="/home/eros/forRTC/rocksdb/db_bench"

if [ ! -f "${bench_file_path}" ]; then
  echo "Error: ${bench_file_path} not found!"
  exit 1
fi

for num in "${bench_nums[@]}"; do
  for uni in "${unis[@]}"; do
    for rtc in "${use_rtc[@]}"; do
      for round in $(seq 1 $number_of_runs); do

        log_file="/home/eros/forRTC/result/out_${num}_uni${uni}_rtc${rtc}_round${round}.log"
        db_dir="${bench_db_base}_${num}_uni${uni}_rtc${rtc}_round${round}"
        mkdir -p "$db_dir"

        const_params="--db=${db_dir} \
          --key_size=$bench_key \
          --value_size=$bench_value \
          --benchmarks=$bench_benchmarks \
          --num=$num \
          --uni=$uni \
          --bloom_bits=10 \
          --level0_file_num_compaction_trigger=5 \
          --compression_type=$bench_compression \
          --max_background_jobs=$max_background_jobs \
          --is_rtc=$rtc \
          --statistics"

        sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'
        echo "[INFO] Running round $round, uni=$uni, rtc=$rtc" | tee -a "$log_file"

        start_time=$(date +%s)

        if [ -n "$1" ]; then
            cmd="stdbuf -oL $bench_file_path $const_params >> $log_file 2>&1 & echo \$!"
            db_bench_pid=$(eval "$cmd")
        else
            cmd="stdbuf -oL $bench_file_path $const_params"
            echo "$cmd" >> "$log_file"
            $cmd >> "$log_file" 2>&1 &
            db_bench_pid=$!
        fi
        # if [ -n "$1" ]; then
        #     cmd="stdbuf -oL $bench_file_path $const_params 2>&1 | tee \"$log_file\" | grep \"rocksdb.\" > \"${log_file%.log}_summary.log\" & echo \$!"
        #     db_bench_pid=$(eval "$cmd")
        # else
        #     cmd="stdbuf -oL $bench_file_path $const_params"
        #     echo "$cmd" >> "$log_file"
        #     $cmd 2>&1 | tee "$log_file" | grep "rocksdb." > "${log_file%.log}_summary.log" &
        #     db_bench_pid=$!
        # fi


        # Monitor CPU usage
        while ps -p $db_bench_pid > /dev/null; do
            usage=$(ps -p $db_bench_pid -o %cpu,rss --no-headers)
            cpu_usage=$(echo "$usage" | awk '{print $1}')
            mem_usage=$(echo "$usage" | awk '{print $2}')
            [ -z "$cpu_usage" ] && cpu_usage="N/A"
            [ -z "$mem_usage" ] && mem_usage="N/A"
            elapsed_time=$(( $(date +%s) - start_time ))

            echo "$elapsed_time,$rtc,$cpu_usage,$mem_usage" >> "$cpu_mem_log_file"
            sleep 1
        done
      done
    done
  done
done
