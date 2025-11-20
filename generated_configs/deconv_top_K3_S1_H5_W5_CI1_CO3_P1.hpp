#ifndef DECONV_TOP_HPP
#define DECONV_TOP_HPP

#include <ap_int.h>
#include <hls_stream.h>
#include <hls_vector.h>

constexpr unsigned  K = 3;		// kernel Size
constexpr unsigned  S = 1; 		// stride
constexpr unsigned  P = 1;		// padding
constexpr unsigned  H = 5;		// IFM height
constexpr unsigned  W = 5;		// IFM Width
constexpr unsigned  CI = 1;		// input channels
constexpr unsigned  CO = 3;		// output channels

using  TW = ap_uint< 8>;
using  TI = ap_uint< 4>;
using  TO = ap_uint<16>;

#if 1

constexpr unsigned  PE   = 1;

constexpr unsigned  SIMD = 1;


static TW const  KERNEL[27][1][1] = {
	{{0xbb,}},
	{{0x8f,}},
	{{0x18,}},
	{{0xfb,}},
	{{0x89,}},
	{{0xc2,}},
	{{0xc7,}},
	{{0x35,}},
	{{0x45,}},
	{{0xa4,}},
	{{0x65,}},
	{{0xf8,}},
	{{0x15,}},
	{{0x28,}},
	{{0x4d,}},
	{{0xdb,}},
	{{0xb1,}},
	{{0x71,}},
	{{0x2f,}},
	{{0xcd,}},
	{{0xa8,}},
	{{0xce,}},
	{{0x2d,}},
	{{0x57,}},
	{{0x90,}},
	{{0x9c,}},
	{{0xea,}},
};

#else

constexpr unsigned  PE   = 3;

constexpr unsigned  SIMD = 1;


static TW const  KERNEL[9][3][1] = {
	{{0xbb,},{0x8f,},{0x18,}},
	{{0xfb,},{0x89,},{0xc2,}},
	{{0xc7,},{0x35,},{0x45,}},
	{{0xa4,},{0x65,},{0xf8,}},
	{{0x15,},{0x28,},{0x4d,}},
	{{0xdb,},{0xb1,},{0x71,}},
	{{0x2f,},{0xcd,},{0xa8,}},
	{{0xce,},{0x2d,},{0x57,}},
	{{0x90,},{0x9c,},{0xea,}},
};

#endif
void deconv_top(
    hls::stream<hls::vector<TI, SIMD>> &src,
    hls::stream<hls::vector<TO, PE>>   &dst
);

#endif