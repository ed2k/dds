const path = require('path');
const jsPath = process.argv[2] || path.resolve(__dirname, '../dds_wasm_api.js');
const createDdsApiModule = require(jsPath);
const assert = require('assert');

async function runTests() {
    console.log("Initializing DDS WASM API module from:", jsPath);
    const wasmPath = jsPath.replace(/\.js$/, '.wasm');
    const module = await createDdsApiModule({
        locateFile: (filename) => {
            if (filename.endsWith('.wasm')) {
                return wasmPath;
            }
            return filename;
        }
    });

    assert(typeof module.solveBoardPBN === 'function', "solveBoardPBN function exists");
    assert(typeof module.calcDDTablePBN === 'function', "calcDDTablePBN function exists");
    assert(typeof module.calcParPBN === 'function', "calcParPBN function exists");

    const pbn = "N:QJ6.K652.J85.T98 873.J97.AT764.Q4 K5.T83.KQ9.A7652 AT942.AQ4.32.KJ3";

    console.log("Testing solveBoardPBN...");
    const solveRes = module.solveBoardPBN(pbn, 4, 0, [], [], -1, 3, 0, null);
    assert(solveRes.nodes >= 0, "solveBoardPBN returned valid nodes");
    assert(solveRes.cards > 0, "solveBoardPBN returned cards > 0");
    console.log("solveBoardPBN result: cards =", solveRes.cards);

    console.log("Testing calcDDTablePBN...");
    const tableRes = module.calcDDTablePBN(pbn, null);
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
