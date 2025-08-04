每次读请求：
   ↓
RecordRead(level, miss)
   ↓
read_count[level] ≥ 200000?
   ↓ 是
MaybeTrigger(level)
 → 根据 RL 策略选择动作（是否压实）
   ↓
执行 Compaction (LevelK or Aggressive)
   ↓
计算 reward（比如延迟变化）
   ↓
UpdateAfterAction(level, action, reward)
 → 更新 Q 表
