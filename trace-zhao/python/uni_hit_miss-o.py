import matplotlib.pyplot as plt
import numpy as np

# 파일 경로 (경로는 환경에 맞게 수정하세요)
file_uni = "/home/eros/forRTC/rocksdb/trace-zhao/result/150m_uni.csv"
file_miss = "/home/eros/forRTC/rocksdb/trace-zhao/result/150m_uni_miss.csv"

# 파일에서 levels 읽기 함수
def read_levels(filepath, valid_levels):
    with open(filepath, "r") as f:
        line = f.readline().strip()
    return np.array([int(ch) for ch in line if ch in valid_levels])

# 데이터 읽기
levels_uni = read_levels(file_uni, '01234')    # 레벨 0~4
levels_miss = read_levels(file_miss, '0123')   # 레벨 0~3

# 파라미터
num_bins = 100

def compute_heat(levels, max_level):
    total_points = len(levels)
    chunk_size = total_points // num_bins
    heat = np.zeros((max_level, num_bins), dtype=int)
    for i in range(num_bins):
        start = i * chunk_size
        end = (i + 1) * chunk_size if i < num_bins - 1 else total_points
        chunk = levels[start:end]
        for lvl in range(max_level):
            heat[lvl, i] = np.sum(chunk == lvl)
    return heat

# heatmap 생성
heat_uni = compute_heat(levels_uni, max_level=5)  # 5 rows: L0~L4
heat_miss = compute_heat(levels_miss, max_level=4)  # 4 rows: L0~L3

# 시각화
plt.rcParams["font.family"] = "serif"
fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(16, 8), sharex=True)

# 상단: 150m_uni
im1 = ax1.imshow(heat_uni, aspect='auto', origin='lower', cmap='Blues')
ax1.set_title('150m_uni Level Frequency (L0–L4)', fontsize=20)
ax1.set_ylabel('Level', fontsize=18)
ax1.set_yticks(range(5))
ax1.set_yticklabels(range(5), fontsize=16)
fig.colorbar(im1, ax=ax1, label='Frequency')

# 하단: 150m_uni_miss
im2 = ax2.imshow(heat_miss, aspect='auto', origin='lower', cmap='Blues')
ax2.set_title('150m_uni_miss Level Frequency (L0–L3)', fontsize=20)
ax2.set_ylabel('Level', fontsize=18)
ax2.set_yticks(range(4))
ax2.set_yticklabels(range(4), fontsize=16)
fig.colorbar(im2, ax=ax2, label='Frequency')

# 공통 x축 설정
ax2.set_xlabel('Read Sequence (%)', fontsize=18)
ax2.set_xticks(np.linspace(0, num_bins-1, 6))
ax2.set_xticklabels([f'{int(x/(num_bins-1)*100)}%' for x in np.linspace(0, num_bins-1, 6)], fontsize=16)

plt.tight_layout()
plt.show()
