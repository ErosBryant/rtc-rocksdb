#!/bin/sh

bench_value="1000"
bench_compression="snappy"  # "snappy,none"
bench_key="24"
bench_benchmarks="fillrandomzip,flush,readrandomzip,stats"
bench_nums=(150000000)
max_background_jobs="2"
unis=(1 0)
use_rtc=(1 0)
number_of_runs=1

current_time=$(date +"%d-%H-%M")
bench_db_base="/mnt/RTC"
output_dir="/home/eros/forRTC/result/cpu/"
log_file_dir="/home/eros/forRTC/result/150M-${current_time}/"
mkdir -p "$log_file_dir"
mkdir -p "$output_dir"

# 총합/요약만 기록하는 파일 (실행 당 1줄)
summary_log="${output_dir}150m_cpu_mem_totals_${current_time}.csv"
echo "elapsed_seconds,use_rtc,uni,num,round,cpu_percent,user_seconds,sys_seconds,max_rss_kb" > "$summary_log"

bench_file_path="/home/eros/forRTC/rocksdb/db_bench"
if [ ! -f "${bench_file_path}" ]; then
  echo "Error: ${bench_file_path} not found!"
  exit 1
fi

for num in "${bench_nums[@]}"; do
  for uni in "${unis[@]}"; do
    for rtc in "${use_rtc[@]}"; do
      for round in $(seq 1 $number_of_runs); do
        log_file=${log_file_dir}out_${num}_uni${uni}_rtc${rtc}_round${round}.log

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

        start_time=$(date +%s)
        cmd="$bench_file_path $const_params"
        echo "$cmd" >> "$log_file"

        tmp_time="$(mktemp)"
        # GNU time 로 총합 수치 수집 (-v 자세히, -o 파일저장)
        /usr/bin/time -v -o "$tmp_time" sh -c "$cmd >> \"$log_file\" 2>&1"
        end_time=$(date +%s)
        elapsed=$(( end_time - start_time ))

        # 필요한 필드 파싱
        cpu_percent=$(awk -F': *' '/Percent of CPU this job got/ {gsub("%","",$2); print $2}' "$tmp_time")
        user_sec=$(awk -F': *' '/User time \(seconds\)/ {print $2}' "$tmp_time")
        sys_sec=$(awk -F': *' '/System time \(seconds\)/ {print $2}' "$tmp_time")
        max_rss=$(awk -F': *' '/Maximum resident set size/ {print $2}' "$tmp_time")

        # 값이 비었을 때 대비
        [ -z "$cpu_percent" ] && cpu_percent="0"
        [ -z "$user_sec" ] && user_sec="0"
        [ -z "$sys_sec" ] && sys_sec="0"
        [ -z "$max_rss" ] && max_rss="0"

        # 한 줄 요약만 기록
        echo "${elapsed},${rtc},${uni},${num},${round},${cpu_percent},${user_sec},${sys_sec},${max_rss}" >> "$summary_log"

        rm -f "$tmp_time"
      done
    done
  done
done
