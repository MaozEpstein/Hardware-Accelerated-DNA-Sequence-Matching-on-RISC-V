# Bit-exact model of the systolic Smith-Waterman (affine gap) accelerator.
# Goal: find the minimum signed bit-width W (and a saturating sentinel for NEG_INF)
# that still reproduces the reference scores 26,26,23,2,23,24,23,23.
#
# Hardware reality: every M/I/D register is W-bit signed with saturating add.
# NEG_INF is modeled as the most-negative representable value (saturates, never wins a max).

MATCH, MISMATCH, GAP_OPEN, GAP_EXT = 2, -1, -4, -1

QUERY = "ACGTCGTACGTACGTA"
REFS = [
    "ACGTACGTACGTACGT", "ACGTTCGTACGTACGT", "ACGTACGGACGTACGT",
    "TTTTTTTTTTTTTTTT", "ACGTACGTTCGTACGT", "ACGTACGTACGTACGA",
    "ACGTTTGTACGTACGT", "ACGTACGTGCGTACGT",
]
EXPECTED = [26, 26, 23, 2, 23, 24, 23, 23]

def sat(v, W):
    """Saturate v to signed W-bit range."""
    lo, hi = -(1 << (W - 1)), (1 << (W - 1)) - 1
    return max(lo, min(hi, v))

def add(a, b, W):
    return sat(a + b, W)

def mx(*xs):
    return max(xs)

def sw_bitexact(ref, query, W):
    NEG = -(1 << (W - 1))          # most-negative => saturating sentinel for NEG_INF
    rows, cols = len(query) + 1, len(ref) + 1
    M = [[0] * cols for _ in range(rows)]
    I = [[NEG] * cols for _ in range(rows)]
    D = [[NEG] * cols for _ in range(rows)]
    best = 0
    for i in range(1, rows):
        for j in range(1, cols):
            s = MATCH if query[i-1] == ref[j-1] else MISMATCH
            I[i][j] = mx(add(M[i-1][j], GAP_OPEN, W), add(I[i-1][j], GAP_EXT, W))
            D[i][j] = mx(add(M[i][j-1], GAP_OPEN, W), add(D[i][j-1], GAP_EXT, W))
            M[i][j] = sat(mx(0, add(M[i-1][j-1], s, W), I[i][j], D[i][j]), W)
            if M[i][j] > best:
                best = M[i][j]
    return best

for W in range(6, 13):
    got = [sw_bitexact(r, QUERY, W) for r in REFS]
    ok = (got == EXPECTED)
    print(f"W={W:2d} bits  signed[{-(1<<(W-1))}..{(1<<(W-1))-1}]  -> {got}  {'OK' if ok else 'MISMATCH'}")

print("\nExpected:", EXPECTED)
