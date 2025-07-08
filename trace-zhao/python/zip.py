import matplotlib.pyplot as plt
import numpy as np

# 파일에서 모든 level 읽기
with open("/home/eros/forRTC/rocksdb/trace-zhao/result/150m_zip_miss.csv", "r") as f:
# with open("/home/sslab/zhao/rtc-rocksdb/trace-zhao/level_get_zip.csv", "r") as f:
    line = f.readline().strip()
    levels = [int(ch) for ch in line if ch in '0123']

levels = np.array(levels)
total_points = len(levels)
plt.rcParams["font.family"] = "serif"

# 파라미터 설정
num_bins = 100  # 시간 축 분할 수 (수평 방향 구간 수)
max_level = 4    # level 0~5

# 각 bin당 몇 개의 entry가 들어가는지
chunk_size = total_points // num_bins

# 히트맵 데이터 초기화
heat_data = np.zeros((max_level, num_bins), dtype=int)

# 각 bin 구간마다 level 빈도 세기
for i in range(num_bins):
    start = i * chunk_size
    end = (i + 1) * chunk_size if i < num_bins - 1 else total_points
    chunk = levels[start:end]
    for level in range(max_level):
        heat_data[level, i] = np.sum(chunk == level)

# 히트맵 시각화


perm = np.random.permutation(num_bins)
heat_data_shuffled = heat_data[:, perm]

plt.figure(figsize=(16, 5))
plt.imshow(heat_data_shuffled, aspect='auto', cmap='Blues', origin='lower')



# plt.figure(figsize=(16, 5))
# plt.imshow(heat_data, aspect='auto', cmap='Blues', origin='lower')


cbar = plt.colorbar(label='Frequency')
cbar.ax.tick_params(labelsize=15)  # 눈금 폰트 크기 설정
cbar.set_label('Frequency', fontsize=22)  # 라벨 폰트 크기 설정
cbar.ax.yaxis.offsetText.set_fontsize(18)

plt.xlabel('Read Sequence (%)',fontsize=22)
plt.ylabel('Level',fontsize=22)
tick_pos = [0,
            int(0.25*(num_bins-1)),
            int(0.50*(num_bins-1)),
            int(0.75*(num_bins-1)),
            num_bins-1]

tick_labels = ['0','25','50','75','100']

plt.xticks(tick_pos, tick_labels, fontsize=18)
plt.yticks(range(max_level), labels=[str(i) for i in range(max_level)], fontsize=18)
plt.tight_layout()
# plt.savefig("hitmap_150m_zip.svg", format="svg")  # SVG format
plt.show()
