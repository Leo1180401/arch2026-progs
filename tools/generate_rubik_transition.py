factorial = [720, 120, 24, 6, 2, 1, 1]
source = [
    [1, 4, 2, 0, 3, 5, 6],  # R
    [0, 1, 2, 4, 5, 6, 3],  # B
    [0, 2, 5, 3, 1, 4, 6],  # D
    ]

twist = [
    [1, 2, 0, 2, 1, 0, 0],  # R
    [0, 0, 0, 1, 2, 1, 2],  # B
    [0, 0, 0, 0, 0, 0, 0],  # D
]

# Permutation → Rank，將七顆角塊轉換成0 ~ 5039的索引
def rank_perm(p):
    rank = 0;

    for i in range(7):
        smaller = 0

        for j in range(i+1, 7):
            # 判斷陣列後面相較於i小的數字，去計算幾種可能的排列數
            if p[j] < p[i]:
                smaller += 1

        rank = rank + smaller * factorial[i] #計算sigma(0~7)smaler * (7-i)!

    return rank


# Rank → Permutation，將索引還原成七顆幾塊排列
def unrank_perm(rank):
    available = list(range(7))
    result = []

    for i in range(7):
        index = rank // factorial[i]
        rank = rank % factorial[i]

        # 把已用過元素(index)後的陣列元素往前移一格
        number = available.pop(index)
        result.append(number)

    return tuple(result)


# 執行一次 R、B 或 D 旋轉
def turn_perm(p, face):
    result = []

    for i in range(7):
        from_index = source[face][i]
        result.append(p[from_index])
    return tuple(result)


def build_perm_table():
    pt = []

    # 儲存旋轉動作R,B,D(0,1,2)
    for face in range(3):
        row = []

        for rank in range(5040):
            p = unrank_perm(rank)

            new_p = turn_perm(p, face) #重新排列角塊結果(直接按照結果重排即可)

            new_rank = rank_perm(new_p)#把旋轉後的排例重新轉乘0 ~ 5039的整數

            row.append(new_rank)       #把剛計算的新Rank排進row裡面

        pt.append(row)

    return pt

pt = build_perm_table()

# orientation → Rank，將七顆角塊轉換成0 ~ 728的索引
def rank_orient(o):
    rank = 0

    for i in range(6):
        rank = rank * 3 + o[i] #因為3進位

    return rank

# Rank → Orientation，將索引還原成七顆幾塊面朝向
def unrank_orient(rank):
    result = [0] * 7     # result = [0,0,0,0,0,0,0]
    total = 0

    for i in range(5, -1, -1):  # 代表5,4,3,2,1,0，因為rank % 3，每次取得三進位數字的最低為，必須從第六個數字往前填
        result[i] = rank % 3
        rank //= 3
        total += result[i]

    result[6] = (-total) % 3

    return tuple(result)

# 執行一次R, B, D旋轉
def turn_orient(o, face):
    result = []

    for i in range(7):
        from_index = source[face][i]

        new_o = (o[from_index] + twist[face][i]) % 3

        result.append(new_o)

    return tuple(result)


def build_orient_table():
    ot = []

    for face in range(3):
        row = []

        for rank in range(729):
            o = unrank_orient(rank)

            new_o = turn_orient(o, face)

            new_rank = rank_orient(new_o)

            row.append(new_rank)

        ot.append(row)

    return ot


print("Number of faces:", len(pt))
print("R entries:", len(pt[0]))
print("B entries:", len(pt[1]))
print("D entries:", len(pt[2]))

print("Solved -> R:", pt[0][0])



for face in range(3):
    for rank in range(5040):
        current = rank

        for _ in range(4):
            current = pt[face][current]

        assert current == rank

print("Permutation transition table: PASS")

print("Test rank:")
print(rank_perm([1, 4, 2, 0, 3, 5, 6]))
print("Test unrank:")
print(unrank_perm(0))
print(unrank_perm(720))
print("Test turn:")
print(turn_perm([0, 1, 2, 3, 4, 5, 6], 0))

print("=== Debugging ===")

print("Rank test:",
      rank_perm([1, 4, 2, 0, 3, 5, 6]))

print("Unrank 0:",
      unrank_perm(0))

print("Unrank 720:",
      unrank_perm(720))

print("Turn R:",
      turn_perm([0, 1, 2, 3, 4, 5, 6], 0))



ot = build_orient_table()

print("Orientation faces:", len(ot))
print("R orientation entries:", len(ot[0]))
print("B orientation entries:", len(ot[1]))
print("D orientation entries:", len(ot[2]))

print("Solved orientation -> R:", ot[0][0])

# 驗證四次旋轉歸零
for face in range(3):
    for rank in range(729):
        current = rank

        for _ in range(4):
            current = ot[face][current]

        assert current == rank

print("Orientation transition table: PASS")

# 驗證全部 Permutation Rank
for rank in range(5040):
    p = unrank_perm(rank) #先把整數Rank還原成排列

    assert rank_perm(p) == rank #確定重新編碼後，還是可以得到原本的Rank

    for face in range(3):
        expected = rank_perm(turn_perm(p, face)) #用原本的旋轉規則，獨立計算預期的結果

        assert pt[face][rank] == expected        #確認Transition的資料和直接計算相同

print("Full permutation verification: PASS")


# 驗證全部 Orientation Rank
for rank in range(729):
    o = unrank_orient(rank)

    assert rank_orient(o) == rank
    assert sum(o) % 3 == 0

    for face in range(3):
        expected = rank_orient(turn_orient(o, face))

        assert ot[face][rank] == expected

print("Full orientation verification: PASS")



from pathlib import Path

output = Path("src/rubik/rubik_transition.h")

with output.open("w") as f:
    f.write("#pragma once\n")
    f.write("#include <stdint.h>\n\n")

    f.write("static const uint16_t pt[3][5040] = {\n")

    for row in pt:
        f.write("    {\n")

        for i in range(0, len(row), 16): #range(start, stop, step)
            values = row[i:i + 16]       #做slicing，假設number=[10, 20, 30, 40, 50]，則number[1:4]=[20, 30, 40]
            f.write("        " + ", ".join(map(str, values)) + ",\n")

        f.write("    },\n")

    f.write("};\n\n")

    f.write("static const uint16_t ot[3][729] = {\n")

    for row in ot:
        f.write("    {\n")

        for i in range(0, len(row), 16):
            values = row[i:i + 16]
            f.write("        " + ", ".join(map(str, values)) + ",\n")

        f.write("    },\n")

    f.write("};\n")

print("Generated:", output)
