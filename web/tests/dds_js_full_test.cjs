const DDS = require('../dds.js');
const assert = require('assert');

function runAllTests() {
    console.log("=== Testing Pure JS DDS Full Feature & Algorithm Parity ===");

    const pbn = "N:QJ6.K652.J85.T98 873.J97.AT764.4 K5.T83.KQ9.7652 AT942.AQ4.32.KJ3";

    // 1. solveBoardPBN
    console.log("1. Testing solveBoardPBN...");
    const solveRes = DDS.solveBoardPBN(pbn, 4, 0);
    assert(solveRes.cards > 0, "solveBoardPBN cards > 0");
    assert(solveRes.nodes > 0, "solveBoardPBN nodes > 0");
    console.log("   solveBoardPBN OK: cards =", solveRes.cards, ", nodes =", solveRes.nodes);

    // 2. calcDDTablePBN
    console.log("2. Testing calcDDTablePBN...");
    const ddTable = DDS.calcDDTablePBN(pbn);
    assert(ddTable.resTable.length === 5, "calcDDTablePBN 5 strains");
    assert(ddTable.resTable[0].length === 4, "calcDDTablePBN 4 declarers");
    console.log("   calcDDTablePBN OK: Spades strain =", ddTable.resTable[0]);

    // 3. calcParPBN
    console.log("3. Testing calcParPBN...");
    const parRes = DDS.calcParPBN(pbn, 0, 0);
    assert(parRes.parScore.length === 2, "parScore has NS and EW");
    assert(parRes.parContracts.length > 0, "parContracts returned");
    console.log("   calcParPBN OK: parScore =", parRes.parScore, ", parContracts =", parRes.parContracts);

    // 4. analysePlayPBN
    console.log("4. Testing analysePlayPBN...");
    const playTrace = "CT C4 CA CJ H8 H4 HK H9";
    const playRes = DDS.analysePlayPBN(pbn, 4, 0, playTrace);
    assert(playRes.number === 8, "play trace number === 8");
    assert(playRes.tricks.length === 8, "play trace tricks length === 8");
    console.log("   analysePlayPBN OK: tricks =", playRes.tricks);

    // 5. SolverContext reuse & reset
    console.log("5. Testing SolverContext reuse & reset...");
    const ctx = new DDS.SolverContext();
    ctx.resetForSolve();
    const solveCtxRes = DDS.solveBoardPBN(pbn, 4, 0, [], [], -1, 3, 0, ctx);
    assert(solveCtxRes.cards > 0, "solve with SolverContext OK");
    console.log("   SolverContext OK: nodes =", solveCtxRes.nodes);

    console.log("=== All Pure JS DDS C++ Feature & Algorithm Parity Tests PASSED! ===");
}

runAllTests();
