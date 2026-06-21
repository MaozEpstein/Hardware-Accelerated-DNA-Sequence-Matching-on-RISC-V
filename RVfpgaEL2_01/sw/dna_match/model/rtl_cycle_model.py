# Cycle-accurate model mirroring sw_pe.sv register semantics EXACTLY.
# Verifies the systolic timing (diag/up/left alignment) reproduces the scores.
W = 8
MATCH, MISMATCH, GAP_OPEN, GAP_EXT = 2, -1, -4, -1
NEG_INF = -(1 << (W-1))                 # most-negative => saturating sentinel
LO, HI = -(1 << (W-1)), (1 << (W-1)) - 1

def sadd(a, b):
    t = a + b
    return HI if t > HI else (LO if t < LO else t)

def mx(a, b): return a if a > b else b

B = {'A':0,'C':1,'G':2,'T':3}

class PE:
    def __init__(self, q):
        self.q = q
        self.m = 0; self.i = NEG_INF; self.d = NEG_INF; self.diag = 0
        self.out_ref = 0; self.out_valid = 0
        self.cell_valid = 0; self.cell_m = 0
    def comb(self, in_valid, in_ref, up_m, up_i):
        s = MATCH if self.q == in_ref else MISMATCH
        ni = mx(sadd(up_m, GAP_OPEN), sadd(up_i, GAP_EXT))
        nd = mx(sadd(self.m, GAP_OPEN), sadd(self.d, GAP_EXT))
        nm = mx(mx(0, sadd(self.diag, s)), mx(ni, nd))
        return ni, nd, nm
    def tick(self, in_valid, in_ref, up_m, up_i):
        ni, nd, nm = self.comb(in_valid, in_ref, up_m, up_i)
        if in_valid:
            self.diag = up_m
            self.m = nm; self.i = ni; self.d = nd
        self.out_ref = in_ref; self.out_valid = in_valid
        self.cell_valid = in_valid; self.cell_m = nm

def score(ref, query):
    N = len(query)
    pes = [PE(B[query[k]]) for k in range(N)]
    best = 0
    ref_codes = [B[c] for c in ref]
    # run enough cycles for the wave to traverse + drain
    for t in range(1, N + len(ref) + 4):
        # capture global max from registered cell outputs (previous edge)
        for pe in pes:
            if pe.cell_valid and pe.cell_m > best:
                best = pe.cell_m
        # sample current registered outputs (read-before-write snapshot)
        snap = [(pe.out_valid, pe.out_ref, pe.m, pe.i) for pe in pes]
        # controller feeds PE0 during cycles 1..len(ref)
        if 1 <= t <= len(ref):
            v0, r0, um0, ui0 = 1, ref_codes[t-1], 0, NEG_INF
        else:
            v0, r0, um0, ui0 = 0, 0, 0, NEG_INF
        # tick all PEs simultaneously
        for idx, pe in enumerate(pes):
            if idx == 0:
                pe.tick(v0, r0, um0, ui0)
            else:
                pv, pr, pm, pi = snap[idx-1]
                pe.tick(pv, pr, pm, pi)
    # final drain capture
    for pe in pes:
        if pe.cell_valid and pe.cell_m > best:
            best = pe.cell_m
    return best

QUERY = "ACGTCGTACGTACGTA"
REFS = ["ACGTACGTACGTACGT","ACGTTCGTACGTACGT","ACGTACGGACGTACGT","TTTTTTTTTTTTTTTT",
        "ACGTACGTTCGTACGT","ACGTACGTACGTACGA","ACGTTTGTACGTACGT","ACGTACGTGCGTACGT"]
EXPECTED = [26,26,23,2,23,24,23,23]
got = [score(r, QUERY) for r in REFS]
print("got     :", got)
print("expected:", EXPECTED)
print("RESULT  :", "OK - systolic timing verified" if got==EXPECTED else "MISMATCH - timing bug")
