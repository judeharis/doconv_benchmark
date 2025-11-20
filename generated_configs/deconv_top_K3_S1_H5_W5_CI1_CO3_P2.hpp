#ifndef DECONV_TOP_HPP
#define DECONV_TOP_HPP

#include <ap_int.h>
#include <hls_stream.h>
#include <hls_vector.h>

constexpr unsigned  K = 3;		// kernel Size
constexpr unsigned  S = 1; 		// stride
constexpr unsigned  P = 2;		// padding
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
	{{0x39,}},
	{{0xf0,}},
	{{0xfc,}},
	{{0xd2,}},
	{{0x60,}},
	{{0x0d,}},
	{{0x0a,}},
	{{0x17,}},
	{{0x7c,}},
	{{0x51,}},
	{{0x87,}},
	{{0x79,}},
	{{0x98,}},
	{{0xca,}},
	{{0xdc,}},
	{{0x94,}},
	{{0xa0,}},
	{{0x8c,}},
	{{0xc1,}},
	{{0x5e,}},
	{{0x3c,}},
	{{0xe9,}},
	{{0x98,}},
	{{0x52,}},
	{{0x73,}},
	{{0x61,}},
	{{0x82,}},
};

#else

constexpr unsigned  PE   = 3;

constexpr unsigned  SIMD = 1;


static TW const  KERNEL[9][3][1] = {
	{{0x39,},{0xf0,},{0xfc,}},
	{{0xd2,},{0x60,},{0x0d,}},
	{{0x0a,},{0x17,},{0x7c,}},
	{{0x51,},{0x87,},{0x79,}},
	{{0x98,},{0xca,},{0xdc,}},
	{{0x94,},{0xa0,},{0x8c,}},
	{{0xc1,},{0x5e,},{0x3c,}},
	{{0xe9,},{0x98,},{0x52,}},
	{{0x73,},{0x61,},{0x82,}},
};

#endif
void deconv_top(
    hls::stream<hls::vector<TI, SIMD>> &src,
    hls::stream<hls::vector<TO, PE>>   &dst
);

#endif