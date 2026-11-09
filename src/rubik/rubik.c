#include "rubik.h"
#include "rubik_pdb.h"
#include "rubik_transition9.h"

#define C 7
#define MAX_STEPS 11

typedef struct {
    unsigned char p[C];                                    /* p[7]每個位置的角塊編號，內部會將 1~7 → 0~6 (index) */
    unsigned char o[C];                                    /* o[7]每個位置的方向，內部為 0~2 */
} state_t;

/* 用來儲存rank的數值(最高2^16) */
typedef struct {
    uint16_t p;
    uint16_t o;
} rank_state_t;

/* 每一層保存自己的狀態和下一個要嘗試的動作 */
static rank_state_t stack[MAX_STEPS + 1];                  /* stack[]: 每一層搜尋時的魔方狀態的rank */
static unsigned char next_move[MAX_STEPS + 1];             /* next_move[]: 該層的下一個動作為何，"+1"因為char後面要放'\0' */
static unsigned char path[MAX_STEPS];                      /* path[]: 如何走到目前狀態的 */
static const char move_name[9][3] = {                      /* 儲存9組，每組為"字串"('R','\0'；'R','2','\0'；'R','`' '\0'...字串長度皆為3) */
    "R", "R2", "R'", "B", "B2", "B'", "D", "D2", "D'"
};

/*
 * 檢查輸入是否合法，然後將字串轉成state_t
 */
static int parse(const char *text, state_t *state)
{
    /* seen: 用於bit mask檢查，記錄了七個小塊中，哪個小塊已經出現在輸入中。如果某個小塊重複出現，則表示輸入不符合正立方體的規則，因此解析器會拒絕該輸入 */
    /* sum: 用於檢查orientation是否符合魔方規則 */
    unsigned seen = 0, sum = 0;

    /* 先檢查長度是否為14個字元，避免讀到短字串後面的空間。 */
    int length = 0;
    while (length < 14 && text[length] != '\0') ++length;

    if (length != 14 || text[14] != '\0') return 0;

    /* 只要在陣列裡面(i < 7)，就把每一個(當下的)狀態寫進陣列裡(儲存)*/
    for (int i = 0; i < C; ++i) {
        unsigned p = (unsigned)(text[i] - '1');          /* p只是暫時用於儲存該次迴圈讀到的角塊編號(並非陣列)，且因字串內容為0 ~ 6，又非整數相減一律用ASCII進行(e.g. '4'-'1' = 52-49 = 3)，故4(字元)在p[]被儲存為3 */
        unsigned o = (unsigned)(text[i + C] - '1');      /* o被存在陣列第7~13的位置 */
        if (p >= C || o >= 3 || ((seen >> p) & 1U)) return 0;           /* 檢查格式是否正確 , e.g. p >= 7 或  o >= 3 或     */
        state->p[i] = (unsigned char)p;                  /* p存到state(指向state_t的指標)這個結構裡的p[i] */
        state->o[i] = (unsigned char)o;                  /* o存到state這個結構裡的o[i] */
        seen |= 1U << p;                                 /* seen(=0) 和 unsigned 1(左移p bits) 做"or" */
        sum += o;
    }

    while (sum >= 3) sum -= 3;                           /* sum若超過3，則mod3 */

    return sum == 0;
}


/*
 * 0 1 2 → R
 * 3 4 5 → B
 * 6 7 8 → D
 * 且回傳值:
 * 0 = R
 * 1 = B
 * 2 = D
 */
static int face_of(int move)
{
    if (move < 3) return 0;                                 /* 若小於3，則回傳0(代表R)*/
    if (move < 6) return 1;                                 /* 若小於6，則回傳1(代表B)*/
    return 2;                                               /* 其餘(>6)，則回傳2(代表D)*/
}


/* 邏輯和apply_move的邏輯完全相同，只差旋轉的方式 */
static rank_state_t apply_move_rank(rank_state_t s, int move)
{
    s.p = pt9[move][s.p];
    s.o = ot9[move][s.o];

    return s;
}



/*
 * 一個動作最多影響四個角塊。
 * 若有 k 個角塊尚未完成，至少還要 ceil(k/4) 步。
 * 這只是簡單的下限，不會把真正的最短解排除。
 */

static unsigned rank_perm(const unsigned char p[7])
{
    static const unsigned factorial[7] = {
        720, 120, 24, 6, 2, 1, 1
    };

    unsigned rank = 0;

    for (int i = 0; i < 7; ++i) {
        unsigned smaller = 0;

        for (int j = i + 1; j < 7; ++j) {
            if (p[j] < p[i])
                ++smaller;
        }

        rank += smaller * factorial[i];
    }

    return rank;
}

static unsigned rank_orient(const unsigned char o[7])
{
    unsigned rank = 0;

    for (int i = 0; i < 6; ++i)
        rank = rank * 3 + o[i];

    return rank;
}



