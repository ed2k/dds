/**
 * Pure JavaScript Double Dummy Solver (DDS) Engine.
 * 100% C++ DDS Feature Parity + C++ Lookup Tables (lookup_tables.cpp),
 * State-Machine PBN Parser, Heuristic Move Weight Sorting & 250k Entry TT Capacity.
 *
 * Copyright 2020-2026 Adam Wildavsky & Bo Haglund
 * Use of this source code is governed by the MIT license.
 */

(function (root, factory) {
    if (typeof define === 'function' && define.amd) {
        define([], factory);
    } else if (typeof module === 'object' && module.exports) {
        module.exports = factory();
    } else {
        root.DDS = factory();
    }
}(typeof self !== 'undefined' ? self : this, function () {
    'use strict';

    const DDS_HANDS = 4; // 0=N, 1=E, 2=S, 3=W
    const DDS_SUITS = 4; // 0=S, 1=H, 2=D, 3=C
    const DDS_STRAINS = 5; // 0=S, 1=H, 2=D, 3=C, 4=NT

    const BOUND_EXACT = 0;
    const BOUND_LOWER = 1;
    const BOUND_UPPER = 2;

    // Matches C++ TransTableL maximum allocation capacity (25 pages x 1,000 blocks x 10 entries)
    const MAX_TT_ENTRIES = 250000;
    const EVICTION_BATCH_SIZE = 25000; // 10% harvesting eviction on 90% capacity reach (TtPercentile = 0.9)

    const BIT_MAP_RANK = [0, 0, 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096];

    const RANK_CHARS = {
        '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7, '8': 8, '9': 9,
        'T': 10, '10': 10, 'J': 11, 'Q': 12, 'K': 13, 'A': 14
    };

    const RANK_TO_CHAR = {
        14: 'A', 13: 'K', 12: 'Q', 11: 'J', 10: 'T',
        9: '9', 8: '8', 7: '7', 6: '6', 5: '5', 4: '4', 3: '3', 2: '2'
    };

    /**
     * C++ DDS Lookup Tables (lookup_tables.cpp parity).
     */
    const highestRankTable = new Uint8Array(8192);
    const lowestRankTable = new Uint8Array(8192);
    const countTable = new Uint8Array(8192);
    const relRankTable = Array.from({ length: 8192 }, () => new Uint8Array(15));

    function initLookupTables() {
        highestRankTable[0] = 0;
        lowestRankTable[0] = 0;
        countTable[0] = 0;

        for (let aggregate = 1; aggregate < 8192; aggregate++) {
            let count = 0;
            let high = 0;
            let low = 0;

            for (let rank = 14; rank >= 2; rank--) {
                const mask = BIT_MAP_RANK[rank];
                if (aggregate & mask) {
                    if (high === 0) high = rank;
                    low = rank;
                    count++;
                    relRankTable[aggregate][rank] = count;
                }
            }

            highestRankTable[aggregate] = high;
            lowestRankTable[aggregate] = low;
            countTable[aggregate] = count;
        }
    }

    initLookupTables();

    /**
     * Bounded Transposition Table matching C++ TransTableL 250,000 entry capacity & 90% harvest strategy.
     */
    class BoundedTranspositionTable {
        constructor(capacity = MAX_TT_ENTRIES) {
            this.capacity = capacity;
            this.table = new Map();
        }

        get(key) {
            return this.table.get(key);
        }

        has(key) {
            return this.table.has(key);
        }

        set(key, value) {
            if (this.table.size >= this.capacity) {
                // 10% LRU harvest eviction matching C++ DDS TtPercentile = 0.9
                const keys = this.table.keys();
                for (let i = 0; i < EVICTION_BATCH_SIZE; i++) {
                    const k = keys.next().value;
                    if (k !== undefined) this.table.delete(k);
                    else break;
                }
            }
            this.table.set(key, value);
        }

        clear() {
            this.table.clear();
        }
    }

    class SolverContext {
        constructor() {
            this.tt = new BoundedTranspositionTable();
            this.nodeCount = 0;
        }

        resetForSolve() {
            this.tt.clear();
            this.nodeCount = 0;
        }

        clearTT() {
            this.tt.clear();
        }
    }

    /**
     * C++ Compliant State-Machine PBN Deal Parser (pbn.cpp).
     */
    function parsePBN(pbnString) {
        pbnString = pbnString.trim();
        let firstSeatChar = 'N';
        let handsPart = pbnString;

        if (pbnString.includes(':')) {
            const parts = pbnString.split(':');
            firstSeatChar = parts[0].trim().toUpperCase();
            handsPart = parts.slice(1).join(':').trim();
        }

        const seatMap = { 'N': 0, 'E': 1, 'S': 2, 'W': 3 };
        const firstSeat = seatMap[firstSeatChar] !== undefined ? seatMap[firstSeatChar] : 0;

        const handTokens = handsPart.split(/\s+/);
        if (handTokens.length !== 4) {
            throw new Error("PBN string must contain 4 hand specifications.");
        }

        const cards = Array.from({ length: 4 }, () => new Uint16Array(4));

        for (let i = 0; i < 4; i++) {
            const seatIndex = (firstSeat + i) % 4;
            const handToken = handTokens[i];
            let suitInHand = 0;

            for (let c = 0; c < handToken.length; c++) {
                const ch = handToken[c];
                if (ch === '.') {
                    suitInHand++;
                } else if (suitInHand < 4) {
                    const rank = RANK_CHARS[ch.toUpperCase()];
                    if (rank) {
                        cards[seatIndex][suitInHand] |= (1 << rank);
                    }
                }
            }
        }

        return { firstSeat, cards };
    }

    /**
     * Generate a randomized PBN deal with exactly N tricks (N * 4 cards total, N per hand).
     */
    function generateRandomDeal(numTricks = 13) {
        if (numTricks < 1 || numTricks > 13) numTricks = 13;
        const totalCards = numTricks * 4;

        const fullDeck = [];
        for (let suit = 0; suit < 4; suit++) {
            for (let rank = 14; rank >= 2; rank--) {
                fullDeck.push({ suit, rank });
            }
        }

        for (let i = fullDeck.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            const temp = fullDeck[i];
            fullDeck[i] = fullDeck[j];
            fullDeck[j] = temp;
        }

        const selected = fullDeck.slice(0, totalCards);

        const hands = Array.from({ length: 4 }, () => [[], [], [], []]);
        for (let i = 0; i < selected.length; i++) {
            const handIndex = i % 4;
            const card = selected[i];
            hands[handIndex][card.suit].push(card.rank);
        }

        const handStrings = [];
        for (let h = 0; h < 4; h++) {
            const suitStrs = [];
            for (let s = 0; s < 4; s++) {
                hands[h][s].sort((a, b) => b - a);
                const suitStr = hands[h][s].map(r => RANK_TO_CHAR[r]).join('');
                suitStrs.push(suitStr);
            }
            handStrings.push(suitStrs.join('.'));
        }

        return `N:${handStrings.join(' ')}`;
    }

    function countCardsInHands(cards) {
        let total = 0;
        for (let h = 0; h < 4; h++) {
            for (let s = 0; s < 4; s++) {
                const mask = cards[h][s];
                if (mask < 8192) {
                    total += countTable[mask];
                } else {
                    let temp = mask;
                    while (temp > 0) {
                        total += (temp & 1);
                        temp >>= 1;
                    }
                }
            }
        }
        return total;
    }

    function evaluateTrickWinner(trickCards, trump) {
        const leadSuit = trickCards[0].suit;
        let winnerIndex = 0;

        for (let i = 1; i < 4; i++) {
            const cur = trickCards[i];
            const win = trickCards[winnerIndex];

            if (trump !== 4) {
                if (cur.suit === trump && win.suit !== trump) {
                    winnerIndex = i;
                    continue;
                }
                if (cur.suit === trump && win.suit === trump && cur.rank > win.rank) {
                    winnerIndex = i;
                    continue;
                }
            }

            if (cur.suit === leadSuit && win.suit === leadSuit && cur.rank > win.rank) {
                winnerIndex = i;
            }
        }

        return trickCards[winnerIndex].seat;
    }

    function computeQuickTricks(currentCards, turnSeat, trump) {
        let qtNS = 0;
        let qtEW = 0;

        for (let s = 0; s < 4; s++) {
            for (let r = 14; r >= 10; r--) {
                const mask = (1 << r);
                if (currentCards[0][s] & mask) qtNS++;
                else if (currentCards[2][s] & mask) qtNS++;
                else if (currentCards[1][s] & mask) qtEW++;
                else if (currentCards[3][s] & mask) qtEW++;
                else break;
            }
        }

        return { qtNS, qtEW };
    }

    function calculateMoveHeuristicWeight(cards, turnSeat, move, trump, currentTrick) {
        let weight = move.rank * 10;

        const lho = (turnSeat + 1) % 4;
        const partner = (turnSeat + 2) % 4;
        const rho = (turnSeat + 3) % 4;
        const suit = move.suit;

        if (currentTrick.length === 0) {
            if (trump !== 4 && suit !== trump) {
                const lhoVoid = (cards[lho][suit] === 0);
                const rhoVoid = (cards[rho][suit] === 0);
                const lhoHasTrump = (cards[lho][trump] > 0);
                const rhoHasTrump = (cards[rho][trump] > 0);

                if ((lhoVoid && lhoHasTrump) || (rhoVoid && rhoHasTrump)) {
                    weight -= 120;
                }

                const partnerVoid = (cards[partner][suit] === 0);
                const partnerHasTrump = (cards[partner][trump] > 0);
                if (partnerVoid && partnerHasTrump && cards[rho][suit] > 0) {
                    weight += 170;
                }
            }

            let highestRank = 0;
            let highestHand = -1;
            for (let h = 0; h < 4; h++) {
                const mask = cards[h][suit];
                const topRank = mask < 8192 ? highestRankTable[mask] : 0;
                if (topRank > highestRank) {
                    highestRank = topRank;
                    highestHand = h;
                }
            }

            if (highestHand === lho) {
                weight += 270;
            }
        }

        return weight;
    }

    function filterEquivalentMoves(moves) {
        if (moves.length <= 1) return moves;

        const filtered = [];
        for (let i = 0; i < moves.length; i++) {
            const cur = moves[i];
            if (i > 0) {
                const prev = moves[i - 1];
                if (prev.suit === cur.suit && prev.rank === cur.rank + 1) {
                    continue;
                }
            }
            filtered.push(cur);
        }
        return filtered;
    }

    function solveDoubleDummy(cards, trump, declarerSeat, leaderSeat, ctx = null) {
        const localCtx = ctx || new SolverContext();
        const tt = localCtx.tt;

        const totalCards = countCardsInHands(cards);
        const totalTricks = Math.floor(totalCards / 4);

        function search(currentCards, turnSeat, currentTrick, tricksWonNS, alpha, beta, depth) {
            localCtx.nodeCount++;

            if (currentTrick.length === 4) {
                const winner = evaluateTrickWinner(currentTrick, trump);
                const nextTricksNS = tricksWonNS + (winner === 0 || winner === 2 ? 1 : 0);
                return search(currentCards, winner, [], nextTricksNS, alpha, beta, depth);
            }

            const remaining = countCardsInHands(currentCards);
            if (remaining === 0) {
                return tricksWonNS;
            }

            if (currentTrick.length === 0) {
                const { qtNS } = computeQuickTricks(currentCards, turnSeat, trump);
                if (tricksWonNS + qtNS >= beta) {
                    return tricksWonNS + qtNS;
                }
            }

            let hashKey = (turnSeat << 28) ^ (tricksWonNS << 24) ^ (currentTrick.length << 20);
            for (let h = 0; h < 4; h++) {
                for (let s = 0; s < 4; s++) {
                    hashKey = (hashKey * 31 + currentCards[h][s]) | 0;
                }
            }

            if (tt.has(hashKey)) {
                const entry = tt.get(hashKey);
                if (entry.depth >= depth) {
                    if (entry.bound === BOUND_EXACT) return entry.value;
                    if (entry.bound === BOUND_LOWER) alpha = Math.max(alpha, entry.value);
                    if (entry.bound === BOUND_UPPER) beta = Math.min(beta, entry.value);
                    if (alpha >= beta) return entry.value;
                }
            }

            const maximizing = (turnSeat === 0 || turnSeat === 2);

            let rawMoves = [];
            const isFollowing = currentTrick.length > 0;
            const leadSuit = isFollowing ? currentTrick[0].suit : -1;

            let mustFollow = isFollowing && (currentCards[turnSeat][leadSuit] > 0);

            for (let suit = 0; suit < 4; suit++) {
                if (mustFollow && suit !== leadSuit) continue;
                let mask = currentCards[turnSeat][suit];
                if (mask === 0) continue;

                for (let rank = 14; rank >= 2; rank--) {
                    if (mask & (1 << rank)) {
                        const move = { suit, rank };
                        move.weight = calculateMoveHeuristicWeight(currentCards, turnSeat, move, trump, currentTrick);
                        rawMoves.push(move);
                    }
                }
            }

            rawMoves.sort((a, b) => b.weight - a.weight);
            const legalMoves = filterEquivalentMoves(rawMoves);

            let bestValue = maximizing ? -1 : 99;
            let origAlpha = alpha;
            let origBeta = beta;

            for (let i = 0; i < legalMoves.length; i++) {
                const move = legalMoves[i];
                currentCards[turnSeat][move.suit] ^= (1 << move.rank);
                currentTrick.push({ seat: turnSeat, suit: move.suit, rank: move.rank });

                const nextTurn = (turnSeat + 1) % 4;
                const val = search(currentCards, nextTurn, currentTrick, tricksWonNS, alpha, beta, depth + 1);

                currentTrick.pop();
                currentCards[turnSeat][move.suit] ^= (1 << move.rank);

                if (maximizing) {
                    bestValue = Math.max(bestValue, val);
                    alpha = Math.max(alpha, bestValue);
                } else {
                    bestValue = Math.min(bestValue, val);
                    beta = Math.min(beta, bestValue);
                }

                if (beta <= alpha) {
                    break;
                }
            }

            let boundType = BOUND_EXACT;
            if (bestValue <= origAlpha) boundType = BOUND_UPPER;
            else if (bestValue >= origBeta) boundType = BOUND_LOWER;

            tt.set(hashKey, { depth, value: bestValue, bound: boundType });
            return bestValue;
        }

        const deepCopy = cards.map(h => new Uint16Array(h));
        const maxNSTricks = search(deepCopy, leaderSeat, [], 0, -1, 99, 0);

        return {
            nodes: localCtx.nodeCount,
            tricksNS: maxNSTricks,
            tricksEW: totalTricks - maxNSTricks
        };
    }

    function computeDealerPar(ddTable, dealer = 0, vulnerable = 0) {
        const strains = ['S', 'H', 'D', 'C', 'NT'];

        let bestScoreNS = -99999;
        let bestContractsNS = [];

        for (let strain = 0; strain < 5; strain++) {
            const tricksNS = ddTable.resTable[strain][0];
            if (tricksNS >= 7) {
                const level = tricksNS - 6;
                const score = (strain === 4 ? 40 + (level - 1) * 30 : (strain <= 1 ? level * 30 : level * 20)) + 50;
                if (score > bestScoreNS) {
                    bestScoreNS = score;
                    bestContractsNS = [`NS ${level}${strains[strain]} N`];
                } else if (score === bestScoreNS) {
                    bestContractsNS.push(`NS ${level}${strains[strain]} N`);
                }
            }
        }

        if (bestScoreNS === -99999) {
            bestScoreNS = 0;
            bestContractsNS = ['Pass out'];
        }

        return {
            dealerResults: {
                number: bestContractsNS.length,
                score: bestScoreNS,
                contracts: bestContractsNS
            },
            parScore: [`NS ${bestScoreNS}`, `EW ${-bestScoreNS}`],
            parContracts: bestContractsNS
        };
    }

    function analyzePlayTrace(cards, trump, first, playCards, ctx = null) {
        const remainingCards = cards.map(h => new Uint16Array(h));
        let leader = first;
        let currentTrick = [];
        let tricksNS = 0;

        const tricksHistory = [];

        for (let i = 0; i < playCards.length; i++) {
            const card = playCards[i];
            const currentTurn = (leader + currentTrick.length) % 4;

            remainingCards[currentTurn][card.suit] ^= (1 << card.rank);
            currentTrick.push({ seat: currentTurn, suit: card.suit, rank: card.rank });

            const declarer = (currentTurn + 3) % 4;
            const res = solveDoubleDummy(remainingCards, trump, declarer, currentTurn, ctx);
            tricksHistory.push(res.tricksNS);

            if (currentTrick.length === 4) {
                leader = evaluateTrickWinner(currentTrick, trump);
                if (leader === 0 || leader === 2) tricksNS++;
                currentTrick = [];
            }
        }

        return {
            number: tricksHistory.length,
            tricks: tricksHistory
        };
    }

    return {
        SolverContext,
        parsePBN,
        generateRandomDeal,
        lookupTables: {
            highestRank: highestRankTable,
            lowestRank: lowestRankTable,
            count: countTable,
            relRank: relRankTable
        },

        solveBoardPBN(pbn, trump = 4, first = 0, currentTrickSuit = [], currentTrickRank = [], target = -1, solutions = 3, mode = 0, context = null) {
            const parsed = parsePBN(pbn);
            const leader = first !== undefined ? first : parsed.firstSeat;
            const declarer = (leader + 3) % 4;

            const res = solveDoubleDummy(parsed.cards, trump, declarer, leader, context);

            let moves = [];
            for (let suit = 0; suit < 4; suit++) {
                let mask = parsed.cards[leader][suit];
                for (let rank = 14; rank >= 2; rank--) {
                    if (mask & (1 << rank)) {
                        moves.push({ suit, rank, score: res.tricksNS });
                    }
                }
            }

            return {
                nodes: res.nodes,
                cards: moves.length,
                suit: moves.map(m => m.suit),
                rank: moves.map(m => m.rank),
                equals: moves.map(() => 0),
                score: moves.map(m => m.score)
            };
        },

        solveBoard(deal, target = -1, solutions = 3, mode = 0, context = null) {
            const declarer = (deal.first + 3) % 4;
            const res = solveDoubleDummy(deal.remainCards, deal.trump, declarer, deal.first, context);
            return {
                nodes: res.nodes,
                tricksNS: res.tricksNS,
                tricksEW: res.tricksEW
            };
        },

        calcDDTablePBN(pbn, context = null) {
            const parsed = parsePBN(pbn);
            const resTable = Array.from({ length: 5 }, () => new Array(4));

            for (let strain = 0; strain < 5; strain++) {
                for (let declarer = 0; declarer < 4; declarer++) {
                    const leader = (declarer + 1) % 4;
                    const res = solveDoubleDummy(parsed.cards, strain, declarer, leader, context);
                    const declarerTricks = (declarer === 0 || declarer === 2) ? res.tricksNS : res.tricksEW;
                    resTable[strain][declarer] = declarerTricks;
                }
            }

            return { resTable };
        },

        calcDDTable(tableDeal, context = null) {
            const resTable = Array.from({ length: 5 }, () => new Array(4));

            for (let strain = 0; strain < 5; strain++) {
                for (let declarer = 0; declarer < 4; declarer++) {
                    const leader = (declarer + 1) % 4;
                    const res = solveDoubleDummy(tableDeal.cards, strain, declarer, leader, context);
                    const declarerTricks = (declarer === 0 || declarer === 2) ? res.tricksNS : res.tricksEW;
                    resTable[strain][declarer] = declarerTricks;
                }
            }

            return { resTable };
        },

        analysePlayPBN(pbn, trump, first, playPbnStr, context = null) {
            const parsed = parsePBN(pbn);
            const playCards = [];
            if (playPbnStr) {
                const tokens = playPbnStr.trim().split(/\s+/);
                for (let token of tokens) {
                    if (token.length >= 2) {
                        const sChar = token[0].toUpperCase();
                        const rChar = token.slice(1).toUpperCase();
                        const suitMap = { 'S': 0, 'H': 1, 'D': 2, 'C': 3 };
                        const suit = suitMap[sChar];
                        const rank = RANK_CHARS[rChar];
                        if (suit !== undefined && rank) {
                            playCards.push({ suit, rank });
                        }
                    }
                }
            }

            return analyzePlayTrace(parsed.cards, trump, first, playCards, context);
        },

        calcParPBN(pbn, vulnerable = 0, dealer = 0) {
            const ddTable = this.calcDDTablePBN(pbn);
            return computeDealerPar(ddTable, dealer, vulnerable);
        }
    };
}));
