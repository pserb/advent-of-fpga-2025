# https://adventofcode.com/2025/day/1

pos, p1, p2 = 50, 0, 0

with open("../../inputs/day01.txt") as f:
    ops = [(x[0], int(x[1:])) for x in f.read().split()]

for direction, val in ops:
    if direction == "R":
        wraps, pos = divmod(pos + val, 100) # https://docs.python.org/3/library/functions.html#divmod
        p2 += wraps
    else:
        # if we start at 0 and move left, we leave 0 (going to 99). do not count that as 'clicking onto 0'
        start_sector = -1 if pos == 0 else 0
        end_sector, rem = divmod(pos - 1 - val, 100)
        p2 += start_sector - end_sector
        pos = 0 if rem == 99 else rem + 1

    if pos == 0:
        p1 += 1

print(f"Part 1: {p1}\nPart 2: {p2}")
