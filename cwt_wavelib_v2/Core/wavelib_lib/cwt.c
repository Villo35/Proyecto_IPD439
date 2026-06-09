/*
  Copyright (c) 2015, Rafat Hussain
  Adapted for single-precision (float) embedded targets.
*/
/*
This code is a C translation ( with some modifications) of Wavelet Software provided by
C. Torrence and G. Compo, and is available at URL: http://atoc.colorado.edu/research/wavelets/''.
*/

#include "cwt.h"
#include <math.h>
#include <stdlib.h>
#include <stdio.h>

/* Note: Float maximum value is around 3.4E38. Factorials above 34! will overflow a 32-bit float.
   For typical Paul/DOG parameters in CWT, N is small enough. */
float factorial(int N) {
	static const float fact[35] = { 1.0f, 1.0f, 2.0f, 6.0f, 24.0f, 120.0f, 720.0f, 5040.0f, 40320.0f, 362880.0f, 3628800.0f, 39916800.0f, 479001600.0f, 6227020800.0f, 87178291200.0f, 1307674368000.0f,
		20922789888000.0f, 355687428096000.0f, 6402373705728000.0f, 121645100408832000.0f, 2432902008176640000.0f, 51090942171709440000.0f, 1124000727777607680000.0f,
		25852016738884976640000.0f, 620448401733239439360000.0f, 15511210043330985984000000.0f, 403291461126605635584000000.0f, 10888869450418352160768000000.0f,
		304888344611713860501504000000.0f, 8841761993739701954543616000000.0f, 265252859812191058636308480000000.0f, 8222838654177922817725562880000000.0f,
		263130836933693530167218012160000000.0f, 8683317618811886495518194401280000000.0f, 295232799039604140847618609643520000000.0f };

	if (N > 34 || N < 0) {
		printf("This program is only valid for 0 <= N <= 34 due to float limits\n");
		return -1.0f;
	}

	return fact[N];
}

static void wave_function(int nk, float dt, int mother, float param, float scale1, float *kwave, float pi, float *period1,
	float *coi1, fft_data *daughter) {

	float norm, expnt, fourier_factor;
	int k, m;
	float temp;
	int sign, re;

	if (mother == 0) {
		// MORLET
		if (param < 0.0f) {
			param = 6.0f;
		}
		norm = sqrtf(2.0f * pi * scale1 / dt) * powf(pi, -0.25f);

		for (k = 1; k <= nk / 2 + 1; ++k) {
			temp = (scale1 * kwave[k-1] - param);
			expnt = -0.5f * temp * temp;
			daughter[k - 1].re = norm * expf(expnt);
			daughter[k - 1].im = 0.0f;
		}
		for (k = nk / 2 + 2; k <= nk; ++k) {
			daughter[k - 1].re = daughter[k - 1].im = 0.0f;
		}
		fourier_factor = (4.0f * pi) / (param + sqrtf(2.0f + param * param));
		*period1 = scale1 * fourier_factor;
		*coi1 = fourier_factor / sqrtf(2.0f);
	}
	else if (mother == 1) {
		// PAUL
		if (param < 0.0f) {
			param = 4.0f;
		}
		m = (int)param;
		norm = sqrtf(2.0f * pi * scale1 / dt) * (powf(2.0f, (float)m) / sqrtf((float)(m * factorial(2 * m - 1))));
		for (k = 1; k <= nk / 2 + 1; ++k) {
			temp = scale1 * kwave[k - 1];
			expnt = -temp;
			daughter[k - 1].re = norm * powf(temp, (float)m) * expf(expnt);
			daughter[k - 1].im = 0.0f;
		}
		for (k = nk / 2 + 2; k <= nk; ++k) {
			daughter[k - 1].re = daughter[k - 1].im = 0.0f;
		}
		fourier_factor = (4.0f * pi) / (2.0f * m + 1.0f);
		*period1 = scale1 * fourier_factor;
		*coi1 = fourier_factor * sqrtf(2.0f);
	}
	else if (mother == 2) {
		// DOG
		if (param < 0.0f) {
			param = 2.0f;
		}
		m = (int)param;

		if (m % 2 == 0) {
			re = 1;
		}
		else {
			re = 0;
		}

		if (m % 4 == 0 || m % 4 == 1) {
			sign = -1;
		}
		else {
			sign = 1;
		}

		// Ensure cwt_gamma returns a float or cast it
		norm = sqrtf(2.0f * pi * scale1 / dt) * sqrtf(1.0f / (float)cwt_gamma(m + 0.50f));
		norm *= sign;

		if (re == 1) {
			for (k = 1; k <= nk; ++k) {
				temp = scale1 * kwave[k - 1];
				daughter[k - 1].re = norm * powf(temp, (float)m) * expf(-0.50f * powf(temp, 2.0f));
				daughter[k - 1].im = 0.0f;
			}
		}
		else if (re == 0) {
			for (k = 1; k <= nk; ++k) {
				temp = scale1 * kwave[k - 1];
				daughter[k - 1].re = 0.0f;
				daughter[k - 1].im = norm * powf(temp, (float)m) * expf(-0.50f * powf(temp, 2.0f));
			}
		}
		fourier_factor = (2.0f * pi) * sqrtf(2.0f / (2.0f * m + 1.0f));
		*period1 = scale1 * fourier_factor;
		*coi1 = fourier_factor / sqrtf(2.0f);
	}
}

