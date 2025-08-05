

// logging_trace.h
// #pragma once
#include <stdint.h>
#include <fstream>
#include "file/filename.h"
#include "rocksdb/env.h"
#include "db/dbformat.h"
#include "port/port.h"
#include "rocksdb/types.h" // For FileType and kInfoLogFile

namespace trace_zhao {

  extern std::ofstream get_log_hit;
  extern std::ofstream get_log_miss;
  extern std::vector<std::pair<int, uint64_t>> level_search_time_nanos;

}