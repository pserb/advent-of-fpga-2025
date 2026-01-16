with open("../../inputs/day12.txt") as f:
    lines = [line for line in f.read().split("\n")]


def solve():
    ans = 0
    # ignore the shape definition of the presents, and go straight to region definitions
    # region is of the form (4x4: 0 1 2 3 4)
    for region in lines[30:]:
        if not len(region) > 0:
            continue
        spl = region.split(":")
        region_size = spl[0].strip().split("x")
        region_w = region_size[0]
        region_h = region_size[1]
        region_presents = spl[1].strip().split(" ")
        # there are only two real cases (we aren't solving a NP-complete problem here)
        # case 1: the number of spots presents take up (3 * 3 * N_presents) is greater than the region size (region_w * region_h)
        present_sum = 0
        for present in region_presents:
            present_sum += int(present)

        if (3 * 3 * present_sum) > (int(region_w) * int(region_h)):
            continue

        # case 2: then, each present fits in its own discrete 3x3 spot of the region (max present size is 3x3). shape doesn't matter
        ans += 1

    return ans


p1 = solve()
print(f"Part 1: {p1}")
assert p1 == 595
