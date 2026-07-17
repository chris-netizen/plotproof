import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web3dart/web3dart.dart';

import 'screens/check_screen.dart';
import 'screens/claim_screen.dart';
import 'services/chain_service.dart';
import 'services/wallet_service.dart';
import 'theme.dart';

void main() => runApp(const PlotProofApp());

class PlotProofApp extends StatelessWidget {
  const PlotProofApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlotProof',
      debugShowCheckedModeBanner: false,
      theme: buildPlotProofTheme(),
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
    EtherAmount? b;
    try {
      b = await _chain.balance(a);
    } catch (_) {
      // Offline / RPC unreachable — show the address anyway.
    }
    if (!mounted) return;
    setState(() {
      _addr = a;
      _balance = b;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      CheckScreen(chain: _chain, wallet: _wallet),
      ClaimScreen(wallet: _wallet, chain: _chain, onStaked: _loadWallet),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            const BrandMark(size: 30),
            const SizedBox(width: 10),
            Text(
              'PlotProof',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          if (_addr != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _WalletPill(addr: _addr!, balance: _balance),
            ),
        ],
      ),
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.travel_explore_outlined),
              selectedIcon: Icon(Icons.travel_explore),
              label: 'Check plot'),
          NavigationDestination(
              icon: Icon(Icons.add_location_alt_outlined),
              selectedIcon: Icon(Icons.add_location_alt),
              label: 'Stake claim'),
        ],
      ),
    );
  }
}

/// The PlotProof mark: a green rounded tile with a white location pin —
/// small, recognisable, works at app-bar and icon scale.
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandBright, AppColors.brand],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(Icons.location_on, color: Colors.white, size: size * 0.62),
    );
  }
}

class _WalletPill extends StatelessWidget {
  final EthereumAddress addr;
  final EtherAmount? balance;
  const _WalletPill({required this.addr, this.balance});

  @override
  Widget build(BuildContext context) {
    final hex = addr.hexEip55;
    final short = '${hex.substring(0, 6)}…${hex.substring(hex.length - 4)}';
    final mon = balance == null
        ? '—'
        : '${balance!.getValueInUnit(EtherUnit.ether).toStringAsFixed(3)} MON';
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: hex));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Wallet address copied'),
              duration: Duration(seconds: 2)),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                  color: AppColors.success, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Text('$short · $mon',
                style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink)),
          ],
        ),
      ),
    );
  }
}
