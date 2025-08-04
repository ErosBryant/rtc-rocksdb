#include "rtc.h"
#include <random>
#include <algorithm>
#include <tuple>
#include <iostream>
#include <memory>

namespace rtc{

    // std::vector<Counter> negative_lookups;
    std::vector<Counter> lookups_counts;
    std::unique_ptr<RTCController> rtc_controller = nullptr;
    // trace_zhao::positive_lookups.resize(1);
    

    size_t internal_lookup = 0;
    size_t rtc = 200000;
    bool is_first = true;
    bool is_rtc = true;
    std::vector<std::pair<int, uint64_t>> level_bypass;  // 실제 정의
    std::unordered_map<int, uint64_t> level_fail_count;  // 실제 정의
    std::vector<std::pair<int, uint64_t>> level_count;  // 실제 정의
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
    int bucket = static_cast<int>(ratio * 10.0);  // 例如 0.26 => 2
    // printf("RTCState::Discretize: ratio %f, bucket %d\n", ratio, bucket);
    bucket=floor(bucket/3);
    return std::min(bucket, 3);  // 最大不能超过 3（防止越界）
}

// QTable
// 获取某个状态对应的 Q 值数组（如果不存在则初始化）
std::vector<double>& QTable::GetQValues(const RTCState& state) {
    if (table.find(state) == table.end()) {
        // 初始化为每个动作的 Q 值都为 0
        // table[state] = std::vector<double>(ACTION_SIZE, 0.0);
         table[state] = std::vector<double>{0.0,0.5,0.1};  // encourage compaction actions early
    }
    printf("QTable::GetQValues: state (%d, %d), Q values: ", state.level, state.ratio_bucket);
    for (const auto& q : table[state]) {
        printf("%f ", q);
    }
    printf("\n");
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
        // 生成一个 0 到 1 的随机数，如果这个随机数小于 epsilon（比如 0.1），就执行“探索”模式。
        // 探索（随机选动作）
        // 完全随机地选一个动作（0~2），作为探索（explore）。
        std::uniform_int_distribution<int> action_dis(0, ACTION_SIZE - 1);
        // printf("action_dis: %d\n", action_dis(generator));
            // double epsilon = 0.9;
            // double alpha = 0.5;
            // double gamma = 0.9;
        epsilon-= 0.01;
        if (epsilon < 0.1) epsilon = 0.1;  // 保持 epsilon 不低于 0.1
        return static_cast<RTCAction>(action_dis(generator));
    } else {
        // 利用（选最大 Q 的动作）
        int best = std::distance(q_values.begin(), std::max_element(q_values.begin(), q_values.end()));
        return static_cast<RTCAction>(best);
    }
    // 在 90% 的情况下（1-epsilon），你会选 LevelKCompaction。
    // 在 10% 的情况下，你会随机选一个动作（探索）。
}

// 根据经验三元组 (s, a, r, s') 来更新 Q 表
void QLearningAgent::UpdateQ(const RTCState& state, RTCAction action, double reward, const RTCState& next_state) {
    double q_old = q_table.GetQ(state, action);  // 旧 Q 值
    // printf("QLearningAgent::UpdateQ: state (%d, %d), action %d, old Q value %f, reward %f\n",
        //    state.level, state.ratio_bucket, static_cast<int>(action), q_old, reward);

           
    auto& next_qs = q_table.GetQValues(next_state);  // 下一个状态所有动作的 Q 值
    double max_q_next = *std::max_element(next_qs.begin(), next_qs.end());

    // Q-learning 更新公式：
    // Q(s,a) ← Q(s,a) + α * [ r + γ * max Q(s',a') - Q(s,a) ]
    double new_q = q_old + alpha * (reward + gamma * max_q_next - q_old);
    q_table.SetQ(state, action, new_q);  // 写入新 Q 值
}


// RTCController
// 初始化：构造函数，设置每层的 read_count / miss_count 为 0
RTCController::RTCController(int num_levels)
    : read_count(num_levels, 0), miss_count(num_levels, 0), level_latency(num_levels, 0) {}


// 每次读操作时调用，根据 miss 情况记录行为
void RTCController::RecordRead(int level, bool miss) {
    read_count[level]++;
    if (miss) miss_count[level]++;
}

void RTCController::RecordRead_latency(int level, size_t latency) {
    this->level_latency[level] += latency;
}

void RTCController::reset(int level) {
    read_count[level]= 0;
    miss_count[level] = 0;
    level_latency[level] = 0;  // 重置延迟统计
}


// 当某一层的读操作足够多后，决定是否执行 compaction
RTCAction RTCController::MaybeTrigger(int level) {
    // if (read_count[level] < Triggered_Count)
    //     return RTCAction::NoCompaction;  // 还没到触发阈值，跳过

    double ratio = (double)miss_count[level] / (read_count[level] + 1e-6);  // 当前 miss 比率
    if (ratio >= 0.5){
    RTCState state{level, RTCState::Discretize(ratio)};  // 构造状态对象
    return agent.ChooseAction(state);  // 用 RL agent 决策
    }
    
    return RTCAction::NoCompaction;  // 还没到触发阈值，跳过
}

// compaction 执行完成后，反馈 reward，更新 RL agent
void RTCController::UpdateAfterAction(int level, RTCAction action, double reward) {

    // 计算奖励：假设 reward 是基于 compaction 前后读延迟的差值 --zhao  “还没完成”
    // double reward = (read_latency_before - read_latency_after) - 0.1 * write_amp;


    double ratio = (double)miss_count[level] / (read_count[level] + 1e-6);
    RTCState old_state{level, RTCState::Discretize(ratio)};

    // 重置统计数据，进入新一轮
    read_count[level] = 0;
    miss_count[level] = 0;

    // 下一状态假设 miss ratio 清零（新开始）
    RTCState next_state{level, RTCState::Discretize(0.0)};
    agent.UpdateQ(old_state, action, reward, next_state);
}

}
