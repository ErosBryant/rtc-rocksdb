### **Algorithm 1: Reinforcement Learning-based Compaction Trigger (RTC)**

**Parameters:**
- `α`: Q-learning learning rate
- `γ`: Discount factor for future rewards
- `ε`: Initial probability for exploration (epsilon-greedy)
- `η`: Learning rate for the adaptive trigger threshold
- `w_r`, `w_w`: Weights for miss ratio improvement and WAF penalty in the reward function

**Initialization:**
1: Initialize Q-table `Q(s, a)` to zeros for all state-action pairs.
2: For each level `l` in the LSM-tree:
3: &nbsp;&nbsp; `threshold[l] ← initial_threshold` (e.g., 0.4)
4: &nbsp;&nbsp; `read_count[l] ← 0`, `miss_count[l] ← 0`
5: &nbsp;&nbsp; `prev_ratio[l] ← 0.0`, `prev_waf[l] ← 0.0`
6: &nbsp;&nbsp; `max_delta_ratio[l] ← ε_val`, `max_diff_waf[l] ← ε_val` (small non-zero constant)

---
**Main Loop:** The following procedures are executed concurrently.

**Procedure** `OnRead(level, was_miss)`:
1: **Lock** (to ensure thread safety)
2: `read_count[level] ← read_count[level] + 1`
3: **if** `was_miss` **then**
4: &nbsp;&nbsp; `miss_count[level] ← miss_count[level] + 1`
5: **Unlock**

**Procedure** `MaybeTriggerCompaction()`: (Executed periodically)
1: For each level `l` in the LSM-tree:
2: &nbsp;&nbsp; **Lock**
3: &nbsp;&nbsp; **if** `read_count[l] > 0` **then**
4: &nbsp;&nbsp;&nbsp;&nbsp; `current_ratio ← miss_count[l] / read_count[l]`
5: &nbsp;&nbsp;&nbsp;&nbsp; **if** `current_ratio ≥ threshold[l]` **then**
6: &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; `s_old ← {level: l, ratio_bucket: Discretize(current_ratio)}`
7: &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; `action ← ChooseAction(s_old, Q, ε)`
8: &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; **if** `action ≠ NoCompaction` **then**
9: &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; `prev_ratio[l] ← current_ratio`
10:&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; `prev_waf[l] ← GetCurrentWAF()`
11:&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; Execute compaction `action` on level `l`
12:&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; `waf_new ← GetCurrentWAF()`
13:&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; `UpdatePolicy(l, s_old, action, waf_new)`
14: &nbsp;&nbsp; **Unlock**

---
**Helper Procedures:**

**Procedure** `ChooseAction(s, Q, ε)`:
1: **if** `random() < ε` **then**
2: &nbsp;&nbsp; **return** a random action from `{FullCompaction, PartialCompaction}`
3: **else**
4: &nbsp;&nbsp; **return** `argmax_a Q(s, a)`

**Procedure** `UpdatePolicy(l, s_old, action, waf_new)`:
1:  // 1. Calculate Reward
2:  `ratio_new ← miss_count[l] / read_count[l]`
3:  `delta_ratio ← prev_ratio[l] - ratio_new`
4:  `diff_waf ← max(0, waf_new - prev_waf[l])`
5:  `max_delta_ratio[l] ← max(max_delta_ratio_l, delta_ratio)`
6:  `max_diff_waf[l] ← max(max_diff_waf[l], diff_waf)`
7:  `norm_ratio ← delta_ratio / max_delta_ratio_l`
8:  `norm_dwaf ← diff_waf / max_diff_waf_l`
9:  `reward ← w_r * norm_ratio - w_w * norm_dwaf`
10:
11: // 2. Update Q-value using the Bellman equation
12: `s_new ← {level: l, Discretize(new_ratio)}`
13: `max_q_next ← max_a' Q(s_new, a')`
14: `q_old ← Q(s_old, action)`
15: `Q(s_old, action) ← q_old + α * (reward + γ * max_q_next - q_old)`
16:
17: // 3. Adapt the trigger threshold
18: `threshold[l] ← threshold[l] - η * reward`
19: `threshold[l] ← clamp(threshold[l], 0.0, 1.0)`
20:
21: // 4. Reset for next cycle
22: `read_count[l] ← 0`, `miss_count[l] ← 0`
23: `prev_ratio[l] ← new_ratio`
24: `prev_waf[l] ← waf_current`
