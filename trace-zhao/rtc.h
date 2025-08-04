#ifndef RL_COMPACTION_H
#define RL_COMPACTION_H

#include <vector>
#include <cstdlib>
#include <ctime>
#include <cmath>
#include <unordered_map>
#include <string>
#include <limits>
#include <cstdint>
#include <iostream>
#include <map>
#include <random>
#include <memory>


namespace rtc{

// std::vector<int, std::vector<float>> level_hit_ratio;

class Counter {
public:
    std::string name;
    std::vector<uint64_t> counts;
    std::vector<uint64_t> nums;

    Counter() : counts(7, 0), nums(7, 0) {};
    void Increment(int level, uint64_t n) {
    counts[level] += n;
    nums[level] += 1;
    }
    int Get(int level) { return nums[level]; }
};

// extern std::vector<Counter> negative_lookups;
extern std::vector<Counter> lookups_counts;


// extern uint64_t stat_array[] ={hit_l0,hit_l1,hit_l2,hit_l3,hit_l4,hit_l5,hit_l6};

extern bool is_first;
extern size_t internal_lookup;
extern size_t rtc;
extern bool is_rtc;
extern std::vector<std::pair<int, uint64_t>> level_bypass;
extern std::unordered_map<int, uint64_t> level_fail_count;
extern std::vector<std::pair<int, uint64_t>> level_count;
extern uint64_t level_0_empty_count;
extern uint64_t level_empty_count;
extern uint64_t level_0_compare_count;
extern uint64_t mem_count;


enum class RTCAction {
    NoCompaction = 0,
    LevelKCompaction = 1,
    AggressiveCompaction = 2,
};

const int ACTION_SIZE = 3;

struct RTCState {
    int level;
    int ratio_bucket;

    bool operator<(const RTCState& other) const;
    static int Discretize(double ratio);
};

class QTable {
public:
    std::vector<double>& GetQValues(const RTCState& state);
    double GetQ(const RTCState& state, RTCAction action);
    void SetQ(const RTCState& state, RTCAction action, double value);

private:
    std::map<RTCState, std::vector<double>> table;
};

class QLearningAgent {
public:
    RTCAction ChooseAction(const RTCState& state);
    void UpdateQ(const RTCState& state, RTCAction action, double reward, const RTCState& next_state);

// private:
    double epsilon = 0.9;
    double alpha = 0.5;
    double gamma = 0.9;
    QTable q_table;
    std::default_random_engine generator;
};

class RTCController {
public:
    explicit RTCController(int num_levels);
    void RecordRead(int level, bool miss);
    void RecordRead_latency(int level, size_t latency);
    void reset(int level);
    RTCAction MaybeTrigger(int level);
    void UpdateAfterAction(int level, RTCAction action, double reward);

// private:
    QLearningAgent agent;
    std::vector<size_t> read_count;
    std::vector<size_t> miss_count;
    std::vector<size_t> level_latency;

    const size_t Triggered_Count = 200000;
};

extern std::unique_ptr<RTCController> rtc_controller;

}
#endif // RL_COMPACTION_H