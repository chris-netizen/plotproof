/// PlotProof contract binding for web3dart.
///
/// Handles the two calls the app needs:
///   - stakeClaim(...)      write
///   - getClaimsBatch(...)  read across a 9-cell block, tuple[] decoded
library chain_service;

import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';

import '../config.dart';

/// Decoded on-chain claim.
class ChainClaim {
  final String cellHex; // bytes32 of the geohash cell (hex)
  final EthereumAddress claimant;
  final Uint8List evidenceHash;
  final int latE7;
  final int lngE7;
  final DateTime timestamp;
  final String note;

  ChainClaim({
    required this.cellHex,
    required this.claimant,
    required this.evidenceHash,
    required this.latE7,
    required this.lngE7,
    required this.timestamp,
    required this.note,
  });

  double get lat => latE7 / 1e7;
  double get lng => lngE7 / 1e7;
}

const _abi = '''
[
  {"type":"function","name":"stakeClaim","stateMutability":"nonpayable",
   "inputs":[
     {"name":"cell","type":"bytes32"},
     {"name":"evidenceHash","type":"bytes32"},
     {"name":"latE7","type":"int64"},
     {"name":"lngE7","type":"int64"},
     {"name":"note","type":"string"}],
   "outputs":[]},
  {"type":"function","name":"claimCounts","stateMutability":"view",
   "inputs":[{"name":"cells","type":"bytes32[]"}],
   "outputs":[{"name":"counts","type":"uint256[]"}]},
  {"type":"function","name":"getClaimsBatch","stateMutability":"view",
   "inputs":[{"name":"cells","type":"bytes32[]"}],
   "outputs":[
     {"name":"cellOf","type":"bytes32[]"},
     {"name":"claims","type":"tuple[]","components":[
       {"name":"claimant","type":"address"},
       {"name":"evidenceHash","type":"bytes32"},
       {"name":"latE7","type":"int64"},
       {"name":"lngE7","type":"int64"},
       {"name":"timestamp","type":"uint64"},
       {"name":"note","type":"string"}]}]},
  {"type":"function","name":"hasEvidence","stateMutability":"view",
   "inputs":[
     {"name":"cell","type":"bytes32"},
     {"name":"evidenceHash","type":"bytes32"}],
   "outputs":[
     {"name":"found","type":"bool"},
     {"name":"index","type":"uint256"}]},
  {"type":"function","name":"totalClaims","stateMutability":"view",
   "inputs":[],"outputs":[{"name":"","type":"uint256"}]}
]
''';

class ChainService {
  late final Web3Client _client;
  late final DeployedContract _contract;
  late final ContractFunction _stakeClaim;
  late final ContractFunction _getClaimsBatch;
  late final ContractFunction _hasEvidence;
  late final ContractFunction _totalClaims;

  ChainService() {
    _client = Web3Client(ChainConfig.rpcUrl, http.Client());
    _contract = DeployedContract(
      ContractAbi.fromJson(_abi, 'PlotProof'),
      EthereumAddress.fromHex(ChainConfig.contractAddress),
    );
    _stakeClaim = _contract.function('stakeClaim');
    _getClaimsBatch = _contract.function('getClaimsBatch');
    _hasEvidence = _contract.function('hasEvidence');
    _totalClaims = _contract.function('totalClaims');
  }

  Future<EtherAmount> balance(EthereumAddress addr) =>
      _client.getBalance(addr);

  /// Write: stake a claim. Returns the tx hash.
  Future<String> stakeClaim({
    required EthPrivateKey credentials,
    required Uint8List cell, // 32 bytes
    required Uint8List evidenceHash, // 32 bytes
    required int latE7,
    required int lngE7,
    required String note,
  }) {
    return _client.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: _contract,
        function: _stakeClaim,
        parameters: [
          cell,
          evidenceHash,
          BigInt.from(latE7),
          BigInt.from(lngE7),
          note,
        ],
      ),
      chainId: ChainConfig.chainId,
    );
  }

  /// Read: all claims across a set of cells (center + neighbours).
  Future<List<ChainClaim>> getClaimsBatch(List<Uint8List> cells) async {
    final res = await _client.call(
      contract: _contract,
      function: _getClaimsBatch,
      params: [cells],
    );

    final cellOf = (res[0] as List).cast<Uint8List>();
    final rawClaims = (res[1] as List);

    final out = <ChainClaim>[];
    for (var i = 0; i < rawClaims.length; i++) {
      final c = rawClaims[i] as List; // decoded tuple
      out.add(ChainClaim(
        cellHex: _hex(cellOf[i]),
        claimant: c[0] as EthereumAddress,
        evidenceHash: c[1] as Uint8List,
        latE7: (c[2] as BigInt).toInt(),
        lngE7: (c[3] as BigInt).toInt(),
        timestamp: DateTime.fromMillisecondsSinceEpoch(
            (c[4] as BigInt).toInt() * 1000),
        note: c[5] as String,
      ));
    }
    return out;
  }

  /// Read: does this exact evidence hash exist on this cell?
  Future<bool> hasEvidence(Uint8List cell, Uint8List evidenceHash) async {
    final res = await _client.call(
      contract: _contract,
      function: _hasEvidence,
      params: [cell, evidenceHash],
    );
    return res[0] as bool;
  }

  Future<BigInt> totalClaims() async {
    final res = await _client
        .call(contract: _contract, function: _totalClaims, params: []);
    return res[0] as BigInt;
  }

  static String _hex(Uint8List b) =>
      '0x${b.map((x) => x.toRadixString(16).padLeft(2, '0')).join()}';
}
