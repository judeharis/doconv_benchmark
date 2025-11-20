#ifndef DECONV_TOP_HPP
#define DECONV_TOP_HPP

#include <ap_int.h>
#include <hls_stream.h>
#include <hls_vector.h>

constexpr unsigned  K = 3;		// kernel Size
constexpr unsigned  S = 1; 		// stride
constexpr unsigned  P = 1;		// padding
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
	{{0x68,}},
	{{0x16,}},
	{{0x09,}},
	{{0xc3,}},
	{{0xe7,}},
	{{0x7e,}},
	{{0x17,}},
	{{0x7d,}},
	{{0x64,}},
	{{0x9b,}},
	{{0xa5,}},
	{{0x39,}},
	{{0x53,}},
	{{0xa6,}},
	{{0x88,}},
	{{0x20,}},
	{{0xa2,}},
	{{0x0a,}},
	{{0x17,}},
	{{0x8f,}},
	{{0xef,}},
	{{0x57,}},
	{{0x19,}},
	{{0xc7,}},
	{{0xf3,}},
	{{0x5c,}},
	{{0x4a,}},
};

#else

constexpr unsigned  PE   = 3;

constexpr unsigned  SIMD = 1;


static TW const  KERNEL[9][3][1] = {
	{{0x68,},{0x16,},{0x09,}},
	{{0xc3,},{0xe7,},{0x7e,}},
	{{0x17,},{0x7d,},{0x64,}},
	{{0x9b,},{0xa5,},{0x39,}},
	{{0x53,},{0xa6,},{0x88,}},
	{{0x20,},{0xa2,},{0x0a,}},
	{{0x17,},{0x8f,},{0xef,}},
	{{0x57,},{0x19,},{0xc7,}},
	{{0xf3,},{0x5c,},{0x4a,}},
};

#endif
void deconv_top(
    hls::stream<hls::vector<TI, SIMD>> &src,
    hls::stream<hls::vector<TO, PE>>   &dst
);

#endif