void cwavelet(const float *y, int N, float dt, int mother, float param, float s0, float dj, int jtot, int npad,
	float *wave, float *scale, float *period, float *coi) {

	int i, j, k, iter;
	float ymean, freq1, pi, period1, coi1;
	float tmp1, tmp2;
	float scale1;
	float *kwave;
	fft_object obj, iobj;
	fft_data *ypad, *yfft, *daughter;

	(void)s0; (void)dj; 

	period1 = 0.0f;
	coi1 = 0.0f;

	pi = 4.0f * atanf(1.0f);

	if (npad < N) {
		printf("npad must be >= N \n");
		return;
	}

	obj = fft_init(npad, 1);
	iobj = fft_init(npad, -1);

	// WARNING: dynamic allocation in embedded systems
	ypad = (fft_data*)malloc(sizeof(fft_data) * npad);
	yfft = (fft_data*)malloc(sizeof(fft_data) * npad);
	daughter = (fft_data*)malloc(sizeof(fft_data) * npad);
	kwave = (float*)malloc(sizeof(float) * npad);

	ymean = 0.0f;

	for (i = 0; i < N; ++i) {
		ymean += y[i];
	}

	ymean /= (float)N;

	for (i = 0; i < N; ++i) {
		ypad[i].re = y[i] - ymean;
		ypad[i].im = 0.0f;
	}

	for (i = N; i < npad; ++i) {
		ypad[i].re = ypad[i].im = 0.0f;
	}

	// Find FFT of the input y (ypad)
	fft_exec(obj, ypad, yfft);

	for (i = 0; i < npad; ++i) {
		yfft[i].re /= (float)npad;
		yfft[i].im /= (float)npad;
	}

	// Construct the wavenumber array
	freq1 = 2.0f * pi / ((float)npad * dt);
	kwave[0] = 0.0f;

	for (i = 1; i < npad / 2 + 1; ++i) {
		kwave[i] = (float)i * freq1;
	}

	for (i = npad / 2 + 1; i < npad; ++i) {
		kwave[i] = -kwave[npad - i];
	}

	// Main loop: Matrix outputs scales directly
	for (j = 1; j <= jtot; ++j) {
		scale1 = scale[j - 1];
		wave_function(npad, dt, mother, param, scale1, kwave, pi, &period1, &coi1, daughter);
		period[j - 1] = period1;
		for (k = 0; k < npad; ++k) {
			tmp1 = daughter[k].re * yfft[k].re - daughter[k].im * yfft[k].im;
			tmp2 = daughter[k].re * yfft[k].im + daughter[k].im * yfft[k].re;
			daughter[k].re = tmp1;
			daughter[k].im = tmp2;
		}
		fft_exec(iobj, daughter, ypad);
		iter = 2 * (j - 1) * N;
		for (i = 0; i < N; ++i) {
			wave[iter + 2 * i] = ypad[i].re;
			wave[iter + 2 * i + 1] = ypad[i].im;
		}
	}

	for (i = 1; i <= (N + 1) / 2; ++i) {
		coi[i - 1] = coi1 * dt * ((float)i - 1.0f);
		coi[N - i] = coi[i - 1];
	}

	free(kwave);
	free(ypad);
	free(yfft);
	free(daughter);

	free_fft(obj);
	free_fft(iobj);
}

