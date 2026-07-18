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
  Future<EthPrivateKey>? _loading; // shared so concurrent callers don't race

  /// Load the wallet, creating one on first run.
  ///
  /// Concurrent callers (e.g. the wallet pill and the claim screen loading at
  /// the same time) must share a single create-or-read operation — otherwise
  /// each would generate a different key and the app would show two wallets.
  Future<EthPrivateKey> load() {
    if (_credentials != null) return Future.value(_credentials!);
    return _loading ??= _loadOrCreate();
  }

  Future<EthPrivateKey> _loadOrCreate() async {
    try {
      var hex = await _storage.read(key: _kKey);
      if (hex == null) {
        final key = EthPrivateKey.createRandom(Random.secure());
        hex = bytesToHex(key.privateKey, include0x: true);
        await _storage.write(key: _kKey, value: hex);
      }
      _credentials = EthPrivateKey.fromHex(hex);
      return _credentials!;
    } finally {
      _loading = null;
    }
  }

  Future<EthereumAddress> address() async => (await load()).address;
}
