// Auto-generated selector header for deconvolution configurations
// Usage: define one of the following macros before including this file:
//   - DECONV_CFG_IDX_0
//   - DECONV_CFG_K3_S1_H3_W3_CI1_CO3_P2
//   - DECONV_CFG_IDX_1
//   - DECONV_CFG_K3_S1_H3_W3_CI1_CO3_P1

#ifndef DECONV_TOP_SELECTOR_HPP
#define DECONV_TOP_SELECTOR_HPP

#if defined(DECONV_CFG_IDX_0) || defined(DECONV_CFG_K3_S1_H3_W3_CI1_CO3_P2)
#include "deconv_top_K3_S1_H3_W3_CI1_CO3_P2.hpp"
#elif defined(DECONV_CFG_IDX_1) || defined(DECONV_CFG_K3_S1_H3_W3_CI1_CO3_P1)
#include "deconv_top_K3_S1_H3_W3_CI1_CO3_P1.hpp"
#else
#include "deconv_top_K3_S1_H3_W3_CI1_CO3_P2.hpp"
#endif

#endif // DECONV_TOP_SELECTOR_HPP