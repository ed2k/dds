import createDdsApiModule from '../dds_wasm_api.js';
import assert from 'assert';

async function runTests() {
    console.log("Initializing DDS WASM API module in Node...");
    const module = await createDdsApiModule();
    assert(module.solveBoardPBN, "solveBoardPBN function exists");
    assert(module.calcDDTablePBN, "calcDDTablePBN function exists");
    assert(module.calcParPBN, "calcParPBN function exists");

    const pbn = "N:AK.234.456.789T QJ.567.789.2345 23.89T.AQJ.AKQJ 45.JQ.K10.6789";

    console.log("Testing solveBoardPBN...");
    const solveRes = module.solveBoardPBN(pbn, 4, 0);
    assert(solveRes.nodes >= 0, "solveBoardPBN returned valid nodes");
    assert(solveRes.cards > 0, "solveBoardPBN returned cards > 0");
    console.log("solveBoardPBN result: cards =", solveRes.cards);

    console.log("Testing calcDDTablePBN...");
    const tableRes = module.calcDDTablePBN(pbn);
    assert(tableRes.resTable && tableRes.resTable.length === 5, "resTable has 5 strains");
    assert(tableRes.resTable[0].length === 4, "strain 0 has 4 hands");
    console.log("calcDDTablePBN resTable[0] (Spades):", tableRes.resTable[0]);

    console.log("Testing calcParPBN...");
    const parRes = module.calcParPBN(pbn, 0);
    assert(parRes.parScore && parRes.parScore.length === 2, "parScore returned");
    console.log("calcParPBN result:", parRes);

    console.log("Testing SolverContext reuse...");
    const ctx = new module.SolverContext();
    ctx.resetForSolve();
    const solveContextRes = module.solveBoardPBN(pbn, 4, 0, [], [], -1, 3, 0, ctx);
    assert(solveContextRes.cards > 0, "solve with context returned cards > 0");
    ctx.delete();

    console.log("All WASM JS API tests passed successfully!");
}

runTests().catch(err => {
    console.error("Test failed:", err);
    process.exit(1);
});
