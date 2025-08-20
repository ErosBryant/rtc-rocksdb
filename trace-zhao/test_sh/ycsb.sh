#!/bin/sh

bench_value="1000"
bench_compression="snappy"  # "snappy,none"
bench_key="24"
bench_benchmarks="ycsbfill,ycsba,waitforcompaction,ycsbb,waitforcompaction,ycsbc,waitforcompaction,ycsbd,waitforcompaction,ycsbe,waitforcompaction,ycsbf,waitforcompaction,stats"
bench_nums=(10000000)
max_background_jobs="2"
unis=(0 1)
use_rtc=(1 0)
number_of_runs=2


current_time=$(date +"%d-%H-%M")
bench_db_base="/mnt/RTC"
# output_dir="/home/eros/forRTC/result/cpu/"
log_file_dir="/home/eros/forRTC/result/YCSB-${current_time}/"
mkdir -p "$log_file_dir"
# mkdir -p "$output_dir"


# cpu_mem_log_file="${output_dir}cpu_mem_usage_${current_time}.log"
# echo "Time(s),use_rtc,CPU_Usage(%),Memory_Usage(KB)" > "$cpu_mem_log_file"

bench_file_path="/home/eros/forRTC/rocksdb/db_bench"

if [ ! -f "${bench_file_path}" ]; then
  echo "Error: ${bench_file_path} not found!"
  exit 1
fi

# # Function to get process CPU ticks
# get_cpu_usage() {
#     pid=$1
#     awk '{print $14+$15}' /proc/$pid/stat 2>/dev/null
# }

# CLK_TCK=$(getconf CLK_TCK)

for num in "${bench_nums[@]}"; do
  for uni in "${unis[@]}"; do
    for rtc in "${use_rtc[@]}"; do
      for round in $(seq 1 $number_of_runs); do

         log_file=${log_file_dir}out_${num}_uni${uni}_rtc${rtc}_round${round}.log
        # db_dir="${bench_db_base}_${num}_uni${uni}_rtc${rtc}_round${round}"
        # mkdir -p "$db_dir"
        # --db=${db_dir} \

        const_params=" \
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

        # start_time=$(date +%s)

        cmd="$bench_file_path $const_params"
        echo "$cmd" >> "$log_file"
        $cmd >> "$log_file" 2>/dev/null

        # db_bench_pid=$!

        # prev_cpu=$(get_cpu_usage $db_bench_pid)
        # prev_time=$(date +%s)

        # Monitor CPU usage
        # while ps -p $db_bench_pid > /dev/null; do
        #     sleep 1
        #     cur_cpu=$(get_cpu_usage $db_bench_pid)
        #     cur_time=$(date +%s)

        #     if [ -n "$cur_cpu" ]; then
        #         cpu_delta=$((cur_cpu - prev_cpu))
        #         time_delta=$((cur_time - prev_time))
        #         cpu_usage=$(echo "scale=2; ($cpu_delta/$CLK_TCK)/$time_delta*100" | bc)
        #     else
        #         cpu_usage="0.0"
        #     fi

        #     mem_usage=$(ps -p $db_bench_pid -o rss= --no-headers)
        #     [ -z "$mem_usage" ] && mem_usage="0"

        #     elapsed_time=$(( $(date +%s) - start_time ))
        #     echo "$elapsed_time,$rtc,$cpu_usage,$mem_usage" >> "$cpu_mem_log_file"

        #     prev_cpu=$cur_cpu
        #     prev_time=$cur_time
        # done
      done
    done
  done
done
