/// In-app burner wallet.
///
/// Generates a private key on first launch, stores it in the platform
/// secure enclave/keystore, and exposes credentials for signing.
/// Fund the address from the hackathon/Monad testnet faucet.
library wallet_service;

import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';

class WalletService {
  static const _kKey = 'plotproof_pk_v1';
  static const _storage = FlutterSecureStorage();

  EthPrivateKey? _credentials;

  /// Load the wallet, creating one on first run.
  Future<EthPrivateKey> load() async {
    if (_credentials != null) return _credentials!;

    var hex = await _storage.read(key: _kKey);
    if (hex == null) {
      final key = EthPrivateKey.createRandom(Random.secure());
      hex = bytesToHex(key.privateKey, include0x: true);
      await _storage.write(key: _kKey, value: hex);
    }
    _credentials = EthPrivateKey.fromHex(hex);
    return _credentials!;
  }

  Future<EthereumAddress> address() async => (await load()).address;
}
