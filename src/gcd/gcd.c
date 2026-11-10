#include "gcd.h"

// 利用輾轉相除法解質數
uint32_t gcd_u32(uint32_t a, uint32_t b)
{
    unsigned shift = 0;

    // 處理a, b 皆為 0 的情況
    if(a == 0){
        return b;
    }

    if(b == 0){
        return a;
    }

    while(((a & 1u) == 0u) && ((b & 1u) == 0u)){
        a = a >> 1;
        b = b >> 1;
        shift++;
    }

    while(a != b){
        if((a & 1u) == 0u){
            a = a >> 1;
        }

        else if((b & 1u) == 0u){
            b = b >> 1;
        }

        else{
            if(a > b){
                a = a - b;
            }
            else{
                b = b - a;
            }
        }
    }

    return a << shift;
}
