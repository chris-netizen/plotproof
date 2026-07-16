// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title PlotProof
/// @notice A tamper-proof, geo-anchored claim ledger for land plots.
///         Claims are indexed by geohash cell (bytes32) so anyone can
///         query "has this plot already been claimed?" before buying.
/// @dev    Designed for Monad testnet. Evidence (photo etc.) stays
///         off-chain; only its keccak256 hash is stored, proving the
///         evidence existed at claim time without revealing it.
contract PlotProof {
    // ---------------------------------------------------------------
    // Types
    // ---------------------------------------------------------------

    struct Claim {
        address claimant;      // who staked the claim
        bytes32 evidenceHash;  // keccak256(photoBytes || latE7 || lngE7 || timestamp || claimant)
        int64 latE7;           // latitude  * 1e7 (e.g. 6.4550123 -> 64550123)
        int64 lngE7;           // longitude * 1e7
        uint64 timestamp;      // block timestamp at claim time
        string note;           // free text, e.g. "Plot 14, Palm Garden City, Enugu"
    }

    // ---------------------------------------------------------------
    // Storage
    // ---------------------------------------------------------------

    /// @dev geohash cell id (ASCII geohash right-padded into bytes32) => claims
    mapping(bytes32 => Claim[]) private _claimsByCell;

    /// @dev total number of claims ever staked (for stats / UI)
    uint256 public totalClaims;

    /// @dev max note length to keep storage costs and spam bounded
    uint256 public constant MAX_NOTE_BYTES = 160;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    event ClaimStaked(
        bytes32 indexed cell,
        address indexed claimant,
        bytes32 evidenceHash,
        int64 latE7,
        int64 lngE7,
        uint64 timestamp,
        uint256 indexInCell
    );

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error EmptyCell();
    error EmptyEvidenceHash();
    error NoteTooLong();
    error InvalidCoordinates();

    // ---------------------------------------------------------------
    // Write
    // ---------------------------------------------------------------

    /// @notice Stake a claim on a geohash cell.
    /// @param cell         Geohash cell id (see geocell.dart for encoding).
    /// @param evidenceHash keccak256 hash of the evidence bundle.
    /// @param latE7        Latitude * 1e7.
    /// @param lngE7        Longitude * 1e7.
    /// @param note         Short human-readable label for the plot.
    function stakeClaim(
        bytes32 cell,
        bytes32 evidenceHash,
        int64 latE7,
        int64 lngE7,
        string calldata note
    ) external {
        if (cell == bytes32(0)) revert EmptyCell();
        if (evidenceHash == bytes32(0)) revert EmptyEvidenceHash();
        if (bytes(note).length > MAX_NOTE_BYTES) revert NoteTooLong();
        // lat in [-90, 90], lng in [-180, 180] (scaled by 1e7)
        if (
            latE7 < -900_000_000 || latE7 > 900_000_000 ||
            lngE7 < -1_800_000_000 || lngE7 > 1_800_000_000
        ) revert InvalidCoordinates();

        uint64 ts = uint64(block.timestamp);

        _claimsByCell[cell].push(
            Claim({
                claimant: msg.sender,
                evidenceHash: evidenceHash,
                latE7: latE7,
                lngE7: lngE7,
                timestamp: ts,
                note: note
            })
        );

        unchecked {
            totalClaims++;
        }

        emit ClaimStaked(
            cell,
            msg.sender,
            evidenceHash,
            latE7,
            lngE7,
            ts,
            _claimsByCell[cell].length - 1
        );
    }

    // ---------------------------------------------------------------
    // Read
    // ---------------------------------------------------------------

    /// @notice All claims staked on a single cell.
    function getClaims(bytes32 cell) external view returns (Claim[] memory) {
        return _claimsByCell[cell];
    }

    /// @notice Number of claims on a single cell (cheap conflict check).
    function claimCount(bytes32 cell) external view returns (uint256) {
        return _claimsByCell[cell].length;
    }

    /// @notice Batch conflict check: claim counts for a cell and its
    ///         neighbours in one RPC round trip. Pass the 9-cell block
    ///         (center + 8 neighbours) computed client-side.
    function claimCounts(bytes32[] calldata cells)
        external
        view
        returns (uint256[] memory counts)
    {
        counts = new uint256[](cells.length);
        for (uint256 i = 0; i < cells.length; i++) {
            counts[i] = _claimsByCell[cells[i]].length;
        }
    }

    /// @notice Batch fetch: all claims across a set of cells, flattened.
    ///         Used by the "Check plot" screen to show conflicts across
    ///         a cell and its 8 neighbours in one call.
    function getClaimsBatch(bytes32[] calldata cells)
        external
        view
        returns (bytes32[] memory cellOf, Claim[] memory claims)
    {
        uint256 total;
        for (uint256 i = 0; i < cells.length; i++) {
            total += _claimsByCell[cells[i]].length;
        }

        cellOf = new bytes32[](total);
        claims = new Claim[](total);

        uint256 k;
        for (uint256 i = 0; i < cells.length; i++) {
            Claim[] storage arr = _claimsByCell[cells[i]];
            for (uint256 j = 0; j < arr.length; j++) {
                cellOf[k] = cells[i];
                claims[k] = arr[j];
                unchecked {
                    k++;
                }
            }
        }
    }

    /// @notice Check whether a specific evidence hash exists on a cell.
    ///         Used by the "Verify evidence" screen.
    function hasEvidence(bytes32 cell, bytes32 evidenceHash)
        external
        view
        returns (bool found, uint256 index)
    {
        Claim[] storage arr = _claimsByCell[cell];
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i].evidenceHash == evidenceHash) {
                return (true, i);
            }
        }
        return (false, 0);
    }
}
