// 專門測量單一狀態所使用的指令數#include <stdint.h>
#include <stddef.h>
#include <stdint.h>

#include "src/rubik/rubik.h"
#include "common/print.h"
#include "tests/tperf.h"

int main(void)
{
    /* Eight known distance-11 MiniRubik states */
    const char *states[] = {
        "21345671111111",
        "56723411121113",
        "23156471222132",
        "76543212222221",
        "74132562122111",
        "37614522323312",
        "12637451332112",
        "47135622132332"
    };

    const int num_states = sizeof(states) / sizeof(states[0]);

    uint64_t max_instret = 0;
    const char *worst_state = NULL;

    int all_pass = 1;

    bm_printf("--------------------------------------------\n");
    bm_printf(" MiniRubik Hybrid IDA* Assembly Benchmark\n");
    bm_printf("--------------------------------------------\n\n");

    for (int i = 0; i < num_states; i++) {

        /* Select the current cube state */
        const char *state = states[i];

        char solution[96];

        uint64_t used = 0;
        int steps = -1;

        /* Measure retired instructions for one solver call */
        PERF_CALL(
            used,
            steps = rubik_solve_asm(state, solution, sizeof(solution))
        );

        /* Print measurement results */
        bm_printf("State %d: %s\n", i + 1, state);
        bm_printf("  Steps: %d\n", steps);
        bm_printf("  Retired Instructions: %llu\n", used);

        /* Verify optimal distance and instruction budget */
        if (steps != 11 || used > 7500000ULL) {

            bm_printf("  Result: FAIL\n\n");
            all_pass = 0;

        } else {

            bm_printf("  Solution: %s\n", solution);
            bm_printf("  Result: PASS\n\n");
        }

        /* Update maximum retired instructions */
        if (max_instret < used) {

            max_instret = used;
            worst_state = state;
        }
    }

    /* Final summary */
    bm_printf("--------------------------------------------\n");
    bm_printf(" Benchmark Summary\n");
    bm_printf("--------------------------------------------\n");

    bm_printf("Total States: %d\n", num_states);
    bm_printf("Worst State: %s\n", worst_state);
    bm_printf("Maximum Retired Instructions: %llu\n", max_instret);
    bm_printf("Instruction Budget: %u\n", 7500000U);

    if (all_pass) {

        bm_printf("Final Result: PASS\n");
        return 0;

    } else {

        bm_printf("Final Result: FAIL\n");
        return 1;
    }
}
