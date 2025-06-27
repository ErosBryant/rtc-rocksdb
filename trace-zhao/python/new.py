import matplotlib.pyplot as plt
import pandas as pd

# CSV 파일에서 level 데이터 읽기
df = pd.read_csv("/home/eros/forRTC/rocksdb/trace-zhao/level_get.csv", 
                 header=None, names=["level"])

levels = df["level"].astype(int).tolist()

# 시각화
plt.figure(figsize=(12, 6))
x = range(len(levels))
plt.vlines(x=x, ymin=0, ymax=levels, color='red', linewidth=0.5)

plt.xlabel("Time Step")
plt.ylabel("Level")
plt.title("Level GET Trace (Top-down View)")
plt.ylim(-0.5, 5.5)
plt.yticks(range(6))
plt.gca().invert_yaxis()
plt.grid(True, linestyle='--', linewidth=0.3)
plt.tight_layout()
plt.savefig("level_get_trace.png", dpi=300)
plt.show()
