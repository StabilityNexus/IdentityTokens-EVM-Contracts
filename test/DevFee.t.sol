// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Test } from "forge-std/Test.sol";
import { IdentitySystem } from "../src/IdentitySystem.sol";
import { ProfileSystem } from "../src/ProfileSystem.sol";
import { DataTypes } from "../src/libraries/DataTypes.sol";
import { Errors } from "../src/libraries/Errors.sol";
import { Events } from "../src/libraries/Events.sol";

// A receiver with no receive/fallback, so any ETH sent to it reverts
contract RejectsEther {}

contract DevFeeTest is Test {
    IdentitySystem public identitySystem;
    ProfileSystem public profileSystem;

    uint256 public constant DEV_FEE = 100;
    uint256 public constant DONATION = 0.0001 ether;

    address public dev = makeAddr("dev");
    address public receiver = makeAddr("receiver");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    function setUp() public {
        identitySystem = new IdentitySystem(dev, receiver, DEV_FEE);
        profileSystem = new ProfileSystem(address(identitySystem));
        identitySystem.setProfileSystem(address(profileSystem));

        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
        vm.deal(charlie, 1 ether);
    }

    function _meta(string memory username) internal pure returns (DataTypes.ProfileMetadata memory) {
        return
            DataTypes.ProfileMetadata({
                name: username,
                username: username,
                nationality: "",
                github: "",
                email: "",
                discord: "",
                xDotCom: "",
                websitePortfolioLink: "",
                ens: "",
                avatarId: ""
            });
    }

    function _noLinks() internal pure returns (DataTypes.LinkUpdate[] memory) {
        return new DataTypes.LinkUpdate[](0);
    }

    function _noFields() internal pure returns (DataTypes.FieldUpdate[] memory) {
        return new DataTypes.FieldUpdate[](0);
    }

    // One donation on each contract
    function _collectDonations() internal returns (uint256 total) {
        vm.prank(alice);
        identitySystem.createRootIdentity{ value: DONATION }("alice");
        vm.prank(alice);
        profileSystem.createProfile{ value: 2 * DONATION }(_meta("alice"), _noLinks());
        return 3 * DONATION;
    }

    // =========================================================================
    // Constructor
    // =========================================================================

    function test_Constructor_SetsDevFeeConfig() public view {
        assertEq(identitySystem.dev(), dev);
        assertEq(identitySystem.pendingDev(), address(0));
        assertEq(identitySystem.devFeeReceiver(), receiver);
        assertEq(identitySystem.devFee(), DEV_FEE);
    }

    function test_RevertIf_Constructor_ZeroDev() public {
        vm.expectRevert(Errors.ZeroAddress.selector);
        new IdentitySystem(address(0), receiver, DEV_FEE);
    }

    function test_RevertIf_Constructor_ZeroReceiver() public {
        vm.expectRevert(Errors.ZeroAddress.selector);
        new IdentitySystem(dev, address(0), DEV_FEE);
    }

    function test_RevertIf_Constructor_FeeAboveMax() public {
        uint256 tooHigh = identitySystem.MAX_DEV_FEE() + 1;
        vm.expectRevert(Errors.DevFeeTooHigh.selector);
        new IdentitySystem(dev, receiver, tooHigh);
    }

    // =========================================================================
    // Donating
    // =========================================================================

    function test_PaidActions_CollectDonations() public {
        vm.prank(alice);
        identitySystem.createRootIdentity{ value: DONATION }("alice");
        vm.prank(bob);
        identitySystem.createRootIdentity{ value: DONATION }("bob");

        vm.prank(alice);
        uint256 profileId = profileSystem.createProfile{ value: DONATION }(_meta("alice"), _noLinks());
        vm.prank(alice);
        profileSystem.updateProfile{ value: DONATION }(profileId, _noFields(), _noLinks());

        vm.prank(alice);
        uint256 tokenId = identitySystem.createToken{ value: DONATION }("Degree", "education", "", "", 0);
        vm.prank(bob);
        identitySystem.attestToken{ value: DONATION }(tokenId, 30 days);
        vm.prank(bob);
        identitySystem.flagToken{ value: DONATION }(tokenId);
        vm.prank(bob);
        identitySystem.revokeAttestation{ value: DONATION }(tokenId);

        vm.prank(alice);
        identitySystem.transferToken{ value: DONATION }(tokenId, charlie);
        vm.prank(charlie);
        identitySystem.burnToken{ value: DONATION }(tokenId);

        assertEq(address(identitySystem).balance, 8 * DONATION);
        assertEq(address(profileSystem).balance, 2 * DONATION);
    }

    function test_PaidActions_WithoutDonation() public {
        vm.prank(alice);
        identitySystem.createRootIdentity("alice");
        vm.prank(alice);
        profileSystem.createProfile(_meta("alice"), _noLinks());

        assertEq(address(identitySystem).balance, 0);
        assertEq(address(profileSystem).balance, 0);
    }

    // The donation follows the gas fee, so the contract takes any amount
    function test_Fuzz_AnyDonationAccepted(uint96 value) public {
        vm.deal(alice, value);
        vm.prank(alice);
        identitySystem.createRootIdentity{ value: value }("alice");
        assertEq(address(identitySystem).balance, value);
    }

    // =========================================================================
    // Withdrawing
    // =========================================================================

    function test_WithdrawDevFees_SweepsBothContracts() public {
        uint256 total = _collectDonations();

        vm.expectEmit(true, false, false, true, address(identitySystem));
        emit Events.DevFeesWithdrawn(receiver, total);
        vm.prank(dev);
        identitySystem.withdrawDevFees();

        assertEq(receiver.balance, total);
        assertEq(address(identitySystem).balance, 0);
        assertEq(address(profileSystem).balance, 0);
    }

    function test_WithdrawDevFees_NothingInProfileSystem() public {
        vm.prank(alice);
        identitySystem.createRootIdentity{ value: DONATION }("alice");

        vm.prank(dev);
        identitySystem.withdrawDevFees();

        assertEq(receiver.balance, DONATION);
        assertEq(address(identitySystem).balance, 0);
    }

    function test_RevertIf_WithdrawDevFees_NotDev() public {
        _collectDonations();

        vm.expectRevert(Errors.NotDev.selector);
        vm.prank(alice);
        identitySystem.withdrawDevFees();
    }

    function test_RevertIf_WithdrawDevFees_ReceiverRejects() public {
        _collectDonations();
        address rejecter = address(new RejectsEther());
        vm.prank(dev);
        identitySystem.setDevFeeReceiver(rejecter);

        vm.expectRevert(Errors.DevFeeTransferFailed.selector);
        vm.prank(dev);
        identitySystem.withdrawDevFees();
    }

    function test_RevertIf_SweepDevFees_NotIdentitySystem() public {
        _collectDonations();

        vm.expectRevert(Errors.OnlyIdentitySystem.selector);
        vm.prank(dev);
        profileSystem.sweepDevFees(dev);
    }

    // =========================================================================
    // Settings
    // =========================================================================

    function test_SetDevFee() public {
        uint256 newFee = identitySystem.MAX_DEV_FEE();
        vm.expectEmit(false, false, false, true, address(identitySystem));
        emit Events.DevFeeSet(newFee);
        vm.prank(dev);
        identitySystem.setDevFee(newFee);

        assertEq(identitySystem.devFee(), newFee);
    }

    function test_RevertIf_SetDevFee_AboveMax() public {
        uint256 tooHigh = identitySystem.MAX_DEV_FEE() + 1;
        vm.expectRevert(Errors.DevFeeTooHigh.selector);
        vm.prank(dev);
        identitySystem.setDevFee(tooHigh);
    }

    function test_RevertIf_SetDevFee_NotDev() public {
        vm.expectRevert(Errors.NotDev.selector);
        vm.prank(alice);
        identitySystem.setDevFee(1);
    }

    function test_SetDevFeeReceiver() public {
        vm.expectEmit(true, false, false, false, address(identitySystem));
        emit Events.DevFeeReceiverSet(bob);
        vm.prank(dev);
        identitySystem.setDevFeeReceiver(bob);

        assertEq(identitySystem.devFeeReceiver(), bob);
    }

    function test_RevertIf_SetDevFeeReceiver_ZeroAddress() public {
        vm.expectRevert(Errors.ZeroAddress.selector);
        vm.prank(dev);
        identitySystem.setDevFeeReceiver(address(0));
    }

    function test_RevertIf_SetDevFeeReceiver_NotDev() public {
        vm.expectRevert(Errors.NotDev.selector);
        vm.prank(alice);
        identitySystem.setDevFeeReceiver(alice);
    }

    // =========================================================================
    // Handing over the dev role
    // =========================================================================

    function test_ProposeAndAcceptDev() public {
        uint256 total = _collectDonations();

        vm.expectEmit(true, true, false, false, address(identitySystem));
        emit Events.DevTransferProposed(dev, bob);
        vm.prank(dev);
        identitySystem.proposeDev(bob);

        // Still the old dev until the new one accepts
        assertEq(identitySystem.dev(), dev);
        assertEq(identitySystem.pendingDev(), bob);

        vm.expectEmit(true, true, false, false, address(identitySystem));
        emit Events.DevTransferred(dev, bob);
        vm.prank(bob);
        identitySystem.acceptDev();

        assertEq(identitySystem.dev(), bob);
        assertEq(identitySystem.pendingDev(), address(0));

        vm.expectRevert(Errors.NotDev.selector);
        vm.prank(dev);
        identitySystem.setDevFee(0);

        // One handover covers ProfileSystem's donations too
        vm.prank(bob);
        identitySystem.withdrawDevFees();
        assertEq(receiver.balance, total);
    }

    function test_ProposeDev_ZeroCancels() public {
        vm.prank(dev);
        identitySystem.proposeDev(bob);
        vm.prank(dev);
        identitySystem.proposeDev(address(0));

        vm.expectRevert(Errors.NotPendingDev.selector);
        vm.prank(bob);
        identitySystem.acceptDev();
    }

    function test_RevertIf_ProposeDev_NotDev() public {
        vm.expectRevert(Errors.NotDev.selector);
        vm.prank(alice);
        identitySystem.proposeDev(alice);
    }

    function test_RevertIf_AcceptDev_NotPendingDev() public {
        vm.prank(dev);
        identitySystem.proposeDev(bob);

        vm.expectRevert(Errors.NotPendingDev.selector);
        vm.prank(alice);
        identitySystem.acceptDev();
    }
}
