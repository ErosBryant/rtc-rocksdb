
import matplotlib.pyplot as plt
import numpy as np
import matplotlib.ticker as mticker

levels = np.arange(4)
plt.rcParams["font.family"] = "serif"

# 두 번째 데이터셋 (LevelDB)
# baseline_negative2 = np.array([154907772,  4588646, 32740810,        0])
# baseline_positive2 = np.array([ 18273955,   493739, 37470195, 37103474])

baseline_negative2 = np.array([27360494,  5156738, 2549377,        0])

baseline_positive2 = np.array([ 1889617,   3088084, 32773040, 112157448])


# 119591064, 18087201, 18396681, 10350501, 0
# 38739 , 167197, 398464, 13974456,25343614

# waitforcompaction

# 39922470
plt.figure(figsize=(6,6))
# 아래의 막대: Miss
plt.bar(levels, baseline_negative2, width=0.5, 
        label='Hit', color='#fdc500', edgecolor='black')

plt.bar(levels, baseline_negative2, width=0.5,bottom=baseline_positive2,  label='Miss', edgecolor='black', color='#3f8efc')
# 위에 쌓이는 막대: Hit

# , hatch='//'

plt.ylabel("Count", fontsize=26)

# 현재 Axes 객체 가져와서 y축 오프셋 텍스트 폰트 크기 조정
ax = plt.gca()
ax.yaxis.get_offset_text().set_fontsize(26)

# x축 눈금을 L0, L1, L2, L3, L4로 설정
plt.xticks(levels, [f"L{i}" for i in levels], fontsize=24)
plt.yticks(fontsize=24)
plt.legend(fontsize=22)
# plt.ylim(0, baseline_negative2.max() * 1.1)
plt.grid(axis='y', linestyle='--', color='gray')


# 각 Level의 막대 위에 텍스트를 표시 (L0만 x축 위치를 오른쪽으로 이동)
# for i, (neg, pos) in enumerate(zip(baseline_negative2, baseline_positive2)):
#     total = neg  # 만약 두 값의 합을 원한다면: neg + pos
#     if i == 0:  # L0의 경우: 오프셋과 함께 x 위치 이동
#         offset = 1000000
#         x_pos = i + 0.8  # 오른쪽으로 0.4만큼 이동
#     elif i == 1:
#         offset = 2000000
#         x_pos = i+0.4
#     elif i == 4:
#         offset = 23000000
#         x_pos = i+0.3
#     else:
#         offset = 17000000 if total < 50e6 else total * 0.02
#         x_pos = i
#     plt.text(x_pos, total + offset, f'{total}', ha='center', va='bottom', fontsize=24)

# ■ 여기부터 scilimits=(8,8)로 지수부를 8로 강제  
# ① useMathText=False 로 설정
# formatter = mticker.ScalarFormatter(useMathText=False)
# ② 지수부를 8로 고정
# formatter.set_powerlimits((8,8))

# ax.yaxis.set_major_formatter(formatter)
# (필요하다면)
# ax.yaxis.offsetText.set_fontsize(22)

plt.tight_layout()
plt.show()
