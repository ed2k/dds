# DDS Optimization TODO Roadmap

This document outlines potential performance optimization opportunities identified for the Double Dummy Solver (DDS) C++ engine in [`library/src/`](file:///Users/admin/Documents/GitHub/dds/library/src/).

---

## 1. SIMD Vectorization & Bit Manipulation Instructions

- [ ] **4-Suit Parallel SIMD Vectorization**:
  - Convert scalar 4-suit loops (`for (int ss = 0; ss < DDS_SUITS; ss++)`) in `QuickTricks`, move generation, and mask comparisons to SIMD vector operations.
  - Utilize 64-bit / 128-bit SIMD registers (AVX2, ARM NEON, WASM SIMD128) to process Spades, Hearts, Diamonds, and Clubs concurrently.
- [ ] **Hardware Bit Intrinsics**:
  - Replace loop-based card count and rank scanning logic with hardware intrinsics:
    - `POPCNT` / `__builtin_popcount` for suit length computation.
    - `CTZ` / `CLZ` (`__builtin_ctz`, `__builtin_clz`) for rank mask scanning.

---

## 2. Transposition Table (TT) Hashing & Memory Locality

- [ ] **Expanded Hash Table Capacity**:
  - Replace the current 8-bit hash table (256 buckets) in [`trans_table_l.cpp`](file:///Users/admin/Documents/GitHub/dds/library/src/trans_table/trans_table_l.cpp) with a larger 12-bit or 16-bit hash table to reduce linear scan collisions under heavy search trees.
  - Evaluate open-addressing hash strategies (e.g., Robin Hood or Cuckoo hashing).
- [ ] **SIMD Vector Lookup Comparisons**:
  - Parallelize 32-bit suit vector and rank mask comparisons in `TransTable::lookup()` using 128-bit vector instructions.
- [ ] **Depth-Aware Replacement Policy**:
  - Replace simple cyclic FIFO page overwriting with a depth-aware replacement policy that prioritizes keeping deeper search nodes in memory.
- [ ] **Killer Moves Storage**:
  - Extend [`NodeCards`](file:///Users/admin/Documents/GitHub/dds/library/src/trans_table/trans_table.hpp#L52) to store 2–3 secondary "killer moves" per TT entry to provide immediate candidate alternatives when primary best moves are blocked or illegal in transposed nodes.

---

## 3. Fast-Path Execution & Branch Optimization

- [ ] **Singleton / Forced Move Fast-Path**:
  - Short-circuit [`MoveOrdering`](file:///Users/admin/Documents/GitHub/dds/library/src/heuristic_sorting/heuristic_sorting.cpp) when a hand has only 1 legal card (singleton / forced play) to bypass heuristic weight calculation.
- [ ] **Compiler Branch Prediction Hints**:
  - Add C++20 `[[likely]]` / `[[unlikely]]` (or `__builtin_expect`) hints on high-frequency alpha-beta cutoffs (`if (value == TRUE) goto searchExit;`).
- [ ] **Profile-Guided Optimization (PGO)**:
  - Configure build targets to support PGO (`-fprofile-generate` / `-fprofile-use`) using standardized benchmark deals.

---

## 4. Cache-Line Alignment & Arena Allocation

- [ ] **Cache Line Alignment (`alignas(64)`)**:
  - Align per-thread search state structures ([`ThreadData`](file:///Users/admin/Documents/GitHub/dds/library/src/solver_context/solver_context.hpp)) to 64-byte boundaries to eliminate false sharing during multi-threaded `SolveAllBoards` calls.
- [ ] **Contiguous Arena Memory Allocators**:
  - Replace dynamic node heap allocations with contiguous arena memory pools to increase CPU L1/L2 cache hit rates.

---

## 5. WebAssembly (WASM) & Web Performance

- [ ] **WASM SIMD Compilation (`-msimd128`)**:
  - Enable WebAssembly 128-bit SIMD in Emscripten build flags for web deployments (e.g., [`web/dds_api_demo.html`](file:///Users/admin/Documents/GitHub/dds/web/dds_api_demo.html)).
- [ ] **Multi-Threaded Web Workers (`-pthread`)**:
  - Enable WebAssembly multithreading with `SharedArrayBuffer` to distribute `SolveAllBoards` across Web Workers.
- [ ] **Pre-Allocated Linear Memory Arenas**:
  - Pre-allocate WASM linear memory pools at startup to prevent memory re-allocations and GC pauses during interactive solving.

---

## 6. Move Ordering & Search Tree Heuristics

- [ ] **Machine Learning Weight Optimization**:
  - Train heuristic card-weighting parameters in [`heuristic_sorting.cpp`](file:///Users/admin/Documents/GitHub/dds/library/src/heuristic_sorting/heuristic_sorting.cpp) using supervised regression / gradient boosting trained over large double-dummy search tree datasets to replace hand-tuned 2010 constants.
- [ ] **History Heuristic & Butterfly Tables**:
  - Implement a global History Table (`history_score[hand][suit][rank]`) accumulating cutoff depth credits to order non-TT quiet moves across sibling subtrees.
- [ ] **Principal Variation Search (PVS) & Late Move Pruning**:
  - Apply PVS zero-window searching for moves after the principal move, and defer full move generation for deep candidate moves when top moves consistently produce cutoffs.

---

## 7. Target Binary Search & Cutoff Heuristics

- [ ] **Aspiration Windowing in `SolveBoard`**:
  - Replace wide binary search bounds $[0, 13]$ in [`solve_board.cpp`](file:///Users/admin/Documents/GitHub/dds/library/src/solve_board.cpp) with narrow Aspiration Windows $[T_{expected} - 1, T_{expected} + 1]$ centered on quick trick estimates to reduce search passes from 4 to 1–2 on average.
- [ ] **Cross-Target Transposition Table Reuse**:
  - Preserve valid upper/lower bounds across target iterations (`target = T` to `target = T + 1`) to eliminate redundant tree revisits.
- [ ] **Running Suit Promotion in `QuickTricks`**:
  - Enhance [`quick_tricks.cpp`](file:///Users/admin/Documents/GitHub/dds/library/src/quick_tricks.cpp) with suit promotion detection (counting sure tricks in long suits like AKQJ10 in NT when entry is guaranteed) to trigger cutoffs 3–4 tricks earlier.
- [ ] **Cross-Ruff Lower Bounds**:
  - Detect guaranteed cross-ruff tricks in suit contracts (void hands with top trumps) to boost lower-bound QuickTricks estimates.
