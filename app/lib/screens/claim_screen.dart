import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../evidence.dart';
import '../geocell.dart';
import '../services/chain_service.dart';
import '../services/wallet_service.dart';
import '../theme.dart';

/// Stake a claim: photo -> GPS -> hash -> one Monad transaction.
class ClaimScreen extends StatefulWidget {
  final WalletService wallet;
  final ChainService chain;
  final VoidCallback? onStaked;
  const ClaimScreen({
    super.key,
    required this.wallet,
    required this.chain,
    this.onStaked,
  });

  @override
  State<ClaimScreen> createState() => _ClaimScreenState();
}

class _ClaimScreenState extends State<ClaimScreen> {
  final _noteCtrl = TextEditingController();
  XFile? _photo;
  Position? _pos;
  String? _status;
  String? _txHash;
  bool _busy = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    setState(() => _status = null);
    try {
      final img = await ImagePicker()
          .pickImage(source: ImageSource.camera, imageQuality: 85);
      if (img == null) return;

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() => _status = 'Location permission is required to claim.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best);

      setState(() {
        _photo = img;
        _pos = pos;
      });
    } catch (e) {
      setState(() => _status = 'Capture failed: $e');
    }
  }

  Future<void> _submit() async {
    if (_photo == null || _pos == null) return;
    setState(() {
      _busy = true;
      _status = 'Hashing evidence…';
    });

    try {
      final creds = await widget.wallet.load();
      final photoBytes = await _photo!.readAsBytes();
      final latE7 = toE7(_pos!.latitude);
      final lngE7 = toE7(_pos!.longitude);
      final ts = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

      final hash = evidenceHash(
        photoBytes: Uint8List.fromList(photoBytes),
        latE7: latE7,
        lngE7: lngE7,
        tsUnixSecs: ts,
        claimant: creds.address,
      );

      final cellStr = encodeGeohash(_pos!.latitude, _pos!.longitude);
      final cell = cellToBytes32(cellStr);

      // Save photo + sidecar locally so it can be verified later.
      try {
        final dir = await getApplicationDocumentsDirectory();
        final base = '${dir.path}/claim_$ts';
        await File('$base.jpg').writeAsBytes(photoBytes);
        await File('$base.json').writeAsString(jsonEncode(EvidenceMeta(
          latE7: latE7,
          lngE7: lngE7,
          tsUnixSecs: ts,
          claimant: creds.address.hexEip55,
          cell: cellStr,
          note: _noteCtrl.text.trim(),
        ).toJson()));
      } catch (_) {
        // Non-fatal (e.g. web has no documents dir) — the chain record
        // is what matters; local sidecar is a convenience.
      }

      setState(() => _status = 'Sending transaction to Monad…');

      final tx = await widget.chain.stakeClaim(
        credentials: creds,
        cell: cell,
        evidenceHash: hash,
        latE7: latE7,
        lngE7: lngE7,
        note: _noteCtrl.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _txHash = tx;
        _status = cellStr;
      });
      widget.onStaked?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reset() {
    setState(() {
      _photo = null;
      _pos = null;
      _txHash = null;
      _status = null;
      _noteCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_txHash != null)
              _SuccessCard(
                  txHash: _txHash!, cell: _status ?? '', onAgain: _reset)
            else ...[
              Text('Stake a claim',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              const Text(
                'Stand on the plot. PlotProof anchors your photo, GPS and the '
                'time to Monad — permanently.',
                style: TextStyle(fontSize: 14, height: 1.45, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 20),
              if (_photo != null && _pos != null)
                _capturedView(context)
              else
                _capturePrompt(),
              if (_status != null && _txHash == null) ...[
                const SizedBox(height: 16),
                _StatusLine(text: _status!, busy: _busy),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _capturePrompt() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
                color: AppColors.brandTint, shape: BoxShape.circle),
            child: const Icon(Icons.photo_camera_rounded,
                size: 34, color: AppColors.brand),
          ),
          const SizedBox(height: 16),
          const Text('Capture plot evidence',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink)),
          const SizedBox(height: 6),
          const Text(
            'Take a photo while standing on the plot. Your device location and '
            'the current time are captured with it.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.45, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _capture,
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Open camera'),
          ),
        ],
      ),
    );
  }

  Widget _capturedView(BuildContext context) {
    final cell = encodeGeohash(_pos!.latitude, _pos!.longitude);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Image.file(File(_photo!.path),
              height: 220, width: double.infinity, fit: BoxFit.cover),
        ),
        const SizedBox(height: 12),
        // Receipt-style capture readout.
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _ReceiptRow(
                  icon: Icons.my_location_rounded,
                  label: 'Coordinates',
                  value:
                      '${_pos!.latitude.toStringAsFixed(6)}, ${_pos!.longitude.toStringAsFixed(6)}'),
              const Divider(height: 20),
              _ReceiptRow(
                  icon: Icons.gps_fixed_rounded,
                  label: 'Accuracy',
                  value: '±${_pos!.accuracy.toStringAsFixed(0)} m'),
              const Divider(height: 20),
              _ReceiptRow(
                  icon: Icons.grid_on_rounded, label: 'Geocell', value: cell),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _noteCtrl,
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: 'Plot label',
            hintText: 'e.g. Plot 14, Palm Garden City, Enugu',
          ),
        ),
        const SizedBox(height: 4),
        FilledButton.icon(
          onPressed: _busy ? null : _submit,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.anchor_rounded),
          label: Text(_busy ? 'Staking…' : 'Stake claim on Monad'),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _busy ? null : _reset,
            child: const Text('Retake'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _ReceiptRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ReceiptRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.brand),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(fontSize: 13.5, color: AppColors.inkSoft)),
        const Spacer(),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink)),
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  final String text;
  final bool busy;
  const _StatusLine({required this.text, required this.busy});

  @override
  Widget build(BuildContext context) {
    final isError = text.startsWith('Failed') ||
        text.startsWith('Capture failed') ||
        text.contains('permission');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError ? AppColors.dangerBg : AppColors.brandTint,
        borderRadius: BorderRadius.circular(AppRadii.control),
      ),
      child: Row(
        children: [
          if (busy)
            const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
          else
            Icon(isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
                size: 18,
                color: isError ? AppColors.danger : AppColors.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13.5,
                    color: isError ? AppColors.danger : AppColors.brand,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _SuccessCard extends StatelessWidget {
  final String txHash;
  final String cell;
  final VoidCallback onAgain;
  const _SuccessCard(
      {required this.txHash, required this.cell, required this.onAgain});

  Future<void> _openExplorer() async {
    final uri = Uri.parse('${ChainConfig.explorerTxBase}$txHash');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final short = '${txHash.substring(0, 10)}…${txHash.substring(txHash.length - 8)}';
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 84,
          height: 84,
          decoration: const BoxDecoration(
              color: AppColors.successBg, shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_rounded,
              size: 46, color: AppColors.success),
        ),
        const SizedBox(height: 18),
        Text('Claim staked', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text('Anchored to Monad on cell $cell',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.inkSoft)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.receipt_long_rounded,
                  size: 18, color: AppColors.brand),
              const SizedBox(width: 10),
              const Text('Transaction',
                  style: TextStyle(fontSize: 13.5, color: AppColors.inkSoft)),
              const Spacer(),
              Flexible(
                child: Text(short,
                    style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()],
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _openExplorer,
          icon: const Icon(Icons.open_in_new_rounded),
          label: const Text('View on explorer'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onAgain,
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Stake another'),
        ),
      ],
    );
  }
}
