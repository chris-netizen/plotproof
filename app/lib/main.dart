import 'package:flutter/material.dart';
import 'package:web3dart/web3dart.dart';

import 'screens/check_screen.dart';
import 'screens/claim_screen.dart';
import 'services/chain_service.dart';
import 'services/wallet_service.dart';

void main() => runApp(const PlotProofApp());

class PlotProofApp extends StatelessWidget {
  const PlotProofApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Give it an identity — not default Material blue.
    const seed = Color(0xFF1B5E20); // deep land-green; tweak on day 3 pass
    return MaterialApp(
      title: 'PlotProof',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      home: const _Home(),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  final _wallet = WalletService();
  late final _chain = ChainService();

  int _tab = 0; // Check first — it's the everyday screen.
  EthereumAddress? _addr;
  EtherAmount? _balance;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    final a = await _wallet.address();
    final b = await _chain.balance(a);
    setState(() {
      _addr = a;
      _balance = b;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      CheckScreen(chain: _chain),
      ClaimScreen(wallet: _wallet, chain: _chain),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('PlotProof'),
        actions: [
          if (_addr != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  '${_addr!.hexEip55.substring(0, 6)}… · '
                  '${_balance?.getValueInUnit(EtherUnit.ether).toStringAsFixed(3) ?? '…'} MON',
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
        ],
      ),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.search), label: 'Check plot'),
          NavigationDestination(icon: Icon(Icons.anchor), label: 'Claim'),
        ],
      ),
    );
  }
}
