#ifndef CWT_H_
#define CWT_H_

#include "wavefunc.h"

#ifdef __cplusplus
extern "C" {
#endif

// Prototipos adaptados a float para STM32 Cortex-M4 (FPU de 32 bits)

void cwavelet(const float *y, int N, float dt, int mother, float param, float s0, float dj, int jtot, int npad,
		float *wave, float *scale, float *period, float *coi);

void psi0(int mother, float param, float *val, int *real);

float factorial(int N);

float cdelta(int mother, float param, float psi0_val);

void icwavelet(float *wave, int N, float *scale, int jtot, float dt, float dj, float cdelta, float psi0_val, float *oup);


#ifdef __cplusplus
}
#endif

#endif /* CWT_H_ */

