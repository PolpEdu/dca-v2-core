// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.7 <0.9.0;

import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '../interfaces/ITimeWeightedOracle.sol';
import './DCAHubParameters.sol';

abstract contract DCAHubConfigHandler is DCAHubParameters, AccessControl, Pausable, IDCAHubConfigHandler {
  bytes32 public constant IMMEDIATE_ROLE = keccak256('IMMEDIATE_ROLE');
  bytes32 public constant TIME_LOCKED_ROLE = keccak256('TIME_LOCKED_ROLE');
  bytes32 public constant PLATFORM_WITHDRAW_ROLE = keccak256('PLATFORM_WITHDRAW_ROLE');
  ITimeWeightedOracle public oracle;
  uint32 public swapFee = 6000; // 0.6%
  uint32 public loanFee = 1000; // 0.1%
  uint32 public constant MAX_FEE = 10 * FEE_PRECISION; // 10%
  bytes1 public allowedSwapIntervals = 0xF0; // Start allowing weekly, daily, every 4 hours, hourly

  constructor(
    address _immediateGovernor,
    address _timeLockedGovernor,
    ITimeWeightedOracle _oracle
  ) {
    if (_immediateGovernor == address(0) || _timeLockedGovernor == address(0) || address(_oracle) == address(0)) revert IDCAHub.ZeroAddress();
    _setupRole(IMMEDIATE_ROLE, _immediateGovernor);
    _setupRole(TIME_LOCKED_ROLE, _timeLockedGovernor);
    _setRoleAdmin(PLATFORM_WITHDRAW_ROLE, TIME_LOCKED_ROLE);
    // We set each role as its own admin, so they can assign new addresses with the same role
    _setRoleAdmin(IMMEDIATE_ROLE, IMMEDIATE_ROLE);
    _setRoleAdmin(TIME_LOCKED_ROLE, TIME_LOCKED_ROLE);
    oracle = _oracle;
  }

  function setOracle(ITimeWeightedOracle _oracle) external onlyRole(TIME_LOCKED_ROLE) {
    if (address(_oracle) == address(0)) revert IDCAHub.ZeroAddress();
    oracle = _oracle;
    emit OracleSet(_oracle);
  }

  function setSwapFee(uint32 _swapFee) external onlyRole(TIME_LOCKED_ROLE) {
    if (_swapFee > MAX_FEE) revert HighFee();
    if (_swapFee % 100 != 0) revert InvalidFee();
    swapFee = _swapFee;
    emit SwapFeeSet(_swapFee);
  }

  function setLoanFee(uint32 _loanFee) external onlyRole(TIME_LOCKED_ROLE) {
    if (_loanFee > MAX_FEE) revert HighFee();
    if (_loanFee % 100 != 0) revert InvalidFee();
    loanFee = _loanFee;
    emit LoanFeeSet(_loanFee);
  }

  function addSwapIntervalsToAllowedList(uint32[] calldata _swapIntervals) external onlyRole(IMMEDIATE_ROLE) {
    for (uint256 i; i < _swapIntervals.length; i++) {
      allowedSwapIntervals |= intervalToMask(_swapIntervals[i]);
    }
    emit SwapIntervalsAllowed(_swapIntervals);
  }

  function removeSwapIntervalsFromAllowedList(uint32[] calldata _swapIntervals) external onlyRole(IMMEDIATE_ROLE) {
    for (uint256 i; i < _swapIntervals.length; i++) {
      allowedSwapIntervals &= ~intervalToMask(_swapIntervals[i]);
    }
    emit SwapIntervalsForbidden(_swapIntervals);
  }

  function pause() external onlyRole(IMMEDIATE_ROLE) {
    _pause();
  }

  function unpause() external onlyRole(IMMEDIATE_ROLE) {
    _unpause();
  }

  function paused() public view override(IDCAHubConfigHandler, Pausable) returns (bool) {
    return super.paused();
  }
}
