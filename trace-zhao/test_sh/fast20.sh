#!/bin/bash
# ============================================================
# Script: run_fb_workloads.sh
# Based on FAST'20 Appendix A.3 (mixgraph) with acceleration
# - Runs ZippyDB / UDB / UP2X workloads
# - For each workload, toggles -is_rtc in (0, 1)
# - Creates a separate 50M KV DB per is_rtc
# ============================================================

set -euo pipefail

# RocksDB db_bench binary path
DB_BENCH="/home/eros/forRTC/rocksdb/db_bench"

OUTDIR="${OUTDIR:-./fb_workload_results}"
mkdir -p "$OUTDIR"

# -------------------- Common knobs --------------------------
# Appendix base knobs (ACM FAST'20)
CACHE_SIZE=268435456
KEY_SIZE=48
VAL_SIZE_FILL=43
NUM_FILL=50000000

# Acceleration (24h sine → 10x faster)
SINE_INT_MS=5000
SINE_A=1000            # base intensity (can tune to 1500 if you want stronger)
SINE_B=0.0000073       # 0.000073 / 10
SINE_D=45000           # 4500 * 10

# Perf + threading
PERF_LEVEL=2
THREADS=1              # mixgraph更稳定

# RTC toggle list
RTC_LIST=(0 1)

# -------------------- Functions -----------------------------
fill_random_db () {
  local dbdir="$1"
  local rtc="$2"
  echo "[FILL] Creating DB (50M KV) at ${dbdir} (is_rtc=${rtc})"
  mkdir -p "${dbdir}"
  "${DB_BENCH}" --benchmarks=fillrandom \
    --perf_level=3 \
    -use_direct_io_for_flush_and_compaction=true \
    -use_direct_reads=true \
    -cache_size=${CACHE_SIZE} \
    -key_size=${KEY_SIZE} \
    -value_size=${VAL_SIZE_FILL} \
    -num=${NUM_FILL} \
    -db="${dbdir}" \
    -is_rtc=${rtc} \
    > "${OUTDIR}/fillrandom_isrtc${rtc}.log" 2>&1
}

run_zippydb () {
  local dbdir="$1"
  local rtc="$2"
  echo "[RUN] ZippyDB (is_rtc=${rtc})"
  "${DB_BENCH}" --benchmarks="mixgraph" \
    -use_direct_io_for_flush_and_compaction=true \
    -use_direct_reads=true \
    -cache_size=${CACHE_SIZE} \
    -keyrange_dist_a=14.18 -keyrange_dist_b=-2.917 \
    -keyrange_dist_c=0.0164 -keyrange_dist_d=-0.08082 \
    -keyrange_num=30 \
    -value_k=0.2615 -value_sigma=25.45 \
    -iter_k=2.517 -iter_sigma=14.236 \
    -mix_get_ratio=0.85 -mix_put_ratio=0.14 -mix_seek_ratio=0.01 \
    -sine_mix_rate_interval_milliseconds=${SINE_INT_MS} \
    -sine_a=${SINE_A} -sine_b=${SINE_B} -sine_d=${SINE_D} \
    --perf_level=${PERF_LEVEL} --threads=${THREADS} \
    -reads=420000000 -num=${NUM_FILL} -key_size=${KEY_SIZE} \
    -db="${dbdir}" -use_existing_db=true \
    -is_rtc=${rtc} \
    > "${OUTDIR}/zippydb_isrtc${rtc}.log" 2>&1
}

run_udb () {
  local dbdir="$1"
  local rtc="$2"
  echo "[RUN] UDB (is_rtc=${rtc})"
  "${DB_BENCH}" --benchmarks="mixgraph" \
    -use_direct_io_for_flush_and_compaction=true \
    -use_direct_reads=true \
    -cache_size=${CACHE_SIZE} \
    # 下面的 keyrange/value/iter 分布取自与 ZippyDB 同风格的可用参数，
    # 操作比例按 UDB Assoc 常见比率 (Get/Put/Seek ≈ 0.806/0.159/0.035)
    -keyrange_dist_a=12.0 -keyrange_dist_b=-2.5 \
    -keyrange_dist_c=0.015 -keyrange_dist_d=-0.07 \
    -keyrange_num=30 \
    -value_k=0.2615 -value_sigma=25.45 \
    -iter_k=2.517 -iter_sigma=14.236 \
    -mix_get_ratio=0.806 -mix_put_ratio=0.159 -mix_seek_ratio=0.035 \
    -sine_mix_rate_interval_milliseconds=${SINE_INT_MS} \
    -sine_a=${SINE_A} -sine_b=${SINE_B} -sine_d=${SINE_D} \
    --perf_level=${PERF_LEVEL} --threads=${THREADS} \
    -reads=420000000 -num=${NUM_FILL} -key_size=${KEY_SIZE} \
    -db="${dbdir}" -use_existing_db=true \
    -is_rtc=${rtc} \
    > "${OUTDIR}/udb_isrtc${rtc}.log" 2>&1
}

run_up2x_approx () {
  local dbdir="$1"
  local rtc="$2"
  echo "[RUN] UP2X (approx, Put≈Merge, is_rtc=${rtc})"
  # 说明：mixgraph 不产 Merge。这里用 Put≈0.925 近似，
  # 请在打开 RocksDB 时注册你的 MergeOperator，使写入具有合并语义。
  "${DB_BENCH}" --benchmarks="mixgraph" \
    -use_direct_io_for_flush_and_compaction=true \
    -use_direct_reads=true \
    -cache_size=${CACHE_SIZE} \
    -keyrange_dist_a=10.0 -keyrange_dist_b=-2.2 \
    -keyrange_dist_c=0.012 -keyrange_dist_d=-0.06 \
    -keyrange_num=20 \
    -value_k=0.25 -value_sigma=16 \
    -iter_k=2.0 -iter_sigma=10 \
    -mix_get_ratio=0.075 -mix_put_ratio=0.925 -mix_seek_ratio=0.000 \
    -sine_mix_rate_interval_milliseconds=${SINE_INT_MS} \
    -sine_a=${SINE_A} -sine_b=${SINE_B} -sine_d=${SINE_D} \
    --perf_level=${PERF_LEVEL} --threads=${THREADS} \
    -reads=111000000 -num=5000000 -key_size=${KEY_SIZE} \
    -db="${dbdir}" -use_existing_db=true \
    -is_rtc=${rtc} \
    > "${OUTDIR}/up2x_isrtc${rtc}.log" 2>&1
}

# -------------------- Main -----------------------------
for rtc in "${RTC_LIST[@]}"; do
  DBBASE="/mnt/fast_${rtc}/"
  # 为该 is_rtc 构建独立底库（50M KV）
  fill_random_db "${DBBASE}" "${rtc}"

  # 跑三种 workload（使用相同底库路径）
  run_zippydb   "${DBBASE}" "${rtc}"
  run_udb       "${DBBASE}" "${rtc}"
  run_up2x_approx "${DBBASE}" "${rtc}"
done

echo "[DONE] Logs saved to ${OUTDIR}"
