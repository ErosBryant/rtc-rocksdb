#!/bin/sh
set -e

bench_value="1000"
bench_compression="snappy"
bench_key="24"
bench_benchmarks="fillrandomgen,flush,readrandomgen,waitforcompaction,fillrandomgen,flush,readrandomgen,waitforcompaction,fillrandomgen,flush,readrandomgen,waitforcompaction,fillrandomgen,flush,readrandomgen,waitforcompaction,fillrandomgen,flush,readrandomgen,waitforcompaction,fillrandomgen,flush,readrandomgen,waitforcompaction,fillrandomgen,flush,readrandomgen,waitforcompaction,fillrandomgen,flush,readrandomgen,waitforcompaction,fillrandomgen,flush,readrandomgen,stats"
bench_nums=(15000000 10000000)
max_background_jobs="2"
unis=(0 1)
use_rtc=(1 0)
number_of_runs=2

current_time=$(date +"%d-%H-%M")
bench_db_base="/mnt/RTC"
output_dir="/home/eros/forRTC/result/cpu/"
log_file_dir="/home/eros/forRTC/result/15Mx10-${current_time}/"
mkdir -p "$log_file_dir" "$output_dir"

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
        log_file="${log_file_dir}out_${num}_uni${uni}_rtc${rtc}_round${round}.log"
        db_dir="${bench_db_base}_${num}_uni${uni}_rtc${rtc}_round${round}_${current_time}"

        # 깨끗한 DB 디렉터리 보장
        rm -rf "$db_dir"
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
        cmd="$bench_file_path $const_params"
        echo "$cmd" >> "$log_file"

        tmp_time="$(mktemp)"
        # time -v 로 자원 총합 수집
        /usr/bin/time -v -o "$tmp_time" sh -c "$cmd >> \"$log_file\" 2>&1"
        end_time=$(date +%s)
        elapsed=$(( end_time - start_time ))

        # 필요한 필드 파싱
        cpu_percent=$(awk -F': *' '/Percent of CPU this job got/ {gsub("%","",$2); print $2}' "$tmp_time")
        user_sec=$(awk -F': *' '/User time \(seconds\)/ {print $2}' "$tmp_time")
        sys_sec=$(awk -F': *' '/System time \(seconds\)/ {print $2}' "$tmp_time")
        max_rss=$(awk -F': *' '/Maximum resident set size/ {print $2}' "$tmp_time")

        [ -z "$cpu_percent" ] && cpu_percent="0"
        [ -z "$user_sec" ] && user_sec="0"
        [ -z "$sys_sec" ] && sys_sec="0"
        [ -z "$max_rss" ] && max_rss="0"

        echo "${elapsed},${rtc},${uni},${num},${round},${cpu_percent},${user_sec},${sys_sec},${max_rss}" >> "$summary_log"
        rm -f "$tmp_time"
      done
    done
  done
done
