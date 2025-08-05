#include "trace-zhao/logging_trace.h"
#include "file/filename.h"
#include "rocksdb/env.h"
#include "file/filename.h"
#include "db/dbformat.h"
#include "port/port.h"

namespace trace_zhao {

  // Definition + initializer (only once):
  // std::ofstream get_log_hit( "/home/eros/forRTC/rocksdb/trace-zhao/result/150m_uni1_bf.csv",  std::ios::out | std::ios::app);
  // std::ofstream get_log_miss( "/home/eros/forRTC/rocksdb/trace-zhao/result/150m_uni1_bf_miss.csv",  std::ios::out | std::ios::app);
  // ROCKSDB_NAMESPACE::FileType type = ROCKSDB_NAMESPACE::kInfoLogFile; // Initialize type to kInfoLogFile
  std::vector<std::pair<int, uint64_t>> level_search_time_nanos;

  
}
 