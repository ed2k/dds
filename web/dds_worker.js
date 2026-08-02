/**
 * Web Worker for DDS Pure JavaScript Solver.
 * Executes single-deal solver searches off the main UI thread.
 * Supports root-move parallel distribution across CPU worker threads.
 */

importScripts('dds.js');

self.onmessage = function (e) {
    const data = e.data;
    const type = data.type || 'solve';

    if (type === 'solve') {
        const start = performance.now();
        const res = DDS.solveBoardPBN(
            data.pbn,
            data.trump,
            data.first,
            data.currentTrickSuit,
            data.currentTrickRank,
            data.target,
            data.solutions,
            data.mode
        );
        const elapsed = performance.now() - start;

        self.postMessage({
            type: 'solve_result',
            taskId: data.taskId,
            executionTimeMs: elapsed,
            result: res
        });
    } else if (type === 'calcDDTable') {
        const start = performance.now();
        const res = DDS.calcDDTablePBN(data.pbn);
        const elapsed = performance.now() - start;

        self.postMessage({
            type: 'ddtable_result',
            taskId: data.taskId,
            executionTimeMs: elapsed,
            result: res
        });
    }
};