void psi0(int mother, float param, float *val, int *real) {
	float pi, coeff;
	int m, sign;

	m = (int)param;
	pi = 4.0f * atanf(1.0f);

	if (mother == 0) {
		// Morlet
		*val = 1.0f / sqrtf(sqrtf(pi));
		*real = 1;
	}
	else if (mother == 1) {
		// Paul
		if (m % 2 == 0) {
			*real = 1;
		}
		else {
			*real = 0;
		}

		if (m % 4 == 0 || m % 4 == 1) {
			sign = 1;
		}
		else {
			sign = -1;
		}
		*val = (float)sign * powf(2.0f, (float)m) * factorial(m) / (sqrtf(pi * factorial(2 * m)));
	}
	else if (mother == 2) {
		// D.O.G
		*real = 1;

		if (m % 2 == 0) {
			if (m % 4 == 0) {
				sign = -1;
			}
			else {
				sign = 1;
			}
			coeff = (float)sign * powf(2.0f, (float)m / 2.0f) / (float)cwt_gamma(0.5f);
			*val = coeff * (float)cwt_gamma(((float)m + 1.0f) / 2.0f) / sqrtf((float)cwt_gamma(m + 0.50f));
		}
		else {
			*val = 0.0f;
		}
	}
}

static int maxabs(float *array, int N) {
	float maxval, temp;
	int i, index;
	maxval = 0.0f;
	index = -1;

	for (i = 0; i < N; ++i) {
		temp = fabsf(array[i]);
		if (temp >= maxval) {
			maxval = temp;
			index = i;
		}
	}

	return index;
}

float cdelta(int mother, float param, float psi0_val) {
	int N, i, j, iter;
	float *delta, *scale, *period, *wave, *coi, *mval;
	float den, cdel;
	float subscale, dt, dj, s0;
	int jtot;
	int maxarr;

	subscale = 8.0f;
	dt = 0.25f;
	if (mother == 0) {
		N = 16;
		s0 = dt / 4.0f;
	}
	else if (mother == 1) {
		N = 16;
		s0 = dt / 4.0f;
	}
	else if (mother == 2) {
		s0 = dt / 8.0f;
		N = 256;
		if (param == 2.0f) {
			subscale = 16.0f;
			s0 = dt / 16.0f;
			N = 2048;
		}
	} else {
		printf("Mother only takes 0,1 or 2 as values\n");
		return -1.0f;
	}

	dj = 1.0f / subscale;
	jtot = 16 * (int)subscale;

	delta = (float*)malloc(sizeof(float) * N);
	wave = (float*)malloc(sizeof(float) * 2 * N * jtot);
	coi = (float*)malloc(sizeof(float) * N);
	scale = (float*)malloc(sizeof(float) * jtot);
	period = (float*)malloc(sizeof(float) * jtot);
	mval = (float*)malloc(sizeof(float) * N);

	delta[0] = 1.0f;

	for (i = 1; i < N; ++i) {
		delta[i] = 0.0f;
	}

	for (i = 0; i < jtot; ++i) {
		scale[i] = s0 * powf(2.0f, (float)(i) * dj);
	}

	cwavelet(delta, N, dt, mother, param, s0, dj, jtot, N, wave, scale, period, coi);

	for (i = 0; i < N; ++i) {
		mval[i] = 0.0f;
	}

	for (j = 0; j < jtot; ++j) {
		iter = 2 * j * N;
		den = sqrtf(scale[j]);
		for (i = 0; i < N; ++i) {
			mval[i] += wave[iter + 2 * i] / den;
		}
	}

	maxarr = maxabs(mval, N);

	cdel = sqrtf(dt) * dj * mval[maxarr] / psi0_val;

	free(delta);
	free(wave);
	free(scale);
	free(period);
	free(coi);
	free(mval);

	return cdel;
}

void icwavelet(float *wave, int N, float *scale, int jtot, float dt, float dj, float cdelta, float psi0_val, float *oup) {
	int i, j, iter;
	float den, coeff;

	coeff = sqrtf(dt) * dj / (cdelta * psi0_val);

	for (i = 0; i < N; ++i) {
		oup[i] = 0.0f;
	}

	for (j = 0; j < jtot; ++j) {
		iter = 2 * j * N;
		den = sqrtf(scale[j]);
		for (i = 0; i < N; ++i) {
			oup[i] += wave[iter + 2 * i] / den;
		}
	}

	for (i = 0; i < N; ++i) {
		oup[i] *= coeff;
	}
}