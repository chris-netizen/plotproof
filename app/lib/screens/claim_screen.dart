import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../evidence.dart';
import '../geocell.dart';
import '../services/chain_service.dart';
import '../services/wallet_service.dart';

/// Stake a claim: photo -> GPS -> hash -> one Monad transaction.
class ClaimScreen extends StatefulWidget {
  final WalletService wallet;
  final ChainService chain;
  const ClaimScreen({super.key, required this.wallet, required this.chain});

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

  Future<void> _capture() async {
    setState(() => _status = null);

    // 1. Photo
    final img =
        await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
    if (img == null) return;

    // 2. GPS (with permission handling)
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

      setState(() => _status = 'Sending transaction to Monad…');

      final tx = await widget.chain.stakeClaim(
        credentials: creds,
        cell: cell,
        evidenceHash: hash,
        latE7: latE7,
        lngE7: lngE7,
        note: _noteCtrl.text.trim(),
      );

      setState(() {
        _txHash = tx;
        _status = 'Claim staked on cell $cellStr ✅';
      });
    } catch (e) {
      setState(() => _status = 'Failed: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Stake a claim',
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const Text(
            'Stand on the plot. PlotProof anchors your photo + GPS + time '
            'to Monad — permanently.'),
        const SizedBox(height: 20),
        if (_photo != null && _pos != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(_photo!.path), height: 220, fit: BoxFit.cover),
          ),
          const SizedBox(height: 8),
          Text(
            '📍 ${_pos!.latitude.toStringAsFixed(6)}, '
            '${_pos!.longitude.toStringAsFixed(6)}  '
            '(±${_pos!.accuracy.toStringAsFixed(0)}m)\n'
            '⬡ cell ${encodeGeohash(_pos!.latitude, _pos!.longitude)}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Plot label',
              hintText: 'e.g. Plot 14, Palm Garden City, Enugu',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.anchor),
            label: const Text('Stake claim on Monad'),
          ),
        ] else
          FilledButton.icon(
            onPressed: _busy ? null : _capture,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Capture plot evidence'),
          ),
        if (_status != null) ...[
          const SizedBox(height: 16),
          Text(_status!),
        ],
        if (_txHash != null) ...[
          const SizedBox(height: 4),
          SelectableText('tx: $_txHash',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ],
      ],
    );
  }
}
