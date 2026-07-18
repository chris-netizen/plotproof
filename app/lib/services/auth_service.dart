import 'package:local_auth/local_auth.dart';

/// Gates sensitive actions (like selling a claim) behind the device's own
/// biometrics or PIN, so simply holding the phone isn't enough to move an
/// asset. This is a local identity check — the on-chain owner-only rule in
/// PlotProof.transferClaim is the actual authorization.
class AuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// Whether the device can perform any authentication (biometric or PIN).
  Future<bool> get isAvailable async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Ask the user to prove it's them.
  ///
  /// Returns true if confirmed — or if the device has no lock configured at
  /// all (nothing to check against, so we don't hard-block the owner). Returns
  /// false when a check was possible but was cancelled or failed.
  Future<bool> confirm(String reason) async {
    try {
      if (!await _auth.isDeviceSupported()) return true;
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false, // allow device PIN / pattern as a fallback
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      // Fail closed: if we can't complete a possible check, don't proceed.
      return false;
    }
  }
}
