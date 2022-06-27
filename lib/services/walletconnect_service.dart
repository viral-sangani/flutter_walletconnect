import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_walletconnect/models/wallet_connect_registry_listing.dart';
import 'package:flutter_walletconnect/services/custom_cred.dart';
import 'package:flutter_walletconnect/utils/constants.dart';
import 'package:http/http.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:walletconnect_dart/walletconnect_dart.dart';
import 'package:walletconnect_secure_storage/walletconnect_secure_storage.dart';
import 'package:web3dart/web3dart.dart';

class FlutterWalletConnect {
  static final FlutterWalletConnect instance = FlutterWalletConnect._internal();

  factory FlutterWalletConnect() {
    return instance;
  }

  FlutterWalletConnect._internal();

  late WalletConnect walletConnect;
  String? account;
  late int chainId = GlobalConstants.chainId;
  late int nonce = 0;
  EtherAmount bal = EtherAmount.fromUnitAndValue(EtherUnit.wei, 0);
  late BlockchainFlavor blockchainFlavor;
  String statusMessage = 'Initialized';
  String curStatus = "";
  late WalletConnectRegistryListing walletListing;

  var apiUrl = GlobalConstants.apiUrl;

  Future<void> initWalletConnect() async {
    // Wallet Connect Session Storage - So we can persist connections
    final sessionStorage = WalletConnectSecureStorage();
    final session = await sessionStorage.getSession();

    // Create a connector
    walletConnect = WalletConnect(
      bridge: GlobalConstants.bridge,
      session: session,
      sessionStorage: sessionStorage,
      clientMeta: const PeerMeta(
        name: GlobalConstants.name,
        url: GlobalConstants.url,
      ),
    );

    // Did we restore a session?
    if (session != null) {
      curStatus =
          "WalletConnect - Restored  v${session.version} session: ${session.accounts.length} account(s), bridge: ${session.bridge} connected: ${session.connected}, clientId: ${session.clientId}";

      if (session.connected) {
        curStatus =
            'WalletConnect - Attempting to reuse existing connection for chainId ${session.chainId} and wallet address ${session.accounts[0]}.';

        account = session.accounts[0];
        chainId = session.chainId;
        blockchainFlavor = BlockchainFlavorExtention.fromChainId(chainId);
      }
    } else {
      curStatus =
          'WalletConnect - No existing sessions.  User needs to connect to a wallet.';
    }

    walletConnect.registerListeners(
      onConnect: (status) {
        // Status is updated, but session.peerinfo is not yet available.
        curStatus =
            'WalletConnect - onConnect - Established connection with  Wallet app: ${walletConnect.session.peerMeta?.name!} -${walletConnect.session.peerMeta?.description}';

        statusMessage =
            'WalletConnect session established with ${walletConnect.session.peerMeta?.name} - ${walletConnect.session.peerMeta?.description}.';
        // Did the user select a new chain?
        if (chainId != status.chainId) {
          curStatus =
              'WalletConnect - onConnect - Selected blockchain has changed: chainId: $chainId <- ${status.chainId})';

          chainId = status.chainId;
          blockchainFlavor = BlockchainFlavorExtention.fromChainId(chainId);
        }

        // Did the user select a new wallet address?
        if (account != status.accounts[0]) {
          curStatus =
              'WalletConnect - onConnect - Selected wallet has changed: minter: $account <- ${status.accounts[0]}';

          account = status.accounts[0];
        }
      },
      onSessionUpdate: (status) {
        // What information is available?
        //print('WalletConnect - Updated session. $status');

        curStatus =
            'WalletConnect - onSessionUpdate - Wallet ${walletConnect.session.peerMeta?.name} - ${walletConnect.session.peerMeta?.description}';

        statusMessage =
            'WalletConnect - SessionUpdate received with chainId ${status.chainId} and account ${status.accounts[0]}.';

        // Did the user select a new chain?
        if (chainId != status.chainId) {
          curStatus =
              'WalletConnect - onSessionUpdate - Selected blockchain has changed: chainId: $chainId <- ${status.chainId}';

          chainId = status.chainId;
          blockchainFlavor = BlockchainFlavorExtention.fromChainId(chainId);
        }

        // Did the user select a new wallet address?
        if (account != status.accounts[0]) {
          curStatus =
              'WalletConnect - onSessionUpdate - Selected wallet has changed: minter: $account <- ${status.accounts[0]}';

          account = status.accounts[0];
        }
      },
      onDisconnect: () async {
        curStatus =
            'WalletConnect - onDisconnect - minter: $account <- "Please Connect Wallet"';

        account = null;
        statusMessage = 'WalletConnect session disconnected.';
        await initWalletConnect();
      },
    );
  }

