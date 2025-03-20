//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { Policy } from "./Types.sol";
import { IERC4626Custom } from "./IERC4626Custom.sol";
import { IERC20Full } from "./IERC20Full.sol";

interface IShMonad is IERC4626Custom, IERC20Full {
    // --------------------------------------------- //
    //             Extra ERC4626 Functions           //
    // --------------------------------------------- //

    function boostYield() external payable;

    function boostYield(uint256 amount, address from) external;

    // --------------------------------------------- //
    //                Account Functions              //
    // --------------------------------------------- //

    function bond(uint64 policyID, address bondRecipient, uint256 amount) external;

    function depositAndBond(uint64 policyID, address bondRecipient, uint256 amountToBond) external payable;

    function unbond(uint64 policyID, uint256 amount, uint256 newMinBalance) external returns (uint256 unbondBlock);

    function unbondWithTask(
        uint64 policyID,
        uint256 amount,
        uint256 newMinBalance
    )
        external
        payable
        returns (uint256 unbondBlock);

    function claim(uint64 policyID, uint256 amount) external;

    function claimAndWithdraw(uint64 policyID, uint256 amount) external returns (uint256 shares);

    function claimAndRebond(uint64 fromPolicyID, uint64 toPolicyID, address bondRecipient, uint256 amount) external;

    function claimAsTask(uint64 policyID, uint256 amount, address account) external;

    // --------------------------------------------- //
    //                 Agent Functions               //
    // --------------------------------------------- //

    function hold(uint64 policyID, address account, uint256 amount) external;

    function release(uint64 policyID, address account, uint256 amount) external;

    function batchHold(uint64 policyID, address[] calldata accounts, uint256[] memory amounts) external;

    function batchRelease(uint64 policyID, address[] calldata accounts, uint256[] calldata amounts) external;

    function agentTransferFromBonded(
        uint64 policyID,
        address from,
        address to,
        uint256 amount,
        uint256 fromReleaseAmount,
        bool inUnderlying
    )
        external;

    function agentTransferToUnbonded(
        uint64 policyID,
        address from,
        address to,
        uint256 amount,
        uint256 fromReleaseAmount,
        bool inUnderlying
    )
        external;

    function agentWithdrawFromBonded(
        uint64 policyID,
        address from,
        address to,
        uint256 amount,
        uint256 fromReleaseAmount,
        bool inUnderlying
    )
        external;

    function agentBoostYieldFromBonded(
        uint64 policyID,
        address from,
        uint256 amount,
        uint256 fromReleaseAmount,
        bool inUnderlying
    )
        external;

    function agentExecuteWithSponsor(
        uint64 policyID,
        address payor,
        address recipient,
        uint256 msgValue,
        uint256 gasLimit,
        address callTarget,
        bytes calldata callData
    )
        external
        payable
        returns (uint128 actualPayorCost, bool success, bytes memory returnData);

    // --------------------------------------------- //
    //           Top-Up Management Functions         //
    // --------------------------------------------- //

    function setMinBondedBalance(
        uint64 policyID,
        uint128 minBonded,
        uint128 maxTopUpPerPeriod,
        uint32 topUpPeriodDuration
    )
        external;

    // --------------------------------------------- //
    //           Policy Management Functions         //
    // --------------------------------------------- //

    function createPolicy(uint48 escrowDuration) external returns (uint64 policyID, address policyERC20Wrapper);

    function addPolicyAgent(uint64 policyID, address agent) external;

    function removePolicyAgent(uint64 policyID, address agent) external;

    function disablePolicy(uint64 policyID) external;

    // --------------------------------------------- //
    //                 View Functions                //
    // --------------------------------------------- //

    function policyCount() external view returns (uint64);

    function getPolicy(uint64 policyID) external view returns (Policy memory);

    function isPolicyAgent(uint64 policyID, address agent) external view returns (bool);

    function getPolicyAgents(uint64 policyID) external view returns (address[] memory);

    function getHoldAmount(uint64 policyID, address account) external view returns (uint256);

    function unbondingCompleteBlock(uint64 policyID, address account) external view returns (uint256);

    function balanceOfBonded(uint64 policyID, address account) external view returns (uint256);

    function balanceOfUnbonding(uint64 policyID, address account) external view returns (uint256);
}
