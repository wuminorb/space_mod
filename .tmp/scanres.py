import re, sys
path = r"E:\SteamLibrary\steamapps\common\Probably Stolen\Probably Stolen_Data\resources.assets"
data = open(path, "rb").read()
print("size", len(data))
for needle in ["6L", "6 L", "6l", "大桶", "升", "桶装", "6升"]:
    b = needle.encode("utf-8")
    idxs = []
    start = 0
    while True:
        i = data.find(b, start)
        if i < 0: break
        idxs.append(i)
        start = i + 1
        if len(idxs) >= 20: break
    print(f"--- {needle!r}: {len(idxs)} hits")
    for i in idxs:
        ctx = data[max(0,i-200):i+200].decode("utf-8", "replace").replace("\n"," ")
        print(f"  @{i}: {ctx}")
