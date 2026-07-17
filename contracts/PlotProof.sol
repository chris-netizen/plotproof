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

    /// @dev current owner of a claim (cell => index => owner). address(0)
    ///      means "never transferred" — the effective owner is the original
    ///      claimant stored in the Claim. This keeps the Claim struct (and so
    ///      the evidence hash, which commits to the original claimant) intact.
    mapping(bytes32 => mapping(uint256 => address)) private _owner;

    /// @dev number of times a claim has changed hands (cell => index => count)
    mapping(bytes32 => mapping(uint256 => uint32)) private _transfers;

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

    /// @notice Emitted when a claim's ownership is handed to a new address
    ///         (e.g. the plot is sold). Forms the on-chain chain of custody.
    event ClaimTransferred(
        bytes32 indexed cell,
        uint256 indexed indexInCell,
        address indexed from,
        address to,
        uint64 timestamp,
        uint32 transferCount
    );

    // ---------------------------------------------------------------
    // Errors
    // ---------------------------------------------------------------

    error EmptyCell();
    error EmptyEvidenceHash();
    error NoteTooLong();
    error InvalidCoordinates();
    error ClaimIndexOutOfRange();
    error NotClaimOwner();
    error InvalidRecipient();

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

    /// @notice Transfer ownership of a claim to a new address — e.g. when the
    ///         plot is sold. Only the current owner may transfer. This records
    ///         a verifiable chain of custody, so a legitimate sale becomes a
    ///         linked A -> B trail rather than looking like a double sale.
    /// @param cell   The claim's geohash cell.
    /// @param index  The claim's index within the cell (see getClaimsBatch).
    /// @param to     The new owner (e.g. the buyer's wallet).
    function transferClaim(bytes32 cell, uint256 index, address to) external {
        Claim[] storage arr = _claimsByCell[cell];
        if (index >= arr.length) revert ClaimIndexOutOfRange();

        address current = _owner[cell][index];
        if (current == address(0)) current = arr[index].claimant;

        if (current != msg.sender) revert NotClaimOwner();
        if (to == address(0) || to == current) revert InvalidRecipient();

        _owner[cell][index] = to;
        uint32 count;
        unchecked {
            count = ++_transfers[cell][index];
        }

        emit ClaimTransferred(cell, index, current, to, uint64(block.timestamp), count);
    }

    // ---------------------------------------------------------------
    // Read
    // ---------------------------------------------------------------

    /// @notice All claims staked on a single cell.
    function getClaims(bytes32 cell) external view returns (Claim[] memory) {
        return _claimsByCell[cell];
    }

    /// @notice Current owner of a claim (the original claimant unless the
    ///         claim has been transferred).
    function ownerOf(bytes32 cell, uint256 index) public view returns (address) {
        Claim[] storage arr = _claimsByCell[cell];
        if (index >= arr.length) revert ClaimIndexOutOfRange();
        address o = _owner[cell][index];
        return o == address(0) ? arr[index].claimant : o;
    }

    /// @notice How many times a claim has changed hands.
    function transferCountOf(bytes32 cell, uint256 index)
        external
        view
        returns (uint32)
    {
        return _transfers[cell][index];
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
        returns (
            bytes32[] memory cellOf,
            uint256[] memory idxOf,
            address[] memory ownerOf_,
            Claim[] memory claims
        )
    {
        uint256 total;
        for (uint256 i = 0; i < cells.length; i++) {
            total += _claimsByCell[cells[i]].length;
        }

        cellOf = new bytes32[](total);
        idxOf = new uint256[](total);
        ownerOf_ = new address[](total);
        claims = new Claim[](total);

        uint256 k;
        for (uint256 i = 0; i < cells.length; i++) {
            bytes32 cell = cells[i];
            Claim[] storage arr = _claimsByCell[cell];
            for (uint256 j = 0; j < arr.length; j++) {
                cellOf[k] = cell;
                idxOf[k] = j;
                address o = _owner[cell][j];
                ownerOf_[k] = o == address(0) ? arr[j].claimant : o;
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
