/// PlotProof chain configuration.
///
/// ⚠️ THE ONLY FILE YOU MUST EDIT.
/// Get the current Monad TESTNET values from https://docs.monad.xyz
/// (do not trust values copied from blogs — they rotate).
library config;

class ChainConfig {
  /// Monad testnet JSON-RPC endpoint (from docs.monad.xyz).
  static const String rpcUrl = 'https://testnet-rpc.monad.xyz';

  /// Monad testnet chain id (from docs.monad.xyz).
  static const int chainId = 10143; // PASTE REAL CHAIN ID

  /// Your deployed PlotProof contract address.
  static const String contractAddress =
      '0x0e568Fb730D1Ce4b79c9200d516a872C1Aeda6F2';

  /// Block explorer base URL for linking to txs (from docs.monad.xyz).
  static const String explorerTxBase = 'https://testnet.monadexplorer.com/tx/';

  /// Faucet for funding the in-app wallet with testnet MON (for gas).
  static const String faucetUrl = 'https://faucet.monad.xyz/';
}
