# https://adventofcode.com/2025/day/3

with open("../../inputs/day03.txt") as f:
    banks = [bank for bank in f.read().split()]


def get_max_joltage(k, banks=banks):
    ans = 0
    for bank_digits in banks:
        stack = []
        n = len(bank_digits)
        # print(n)

        for i, digit in enumerate(bank_digits):
            # limit is the number of items we can safely pop while ensuring
            # we can still fill the stack to size k with the remaining digits.
            # remaining digits available after this one = n - 1 - i
            # current stack size = len(stack)
            # we need final size = k

            while stack and stack[-1] < digit:
                # can we afford to pop?
                # (Current stack size - 1) + (remaining digits including current) >= k
                remaining_after_pop = (len(stack) - 1) + (n - i)
                if remaining_after_pop >= k:
                    stack.pop()
                else:
                    break

            if len(stack) < k:
                stack.append(digit)

        ans += int("".join(stack))
    return ans


p1 = get_max_joltage(2)
p2 = get_max_joltage(12)
print(f"Part 1: {p1}\nPart 2: {p2}")
assert p1 == 17301
assert p2 == 172162399742349
