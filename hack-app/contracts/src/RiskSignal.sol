// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title RiskSignal
/// @notice On-chain oracle that stores a risk tier (Green/Amber/Red) updated by a CRE workflow.
/// @dev Tier, updatedAt, and confidence are packed into a single storage slot.
///      getEffectiveTier() applies staleness escalation: Green→Amber, Amber→Red if stale.
contract RiskSignal is Ownable {
    // ── Types ────────────────────────────────────────────────────────────
    enum Tier {
        Green, // 0 — normal
        Amber, // 1 — caution
        Red    // 2 — high risk
    }

    // ── Events ───────────────────────────────────────────────────────────
    event TierUpdated(Tier indexed tier, uint64 updatedAt, uint16 confidence);
    event UpdaterChanged(address indexed oldUpdater, address indexed newUpdater);
    event StaleWindowChanged(uint64 oldWindow, uint64 newWindow);

    // ── Errors ───────────────────────────────────────────────────────────
    error UnauthorizedUpdater();
    error InvalidTier(uint8 tier);
    error InvalidStaleWindow();

    // ── Storage (packed) ─────────────────────────────────────────────────
    Tier private _tier;
    uint64 private _updatedAt;
    uint16 private _confidence;

    address public updater;
    uint64 public staleWindow;

    // ── Constructor ──────────────────────────────────────────────────────
    /// @param _updater Address authorized to call setTier (CRE workflow EOA).
    /// @param _staleWindow Staleness threshold in seconds (e.g., 300 for 5 min).
    constructor(address _updater, uint64 _staleWindow) Ownable(msg.sender) {
        if (_staleWindow == 0) revert InvalidStaleWindow();
        updater = _updater;
        staleWindow = _staleWindow;
        emit UpdaterChanged(address(0), _updater);
        emit StaleWindowChanged(0, _staleWindow);
    }

    // ── Modifiers ────────────────────────────────────────────────────────
    modifier onlyUpdater() {
        if (msg.sender != updater) revert UnauthorizedUpdater();
        _;
    }

    // ── Write ────────────────────────────────────────────────────────────
    /// @notice Set the current risk tier. Only callable by the authorized updater.
    /// @param tier Risk tier (0 = Green, 1 = Amber, 2 = Red).
    /// @param confidence Confidence score in basis points (0–10000). Pass 0 if unavailable.
    function setTier(Tier tier, uint16 confidence) external onlyUpdater {
        if (uint8(tier) > uint8(Tier.Red)) revert InvalidTier(uint8(tier));
        _tier = tier;
        _updatedAt = uint64(block.timestamp);
        _confidence = confidence;
        emit TierUpdated(tier, uint64(block.timestamp), confidence);
    }

    /// @notice Change the authorized updater address. Only callable by the owner.
    /// @param newUpdater Address of the new updater (CRE workflow EOA).
    function setUpdater(address newUpdater) external onlyOwner {
        address oldUpdater = updater;
        updater = newUpdater;
        emit UpdaterChanged(oldUpdater, newUpdater);
    }

    /// @notice Change the staleness window. Only callable by the owner.
    /// @param newWindow New stale window in seconds.
    function setStaleWindow(uint64 newWindow) external onlyOwner {
        if (newWindow == 0) revert InvalidStaleWindow();
        uint64 oldWindow = staleWindow;
        staleWindow = newWindow;
        emit StaleWindowChanged(oldWindow, newWindow);
    }

    // ── Read ─────────────────────────────────────────────────────────────
    /// @notice Return the raw stored tier, timestamp, and confidence.
    /// @return tier Current risk tier.
    /// @return updatedAt Block timestamp of the last update.
    /// @return confidence Confidence in basis points (0–10000).
    function getTier() external view returns (Tier tier, uint64 updatedAt, uint16 confidence) {
        return (_tier, _updatedAt, _confidence);
    }

    /// @notice Return the effective tier after staleness escalation.
    /// @dev If block.timestamp - updatedAt > staleWindow:
    ///      Green → Amber, Amber → Red, Red → Red.
    /// @return tier Effective tier after staleness adjustment.
    /// @return isStale Whether the signal is currently stale.
    function getEffectiveTier() external view returns (Tier tier, bool isStale) {
        isStale = _updatedAt > 0 && (block.timestamp - _updatedAt > staleWindow);

        if (!isStale || _updatedAt == 0) {
            // Not stale (or never updated — treat stored value as-is)
            return (_tier, isStale);
        }

        // Staleness escalation
        if (_tier == Tier.Green) {
            return (Tier.Amber, true);
        }
        // Amber or Red both escalate to Red
        return (Tier.Red, true);
    }
}
