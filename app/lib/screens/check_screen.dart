import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../geocell.dart';
import '../services/chain_service.dart';
import '../theme.dart';

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
  final _mapController = MapController();

  LatLng? _pin;
  List<ChainClaim> _claims = [];
  bool _busy = false;
  String? _error;
  bool _checked = false;

  int get _claimantCount =>
      _claims.map((c) => c.claimant.hexEip55).toSet().length;
  bool get _hasConflict => _claimantCount > 1;

  Future<void> _check(LatLng p) async {
    setState(() {
      _pin = p;
      _busy = true;
      _error = null;
      _claims = [];
      _checked = false;
    });
    try {
      final cells =
          cellBlock(p.latitude, p.longitude).map(cellToBytes32).toList();
      final claims = await widget.chain.getClaimsBatch(cells);
      claims.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      if (!mounted) return;
      setState(() {
        _claims = claims;
        _checked = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyError(Object e) =>
      'Could not reach Monad to check this plot. Check your connection and try again.';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 900;
      if (wide) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: _mapCard()),
              const SizedBox(width: 20),
              SizedBox(width: 440, child: _resultPanel(scroll: true)),
            ],
          ),
        );
      }
      return Column(
        children: [
          Expanded(flex: 5, child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _mapCard(),
          )),
          Expanded(flex: 5, child: _resultPanel(scroll: true)),
        ],
      );
    });
  }

  Widget _mapCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pin ?? _initialCenter,
              initialZoom: 15,
              onTap: (_, latlng) => _check(latlng),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'ng.plotproof.app',
              ),
              MarkerLayer(markers: [
                for (final cclaim in _claims)
                  Marker(
                    point: LatLng(cclaim.lat, cclaim.lng),
                    width: 30,
                    height: 30,
                    child: Icon(Icons.flag,
                        size: 26,
                        color: _hasConflict
                            ? AppColors.danger
                            : AppColors.warning),
                  ),
                if (_pin != null)
                  Marker(
                    point: _pin!,
                    width: 44,
                    height: 44,
                    child: const Icon(Icons.location_on,
                        size: 44, color: AppColors.brand),
                  ),
              ]),
            ],
          ),
          Positioned(
            left: 12,
            top: 12,
            right: 12,
            child: _MapHint(busy: _busy),
          ),
        ],
      ),
    );
  }

  Widget _resultPanel({required bool scroll}) {
    final fmt = DateFormat('d MMM yyyy · HH:mm');
    return Container(
      color: AppColors.background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        physics: scroll ? null : const NeverScrollableScrollPhysics(),
        children: [
          if (_pin != null) _CoordChip(pin: _pin!),
          if (_pin != null) const SizedBox(height: 12),
          _resultBody(fmt),
        ],
      ),
    );
  }

  Widget _resultBody(DateFormat fmt) {
    if (_pin == null) {
      return const _EmptyPrompt();
    }
    if (_busy) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return _StateBanner(
        bg: AppColors.dangerBg,
        border: AppColors.dangerBorder,
        icon: Icons.wifi_off_rounded,
        iconColor: AppColors.danger,
        title: 'Check failed',
        body: _error!,
      );
    }
    if (!_checked) return const SizedBox.shrink();

    if (_claims.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StateBanner(
            bg: AppColors.successBg,
            border: AppColors.success.withValues(alpha: 0.35),
            icon: Icons.verified_rounded,
            iconColor: AppColors.success,
            title: 'No claims on this plot',
            body: 'Nobody has staked a PlotProof claim here or on the '
                'surrounding cells yet.',
          ),
          const SizedBox(height: 12),
          const _FootNote(
              'Still confirm the title at the state land registry before paying.'),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hasConflict)
          _StateBanner(
            bg: AppColors.dangerBg,
            border: AppColors.dangerBorder,
            icon: Icons.warning_amber_rounded,
            iconColor: AppColors.danger,
            title: 'Possible double sale',
            body: '${_claims.length} claims by $_claimantCount different '
                'wallets on this plot. Investigate before paying anyone.',
          )
        else
          _StateBanner(
            bg: AppColors.warningBg,
            border: AppColors.warning.withValues(alpha: 0.3),
            icon: Icons.info_rounded,
            iconColor: AppColors.warning,
            title: '${_claims.length} existing claim'
                '${_claims.length == 1 ? '' : 's'}',
            body: 'This area already has a PlotProof record. Review who '
                'staked it and when.',
          ),
        const SizedBox(height: 16),
        Text('Claim history',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ..._claims.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ClaimTile(claim: c, fmt: fmt),
            )),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

class _MapHint extends StatelessWidget {
  final bool busy;
  const _MapHint({required this.busy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        boxShadow: kSoftShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (busy)
            const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(strokeWidth: 2))
          else
            const Icon(Icons.touch_app_rounded,
                size: 17, color: AppColors.brand),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              busy ? 'Checking on Monad…' : 'Tap a plot to check it',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoordChip extends StatelessWidget {
  final LatLng pin;
  const _CoordChip({required this.pin});

  @override
  Widget build(BuildContext context) {
    final cell = encodeGeohash(pin.latitude, pin.longitude);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.brandTint,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Row(
        children: [
          const Icon(Icons.my_location_rounded,
              size: 16, color: AppColors.brand),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${pin.latitude.toStringAsFixed(6)}, '
              '${pin.longitude.toStringAsFixed(6)}   ·   cell $cell',
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.brand,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StateBanner extends StatelessWidget {
  final Color bg;
  final Color border;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  const _StateBanner({
    required this.bg,
    required this.border,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink)),
                const SizedBox(height: 3),
                Text(body,
                    style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: AppColors.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaimTile extends StatelessWidget {
  final ChainClaim claim;
  final DateFormat fmt;
  const _ClaimTile({required this.claim, required this.fmt});

  Color get _avatarColor {
    final h = claim.claimant.hexEip55;
    final v = int.parse(h.substring(2, 8), radix: 16);
    return HSLColor.fromAHSL(1, (v % 360).toDouble(), 0.45, 0.42).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final addr = claim.claimant.hexEip55;
    final short = '${addr.substring(0, 6)}…${addr.substring(addr.length - 4)}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(color: _avatarColor, shape: BoxShape.circle),
            child: const Icon(Icons.person, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(claim.note.isEmpty ? 'Unlabelled plot' : claim.note,
                    style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink)),
                const SizedBox(height: 4),
                Text('$short   ·   ${fmt.format(claim.timestamp.toLocal())}',
                    style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()],
                        fontSize: 12,
                        color: AppColors.inkSoft)),
                const SizedBox(height: 2),
                Text(
                    '${claim.lat.toStringAsFixed(6)}, '
                    '${claim.lng.toStringAsFixed(6)}',
                    style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()],
                        fontSize: 11.5,
                        color: AppColors.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPrompt extends StatelessWidget {
  const _EmptyPrompt();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
                color: AppColors.brandTint, shape: BoxShape.circle),
            child: const Icon(Icons.travel_explore,
                color: AppColors.brand, size: 32),
          ),
          const SizedBox(height: 16),
          Text('Check before you pay',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Tap the exact plot on the map. PlotProof reads Monad and shows '
              'every prior claim on that spot and its neighbours.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.45, color: AppColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

class _FootNote extends StatelessWidget {
  final String text;
  const _FootNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lightbulb_outline_rounded,
            size: 16, color: AppColors.inkSoft),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 12.5, height: 1.4, color: AppColors.inkSoft)),
        ),
      ],
    );
  }
}