  Future<void> createWalletConnectSession(BuildContext context) async {
    // Create a new session
    if (walletConnect.connected) {
      statusMessage =
          'Already connected to ${walletConnect.session.peerMeta?.name} \n${walletConnect.session.peerMeta?.description}\n${walletConnect.session.peerMeta?.url}';
      curStatus =
          'createWalletConnectSession - WalletConnect Already connected to ${walletConnect.session.peerMeta?.name} with minter: $account, chainId $chainId. Ignored.';
      return;
    }

    // IOS users will need to be prompted which wallet to use.
    // if (Platform.isIOS) {
    //   List<WalletConnectRegistryListing> listings =
    //       await readWalletRegistry(limit: 4);

    //   await showModalBottomSheet(
    //     context: context,
    //     builder: (context) {
    //       return showIOSWalletSelectionDialog(
    //           context, listings, setWalletListing);
    //     },
    //     isScrollControlled: true,
    //     isDismissible: false,
    //     shape:
    //         RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
    //   );
    // }

    curStatus = 'createWalletConnectSession';
    SessionStatus session;
    try {
      session = await walletConnect.createSession(
          chainId: 44787,
          onDisplayUri: (uri) async {
            // _displayUri = uri;
            curStatus = ('_displayUri updated with $uri');

            // Open any registered wallet via wc: intent
            bool? result;

            // IOS users have already chosen wallet, so customize the launcher
            if (Platform.isIOS) {
              uri =
                  '${walletListing.mobile.universal}/wc?uri=${Uri.encodeComponent(uri)}';
            }
            // Else
            // - Android users will choose their walled from the OS prompt

            curStatus = ('launching uri: $uri');
            try {
              result = await launchUrl(Uri.parse(uri),
                  mode: LaunchMode.externalApplication);
              if (result == false) {
                // launch alternative method
                curStatus =
                    ('Initial launchuri failed. Fallback launch with forceSafariVC true');
                result = await launchUrl(Uri.parse(uri));
                if (result == false) {
                  curStatus = ('Could not launch $uri');
                }
              }
              if (result) {
                statusMessage = 'Launched wallet app, requesting session.';
              }
            } on PlatformException catch (e) {
              if (e.code == 'ACTIVITY_NOT_FOUND') {
                curStatus = ('No wallets available - do nothing!');

                statusMessage =
                    'ERROR - No WalletConnect compatible wallets found.';
                return;
              }
              curStatus = ('launch returned $result');
              curStatus =
                  ('Unexpected PlatformException error: ${e.message}, code: ${e.code}, details: ${e.details}');
            } on Exception catch (e) {
              curStatus = ('launch returned $result');
              curStatus = ('url launcher other error e: $e');
            }
          });
    } catch (e) {
      curStatus = ('Unable to connect - killing the session on our side.');
      statusMessage = 'Unable to connect - killing the session on our side.';
      walletConnect.killSession();
      return;
    }
    if (session.accounts.isEmpty) {
      statusMessage =
          'Failed to connect to wallet.  Bridge Overloaded? Could not Connect?';

      // wc:f54c5bca-7712-4187-908c-9a92aa70d8db@1?bridge=https%3A%2F%2Fz.bridge.walletconnect.org&key=155ca05ffc2ab197772a5bd56a5686728f9fcc2b6eee5ffcb6fd07e46337888c
      curStatus =
          ('Failed to connect to wallet.  Bridge Overloaded? Could not Connect?');
    }
  }

  Future getBalance() async {
    Credentials cred = CustomCredentials(walletConnect);
    var address = await cred.extractAddress();

    var httpClient = Client();
    var ethClient = Web3Client(apiUrl, httpClient);
    bal = await ethClient.getBalance(address);
  }

  Future<String> sendToken(String toAddress, String amount) async {
    final txBytes = await sendTransaction(toAddress, amount);
    return txBytes;
  }

  Future<String> sendTransaction(String toAddress, String amount) async {
    final transaction = Transaction(
      to: EthereumAddress.fromHex(toAddress),
      from: EthereumAddress.fromHex(account!),
      value: EtherAmount.fromUnitAndValue(
        EtherUnit.wei,
        BigInt.from(double.parse(amount) * pow(10, 18)),
      ),
    );
    var httpClient = Client();
    Credentials cred = CustomCredentials(walletConnect);
    var ethClient = Web3Client(apiUrl, httpClient);
    final txBytes = await ethClient.sendTransaction(cred, transaction);
    return txBytes;
  }
}
