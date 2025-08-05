import matplotlib.pyplot as plt
import numpy as np

levels = np.arange(5)
plt.rcParams["font.family"] = "serif"

# Level별 Miss와 Hit
baseline_negative2 = np.array([903972386, 22940008, 61829286, 61460144, 0])
baseline_positive2 = np.array([636626 , 715122, 8931590, 71547631, 69170031])

plt.figure(figsize=(6,6))

# 막대 그리기
plt.bar(levels, baseline_negative2, width=0.5, label='Miss', edgecolor='black', color='#3f8efc')
plt.bar(levels, baseline_positive2, width=0.5, bottom=baseline_negative2,
        label='Hit', color='#fdc500', edgecolor='black')

plt.ylabel("Count", fontsize=26)

ax = plt.gca()
ax.yaxis.get_offset_text().set_fontsize(26)
plt.xticks(levels, [f"L{i}" for i in levels], fontsize=24)
plt.yticks(fontsize=24)
plt.legend(fontsize=22)
plt.grid(axis='y', linestyle='--', color='gray')

# 전체 Read Amplification 계산
total_miss = np.sum(baseline_negative2)
total_hit = np.sum(baseline_positive2)

if total_hit > 0:
    overall_ra = (total_miss + total_hit) / total_hit
    ra_text = f"Read Amplification = {overall_ra:.2f}"
else:
    ra_text = "Read Amplification = ∞"

# 그래프 위쪽 중앙에 텍스트로 표시
max_height = (baseline_negative2 + baseline_positive2).max()
plt.text(len(levels) / 2 - 0.5, max_height * 1.15, ra_text, ha='center', va='bottom', fontsize=24, fontweight='bold')

plt.tight_layout()
plt.show()
