import 'dart:convert';

import 'package:flutter_walletconnect/models/wallet_connect_registry_listing.dart';
import 'package:http/http.dart' as http;

Future<List<WalletConnectRegistryListing>> readWalletRegistry(
    {int limit = 4}) async {
  String curStatus = "";
  List<WalletConnectRegistryListing> listings = [];

  var client = http.Client();
  try {
    http.Response response;

    final queryParameters = {
      'entries': '$limit',
      'page': '1',
    };

    curStatus = ('Requesting WalletConnect Registry for first $limit wallets.');
    response = await client.get(
      Uri.https(
        'registry.walletconnect.com',
        'api/v1/wallets',
        queryParameters,
      ),
      headers: {
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      //log(response.body);
      var decodedResponse =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>?;

      if (decodedResponse != null && decodedResponse['listings'] != null) {
        // Present user with list of supported wallets (IOS)

        for (Map<String, dynamic> entry in decodedResponse['listings'].values) {
          listings.add(WalletConnectRegistryListing.fromJson(entry));
          //curStatus = ('Processing ${listings.last.name}');
        }
      }
      return listings;
    } else {
      curStatus =
          ('Unexpected server error: ${response.statusCode}: ${response.reasonPhrase}.');
    }
  } catch (e) {
    curStatus = ('Unexpected protocol error: $e');
  } finally {
    client.close();
  }
  return listings;
}
