#ifndef DECONV_TOP_HPP
#define DECONV_TOP_HPP

#include <ap_int.h>
#include <hls_stream.h>
#include <hls_vector.h>

constexpr unsigned  K = 3;		// kernel Size
constexpr unsigned  S = 1; 		// stride
constexpr unsigned  P = 2;		// padding
constexpr unsigned  H = 3;		// IFM height
constexpr unsigned  W = 3;		// IFM Width
constexpr unsigned  CI = 1;		// input channels
constexpr unsigned  CO = 3;		// output channels

using  TW = ap_uint< 8>;
using  TI = ap_uint< 4>;
using  TO = ap_uint<16>;

#if 1

constexpr unsigned  PE   = 1;

constexpr unsigned  SIMD = 1;


static TW const  KERNEL[27][1][1] = {
	{{0x9c,}},
	{{0x9d,}},
	{{0x8e,}},
	{{0x32,}},
	{{0x44,}},
	{{0xd7,}},
	{{0xd7,}},
	{{0xe9,}},
	{{0xf1,}},
	{{0xf7,}},
	{{0xde,}},
	{{0x60,}},
	{{0x56,}},
	{{0x8d,}},
	{{0xe9,}},
	{{0x89,}},
	{{0x07,}},
	{{0x3f,}},
	{{0x3d,}},
	{{0x16,}},
	{{0x39,}},
	{{0x01,}},
	{{0x80,}},
	{{0x3c,}},
	{{0xd1,}},
	{{0x08,}},
	{{0xd8,}},
};

#else

constexpr unsigned  PE   = 3;

constexpr unsigned  SIMD = 1;


static TW const  KERNEL[9][3][1] = {
	{{0x9c,},{0x9d,},{0x8e,}},
	{{0x32,},{0x44,},{0xd7,}},
	{{0xd7,},{0xe9,},{0xf1,}},
	{{0xf7,},{0xde,},{0x60,}},
	{{0x56,},{0x8d,},{0xe9,}},
	{{0x89,},{0x07,},{0x3f,}},
	{{0x3d,},{0x16,},{0x39,}},
	{{0x01,},{0x80,},{0x3c,}},
	{{0xd1,},{0x08,},{0xd8,}},
};

#endif
void deconv_top(
    hls::stream<hls::vector<TI, SIMD>> &src,
    hls::stream<hls::vector<TO, PE>>   &dst
);

#endif