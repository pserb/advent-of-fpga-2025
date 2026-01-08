# https://adventofcode.com/2025/day/2

with open("../../inputs/day02.txt") as f:
    id_ranges = [
        (int(y[0]), int(y[1]))
        for y in [x.split("-") for x in f.read().strip().split(",")]
    ]

# (step, start, end)
PART1_CONSTANTS = [
    (11, 11, 99),
    (101, 1010, 9999),
    (1001, 100100, 999999),
    (10001, 10001000, 99999999),
    (100001, 1000010000, 9999999999),
]
PART2_CONSTANTS = [
    (111, 111, 999),
    (11111, 11111, 99999),
    (10101, 101010, 999999),
    (1111111, 1111111, 9999999),
    (1001001, 100100100, 999999999),
    (101010101, 1010101010, 9999999999),
]
OVERLAP_CONSTANTS = [
    (111111, 111111, 999999),
    (1111111111, 1111111111, 9999999999),
]


def sum_for_constants(constants):
    total = 0
    for step, start, end in constants:
        for low, high in id_ranges:
            # find bounds for invalid patterns within low-high range
            lower_bound = max(((low + step - 1) // step) * step, start)
            upper_bound = min(high, end)

            if lower_bound > upper_bound:
                continue

            # find the number of invalid ids within the bounded range
            # do this by calculating how many multiples of the step can fit
            # within the range
            # aka: lower + 0*step, lower + 1*step, lower + 2*step, ..., upper
            n_invalid_ids = (upper_bound - lower_bound) // step + 1

            # use triangular formula to sum the arithemtic series of ids:
            # n(n-1)/2
            triangular_number = n_invalid_ids * (n_invalid_ids - 1) // 2
            total += (n_invalid_ids * lower_bound) + (step * triangular_number)
    return total


p1 = sum_for_constants(PART1_CONSTANTS)
p2 = p1 + sum_for_constants(PART2_CONSTANTS) - sum_for_constants(OVERLAP_CONSTANTS)

print(f"Part 1: {p1}\nPart 2: {p2}")
