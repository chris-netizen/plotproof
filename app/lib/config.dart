/// PlotProof chain configuration.
///
/// ⚠️ THE ONLY FILE YOU MUST EDIT.
/// Get the current Monad TESTNET values from https://docs.monad.xyz
/// (do not trust values copied from blogs — they rotate).
library config;

class ChainConfig {
  /// Monad testnet JSON-RPC endpoint (from docs.monad.xyz).
  static const String rpcUrl = 'PASTE_MONAD_TESTNET_RPC_URL';

  /// Monad testnet chain id (from docs.monad.xyz).
  static const int chainId = 0; // PASTE REAL CHAIN ID

  /// Your deployed PlotProof contract address.
  static const String contractAddress = '0xPASTE_DEPLOYED_ADDRESS';

  /// Block explorer base URL for linking to txs (from docs.monad.xyz).
  static const String explorerTxBase = 'PASTE_EXPLORER_URL/tx/';
}