/* 不需要每次都重新計算rank，先將rank儲存成表，再利用查詢的方式進行 */
static int lower_bound_rank(rank_state_t s)
{
    int hp = perm_dist[s.p];
    int ho = orient_dist[s.o];

    return hp > ho ? hp : ho;       /* h(s) = max(hp(s), ho(s))，因為兩個PDB都是合法的最短距離下界，所以取最大值仍然不會高估真正距離，這樣就能保存IDA*的最短解保證 */
}

/*
 * 使用帶有heuristic的 "Iterative Deepening Depth-First Search" (接近於IDA*)
 * 不是單純的DFS、IDDFS；它使用「逐步提高步數上限 + "g+h" 剪枝」來搜尋
 * 所以本質上就是 IDA* 的做法，只是它的threshold(limit) 是 0,1,2,...,11 逐一增加，而不是每輪直接跳到下一個超過 threshold 的最小 f 值
 * 其中limit = 這一輪允許使用的"最大步數"
 */
static int solve(state_t start)
{
    rank_state_t initial;

    initial.p = (uint16_t)rank_perm(start.p);
    initial.o = (uint16_t)rank_orient(start.o);

    /* 依序問：0 步能解嗎？ 不行，代表第0步沒有解
     *        1 步呢？ 不行，第1步沒有解
     *        ...
     *        一直到 i 步，找到解答。
     * 最多走11步。
     * 第一次找到的解就是最短解，因為前面的步數都沒有解。
     */
    for (int limit = lower_bound_rank(initial); limit <= MAX_STEPS; ++limit) {
        int depth = 0;                                        /* 紀錄深度，代表已經走了幾步，迴圈的最開始 */
        stack[0] = initial;                                   /* 第0層，即為原始魔方 */
        next_move[0] = 0;                                     /* 第0層下一個先試move 0，也就是R，next_move[]存每層下一個還沒試過的move是哪一個 */

        /*
         * 手動做DFS，一般DFS常用recursion
         * 但這邊用stack[], depth, next_move[]來模擬function call back
         */
        while (depth >= 0) {
            if (stack[depth].p == 0 && stack[depth].o == 0) return depth;         /* 如果已經解完，回傳depth，如果還沒救繼續下一行，stack[]存每個depth的魔方狀態 */
                                                                                  /* 其中Solved Permutation: [0,1,2,3,4,5,6]；Solved Orientation: [0,0,0,0,0,0,0] */

            /*
             * 做backtrack，若
             * 1."已走步數"(depth)快超出可以走的"最大步數"
             * 2."已走步數" + "預計要走步數" 已超過可走的 "最大步數"
             * 3.九種動作都試完，因為move_name[9][3]={...}，且???
             * 則退回上一層(--depth)，繼續下一行。
             */
            if (depth == limit || next_move[depth] == 9) {

                --depth;
                continue;
            }

            int move = next_move[depth]++;                     /* move為下一個動作的index(0~8)，因為DFS會搜尋同一層內的所有合法路徑 */

            /*
             * 不允許連續轉同一面"face_of(move) == face_of(path[depth - 1)"，必定可以合併，不可能是最短解必需的形式
             * 例: R接下來不可能是"R, R2, R'"
             * R*R = R2, R*R2 = R, R*R' = I
             */
            if (depth > 0 && face_of(move) == face_of(path[depth - 1])){

                if(move == 0 || move == 3|| move == 6){
	            next_move[depth] = (unsigned char)(move + 3);
	        }
                continue;
	    }

            path[depth] = (unsigned char)move;                  /* path[]紀錄到置個depth為止執行哪些動作(R,R2,...) */
            rank_state_t child = apply_move_rank(stack[depth], move);

            if(child.p == 0 && child.o ==0){
	        return depth + 1;
	    }

            if(depth + 1 == limit){
                continue;
	    }

	    if(depth + 1 + lower_bound_rank(child) > limit){
	        continue;
	    }

	    stack[depth + 1] = apply_move_rank(stack[depth], move);  /* 拿現在的魔方，執行move後，產生出下一個魔方 */

            ++depth;                                            /* 進入下一層 */
            next_move[depth] = 0;                               /* 第depth層的動作從R(idx 0)開始執行 */
        }
    }
    return -1;
}


/*
 *進入主函式
 */

int rubik_solve(const char *state, char *out, size_t cap)
{
    state_t cube;

    /* Invalid input must not modify out. */
    if (!state || !parse(state, &cube))
        return -1;

    int steps = solve(cube);
    if (steps < 0)
        return -1;

    /* Determine the required output length, including NUL. */
    size_t required = 1;

    for (int i = 0; i < steps; ++i) {
        const char *name = move_name[path[i]];

        if (i > 0)
            ++required;  /* Space between moves. */

        for (int j = 0; name[j] != '\0'; ++j)
            ++required;
    }

    if (required > cap || !out) {
        if (out && cap > 0)
            out[0] = '\0';
        return -2;
    }

    /* Convert the solution path into a string. */
    size_t pos = 0;

    for (int i = 0; i < steps; ++i) {
        if (i > 0)
            out[pos++] = ' ';

        const char *name = move_name[path[i]];

        for (int j = 0; name[j] != '\0'; ++j)
            out[pos++] = name[j];
    }

    out[pos] = '\0';

    return steps;
}
