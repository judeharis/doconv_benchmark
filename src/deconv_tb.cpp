#include "deconv_top.hpp"

#include <fstream>
#include <iomanip>
#include <iostream>

int main() {
  hls::stream<hls::vector<TI, SIMD>> src;
  hls::stream<hls::vector<TO, PE>> dst;

  for (unsigned h = 0; h < H; h++) {
    for (unsigned w = 0; w < W; w++) {
      // src.write(TI(h*W + w));
      src.write(TI(1));
    }
  }

  unsigned cnt = 0;
  unsigned timeout = 0;
  // while(timeout < 200) {
  // 	deconv_top(src, dst);
  // 	if(dst.empty())  timeout++;
  // 	else {
  // 		auto const  y = dst.read();
  // 		char  delim = cnt%CO == 0? '\t' : ':';
  // 		for(unsigned  pe = 0; pe < PE; pe++) {
  // 			std::cout << delim << std::setw(4) << y[pe];
  // 			delim = ':';
  // 		}
  // 		cnt += PE;
  // 		if(cnt == CO*S*(W-K/S+1)) {
  // 			std::cout << std::endl;
  // 			cnt = 0;
  // 		}
  // 		timeout = 0;
  // 	}
  // }

  std::string fname = std::string("deconv_") + std::to_string(W) + "x" +
                      std::to_string(H) + "_in" + std::to_string(CI) + "_out" +
                      std::to_string(CO) + "_k" + std::to_string(K) + "_s" +
                      std::to_string(S) + "_p" + std::to_string(P) +
                      "_output_hls.csv";
  static std::ofstream ofs(fname);
  if (!ofs.is_open()) {
    std::cerr << "Failed to open CSV output file\n";
    return 1;
  }
  while (timeout < 200) {
    deconv_top(src, dst);
    if (dst.empty())
      timeout++;
    else {
      // build filename from constexpr params in top.hpp

      // auto const y = dst.read();
      // char delim = cnt % CO == 0 ? ',' : ',';
      // bool firstInGroup = (cnt % CO) == 0;
      // for (unsigned pe = 0; pe < PE; pe++) {
      //   std::cout << delim << std::setw(4) << y[pe];
      //   delim = ',';

      //   if (!firstInGroup)
      //     ofs << ',';
      //   ofs << y[pe];
      //   firstInGroup = false;
      // }
      // cnt += PE;
      // if (cnt == CO * S * (W - K / S + 1)) {
      //   std::cout << std::endl;
      //   ofs << '\n';
      //   cnt = 0;
      // }
      // timeout = 0;

      auto const y = dst.read();
      for (unsigned pe = 0; pe < PE; pe++) {
        std::cout << std::setw(4) << y[pe] << '\n';
        ofs << y[pe] << '\n';
      }
      timeout = 0;
    }
  }
  ofs.close();
  std::cout << "Output written to " << fname << std::endl;
}
