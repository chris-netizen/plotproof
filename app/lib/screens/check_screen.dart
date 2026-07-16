import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../geocell.dart';
import '../services/chain_service.dart';

/// THE HERO SCREEN: check a plot before you pay.
/// Tap the map -> query the cell + 8 neighbours on Monad -> see every
/// prior claim. Claims by different addresses = conflict warning.
class CheckScreen extends StatefulWidget {
  final ChainService chain;
  const CheckScreen({super.key, required this.chain});

  @override
  State<CheckScreen> createState() => _CheckScreenState();
}

class _CheckScreenState extends State<CheckScreen> {
  // Default view: Enugu. Change to your demo area.
  static final _initialCenter = LatLng(6.4402, 7.4943);

  LatLng? _pin;
  List<ChainClaim> _claims = [];
  bool _busy = false;
  String? _error;

  bool get _hasConflict =>
      _claims.map((c) => c.claimant.hexEip55).toSet().length > 1;

  Future<void> _check(LatLng p) async {
    setState(() {
      _pin = p;
      _busy = true;
      _error = null;
      _claims = [];
    });
    try {
      final cells = cellBlock(p.latitude, p.longitude)
          .map(cellToBytes32)
          .toList();
      final claims = await widget.chain.getClaimsBatch(cells);
      claims.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      setState(() => _claims = claims);
    } catch (e) {
      setState(() => _error = 'Query failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy, HH:mm');
    return Column(
      children: [
        Expanded(
          flex: 5,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 15,
              onTap: (_, latlng) => _check(latlng),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'ng.plotproof.app',
              ),
              if (_pin != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _pin!,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_pin,
                        size: 40, color: Colors.red),
                  ),
                  // Markers for each existing claim near the pin
                  ..._claims.map((c) => Marker(
                        point: LatLng(c.lat, c.lng),
                        width: 30,
                        height: 30,
                        child: const Icon(Icons.flag,
                            size: 28, color: Colors.deepOrange),
                      )),
                ]),
            ],
          ),
        ),
        Expanded(
          flex: 4,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: _buildResult(fmt),
          ),
        ),
      ],
    );
  }

  Widget _buildResult(DateFormat fmt) {
    if (_pin == null) {
      return const Center(
        child: Text('Tap the plot on the map to check it\n'
            'before you pay anyone.', textAlign: TextAlign.center),
      );
    }
    if (_busy) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));

    if (_claims.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _banner(Colors.green.shade100, Icons.verified_outlined,
              'No claims recorded on this plot or its surroundings.'),
          const SizedBox(height: 8),
          const Text(
              'This means no one has staked a PlotProof claim here yet. '
              'Always still verify title at the state land registry.',
              style: TextStyle(fontSize: 13)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _hasConflict
            ? _banner(
                Colors.red.shade100,
                Icons.warning_amber_rounded,
                '⚠ ${_claims.length} claims by '
                '${_claims.map((c) => c.claimant.hexEip55).toSet().length} '
                'different addresses. Possible double sale — investigate '
                'before paying.')
            : _banner(Colors.amber.shade100, Icons.info_outline,
                '${_claims.length} existing claim(s) on this area.'),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            itemCount: _claims.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final c = _claims[i];
              final addr = c.claimant.hexEip55;
              return ListTile(
                dense: true,
                leading: const Icon(Icons.flag),
                title: Text(c.note.isEmpty ? '(no label)' : c.note),
                subtitle: Text(
                  '${addr.substring(0, 6)}…${addr.substring(addr.length - 4)} '
                  '· ${fmt.format(c.timestamp.toLocal())}\n'
                  '${c.lat.toStringAsFixed(6)}, ${c.lng.toStringAsFixed(6)}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _banner(Color bg, IconData icon, String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ]),
      );
}
