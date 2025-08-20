#include "rtc.h"
#include <random>
#include <algorithm>
#include <tuple>
#include <iostream>
#include <memory>
#include "db/internal_stats.h"
#include "db/column_family.h"

namespace rtc{




    // std::vector<Counter> negative_lookups;
    std::vector<Counter> lookups_counts;
    // std::atomic<uint64_t> rtc::internal_lookup_{0};
    std::unique_ptr<RTCController> rtc_controller = nullptr;
    // trace_zhao::positive_lookups.resize(1);
    std::atomic<bool> compaction_in_progress[6] = {false, false, false, false, false, false};
    

    std::atomic<size_t> internal_lookup = 0;
    size_t rtc = 300000;
    bool is_first = true;
    bool is_rtc = true;
    std::vector<std::pair<int, uint64_t>> level_bypass;  // 실제 정의
    std::unordered_map<int, uint64_t> level_fail_count;  // 실제 정의
    std::vector<std::pair<int, uint64_t>> level_count;  // 실제 정의

    std::vector<uint64_t> triggered_count = {0, 0, 0};  // 실제 정의

    uint64_t level_0_empty_count = 0;
    uint64_t level_0_compare_count = 0;
    uint64_t level_empty_count = 0;
    uint64_t mem_count=0;



// RTCState
// 重载小于运算符，使 RTCState 可以用于 std::map 的 key 比较
bool RTCState::operator<(const RTCState& other) const {
    // 比较顺序：level -> ratio_bucket
    return std::tie(level, ratio_bucket) < std::tie(other.level, other.ratio_bucket);
}

// 将 miss ratio 离散化成 0~9（用于状态桶化）
int RTCState::Discretize(double ratio) {
    // Maps a ratio [0.0, 1.0] to a bucket [0, 3].
    // [0.0, 0.3) -> 0
    // [0.3, 0.6) -> 1
    // [0.6, 0.9) -> 2
    // [0.9, 1.0] -> 3
    int bucket = static_cast<int>(ratio * 10.0);  // e.g., 0.26 => 2
    bucket = floor(bucket / 3);
    return std::min(bucket, 3);  // Clamp to 3 to prevent overflow
}

// QTable
// 获取某个状态对应的 Q 值数组（如果不存在则初始化）
std::vector<double>& QTable::GetQValues(const RTCState& state) {
    if (table.find(state) == table.end()) {
        // Initialize Q-values for a new state.
        // The initial values can be tuned to encourage or discourage certain actions.
        // Here, we encourage action 1 (e.g., FullCompaction) slightly at the beginning.
        // TODO: Replace magic numbers with a named constant for action size.
        table[state] = std::vector<double>{0.0, 0.8, 0.0};
    }
    return table[state];
}

// 获取某状态下某个动作的 Q 值
double QTable::GetQ(const RTCState& state, RTCAction action) {
    return GetQValues(state)[static_cast<int>(action)];
}

// 设置某状态下某个动作的 Q 值
void QTable::SetQ(const RTCState& state, RTCAction action, double value) {
    GetQValues(state)[static_cast<int>(action)] = value;
}




// QLearningAgent
// 基于 epsilon-greedy 策略选择动作
RTCAction QLearningAgent::ChooseAction(const RTCState& state) {
    auto& q_values = q_table.GetQValues(state);  // 获取该状态的所有 Q 值
    std::uniform_real_distribution<double> dis(0.0, 1.0);  // 随机小数 [0,1)
    if (dis(generator) < epsilon) {
        // Exploration: choose a random action.
        // TODO: The action size should be a named constant.
        std::uniform_int_distribution<int> action_dis(0, ACTION_SIZE - 1);

        // Epsilon decay: reduces exploration over time.
        // This decay happens only on exploration steps, which might be slow.
        // Consider a small decay after every action.
        epsilon -= 0.01;
        if (epsilon < 0.1) epsilon = 0.1;  // Keep a minimum exploration rate.
        return static_cast<RTCAction>(action_dis(generator));
    } else {
        // Exploitation: choose the action with the highest Q-value.
        int best_action_idx = std::distance(q_values.begin(), std::max_element(q_values.begin(), q_values.end()));
        return static_cast<RTCAction>(best_action_idx);
    }

}

// 根据经验三元组 (s, a, r, s') 来更新 Q 表
void QLearningAgent::UpdateQ(const RTCState& state, RTCAction action, double reward, const RTCState& next_state) {
    double q_old = q_table.GetQ(state, action);  
           
    auto& next_qs = q_table.GetQValues(next_state);  // 下一个状态所有动作的 Q 值
    double max_q_next = *std::max_element(next_qs.begin(), next_qs.end());

    // Q-learning update rule:
    // Q(s,a) ← Q(s,a) + α * [ r + γ * max Q(s',a') - Q(s,a) ]
    double new_q = q_old + alpha * (reward + gamma * max_q_next - q_old);
    q_table.SetQ(state, action, new_q);  // 写入新 Q 值
}


// RTCController
// 初始化：构造函数，设置每层的 read_count / miss_count 为 0
RTCController::RTCController(int num_levels)
    : read_count(num_levels, 0),
      miss_count(num_levels, 0),
      level_latency(num_levels, 0),
      threshold(num_levels, 0.4),
      prev_ratio(num_levels, 0.0),
      prev_waf(num_levels, 0.0),
      max_delta_ratio(num_levels, 1e-6),  // Avoid division by zero
      max_diff_waf(num_levels, 1e-6) {}


// 每次读操作时调用，根据 miss 情况记录行为
void RTCController::RecordRead(int level, bool miss) {
    std::lock_guard<std::mutex> lock(mutex_);
    read_count[level]++;
    if (miss) {
        miss_count[level]++;
    }
}

void RTCController::RecordRead_latency(int level, size_t latency) {
    std::lock_guard<std::mutex> lock(mutex_);
    this->level_latency[level] += latency;
}

void RTCController::reset(int level) {
    std::lock_guard<std::mutex> lock(mutex_);
    read_count[level]= 0;
    miss_count[level] = 0;
    
    level_latency[level] = 0;  // 重置延迟统计
}


// 当某一层的读操作足够多后，决定是否执行 compaction
RTCAction RTCController::MaybeTrigger(int level,double waf) {
    std::lock_guard<std::mutex> lock(mutex_);

    double ratio = (read_count[level] == 0) ? 0.0 : (double)miss_count[level] / read_count[level];
    if (ratio >= threshold[level]){
        prev_ratio[level] = ratio;
        prev_waf[level] = waf;
        RTCState state{level, RTCState::Discretize(ratio)};  // 构造状态对象
        return agent.ChooseAction(state);  // 用 RL agent 决策
    }
    
    return RTCAction::NoCompaction;  // 还没到触发阈值，跳过
}

void RTCController::UpdateAfterAction(int level,
                                      RTCAction action,
                                      double waf) {
  std::lock_guard<std::mutex> lock(mutex_);
  // 1) Calculate new miss ratio after the action
  double new_ratio = (read_count[level] == 0) ? 0.0 : (double)miss_count[level] / read_count[level];

  // 2) Calculate the change in miss ratio and write amp
  double delta_ratio = prev_ratio[level] - new_ratio;     // Improvement in miss ratio (higher is better)
  double diff_waf = std::max(0.0, waf - prev_waf[level]);  // Increase in WAF (lower is better)

  // 3) Update historical maximums for normalization
  max_delta_ratio[level] = std::max(max_delta_ratio[level], delta_ratio);
  max_diff_waf[level]    = std::max(max_diff_waf[level],    diff_waf);

  // 4) Normalize metrics to be in a comparable range [0, 1]
  double norm_ratio = (max_delta_ratio[level] > 0) ? delta_ratio / max_delta_ratio[level] : 0.0;
  double norm_dwaf  = (max_diff_waf[level]    > 0) ? diff_waf    / max_diff_waf[level]    : 0.0;

  // Clamp values to [0, 1] to handle potential floating point inaccuracies
  norm_ratio = std::clamp(norm_ratio, 0.0, 1.0);
  norm_dwaf  = std::clamp(norm_dwaf,  0.0, 1.0);

  // 5) Calculate reward. The goal is to maximize miss ratio reduction while minimizing WAF increase.
  const double w_r = 1.0; // Weight for miss ratio improvement
  const double w_w = 1.0; // Weight for WAF penalty
  double reward = w_r * norm_ratio - w_w * norm_dwaf;

  if (action == RTCAction::NoCompaction) {
      reward = 0.0;
  } else if (reward < 0.01) {
      // Provide a small positive reward for taking an action
      // to avoid punishing exploration too heavily.
      reward = 0.01;
  }


  // 6) Update Q-table with the experience
  RTCState old_state{level, RTCState::Discretize(prev_ratio[level])};
  RTCState next_state{level, RTCState::Discretize(new_ratio)};
  agent.UpdateQ(old_state, action, reward, next_state);

  // 7) Prepare for the next cycle
  read_count[level] = 0;
  miss_count[level] = 0;
  prev_ratio[level] = new_ratio;
  prev_waf[level]   = waf;

  // 8) Adapt the trigger threshold based on the reward
  const double eta = 0.01;  // Threshold learning rate
  // If reward > 0 (good action), lower the threshold to trigger more easily.
  // If reward < 0 (bad action), raise the threshold to trigger less easily.
  threshold[level] -= eta * reward;
  // Clamp threshold to a valid range [0, 1]
  threshold[level] = std::clamp(threshold[level], 0.0, 1.0);

  // 9) Debug output
//   printf("RTCController::UpdateAfterAction: level %d, action %d, "
//          "old_ratio %.3f, new_ratio %.3f, reward %.3f, "
//          "norm_ratio %.3f, norm_dwaf %.3f, threshold %.3f\n",
//          level, static_cast<int>(action), prev_ratio[level], new_ratio,
//          reward, norm_ratio, norm_dwaf, threshold[level]);

}




}
