import io, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
path = r"E:\SteamLibrary\steamapps\common\Probably Stolen\Probably Stolen_Data\resources.assets"
data = open(path, "rb").read()
for needle in ["水桶", "水箱", "水壶", "6升", "6 升", "桶装水", "water_jug", "water_jug_name", "item_water_jug"]:
    b = needle.encode("utf-8")
    idxs = []
    start = 0
    while True:
        i = data.find(b, start)
        if i < 0: break
        idxs.append(i); start = i + 1
        if len(idxs) >= 8: break
    print(f"--- {needle!r}: {len(idxs)} hits")
    for i in idxs:
        ctx = data[max(0,i-250):i+250].decode("utf-8", "replace").replace("\x00"," ").replace("\n"," ")
        print(f"  @{i}: {ctx}")
