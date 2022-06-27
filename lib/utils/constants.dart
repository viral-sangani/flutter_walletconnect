import 'package:flutter/material.dart';

class GlobalConstants {
  static const String apiUrl = "https://alfajores-forno.celo-testnet.org";
  static const String bridge = "https://bridge.walletconnect.org";
  static const String name = "Celo Composer - Flutter";
  static const String url = "https://celo.org";
  static const int chainId = 5;
}

enum BlockchainFlavor {
  ropsten,
  rinkeby,
  ethMainNet,
  polygonMainNet,
  mumbai,
  unknown,
}

extension BlockchainFlavorExtention on BlockchainFlavor {
  static BlockchainFlavor fromChainId(int chainId) {
    switch (chainId) {
      case 80001:
        return BlockchainFlavor.mumbai;
      case 137:
        return BlockchainFlavor.polygonMainNet;
      case 3:
        return BlockchainFlavor.ropsten;
      case 4:
        return BlockchainFlavor.rinkeby;
      case 1:
        return BlockchainFlavor.ethMainNet;
      default:
        return BlockchainFlavor.unknown;
    }
  }
}

class ColorConstants {
  static Color lightScaffoldBackgroundColor = const Color(0xFFF5F5F5);
  static Color darkScaffoldBackgroundColor = const Color(0xFF1D1D1D);

  static Color primaryAppColor = const Color(0xFF37CF7C);
  static Color primaryBlackAppColor = const Color(0xFF37CF7C);

  static Color secondaryAppColor = const Color(0xFFFACD5C);
  static Color secondaryBlackAppColor = const Color(0xFFFACD5C);
}
