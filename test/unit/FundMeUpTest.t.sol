// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {FundMeUp} from "../../src/FundMeUp.sol";

contract FundMeUpTest is Test {
    FundMeUp fundMeUp;
    address fundMeUpOwner = makeAddr("fundMeUpOwner");
    address patron1 = makeAddr("patron1");
    address patron2 = makeAddr("patron2");
    address patron3 = makeAddr("patron3");
    address patron4 = makeAddr("patron4");

    string campaignName = "My Campaign";
    string campaignDescription = "This is my campaign";
    uint256 fundingGoal = 1 ether;
    uint256 duration = 1 days;
    string tierBronze = "bronze";
    uint256 bronzeAmount = 0.1 ether;
    string tierSilver = "silver";
    uint256 silverAmount = 0.3 ether;
    string tierGold = "gold";
    uint256 goldAmount = 0.5 ether;

    enum CampaignStatus {
        ACTIVE,
        FAILED,
        FUNDED
    }

    event Donated(address indexed patron, uint256 indexed tierIndex);
    event Refund(address indexed patron, uint256 indexed amount);
    event TierAdded(uint256 tierIndex);
    event TierRemoved(uint256 tierIndex);
    event Withdrawn(uint256 amount);

    function setUp() external {
        vm.deal(fundMeUpOwner, 1 ether);
        fundMeUp = new FundMeUp(
            fundMeUpOwner,
            campaignName,
            campaignDescription,
            fundingGoal,
            duration
        );

        vm.deal(patron1, 1 ether);
        vm.deal(patron2, 1 ether);
        vm.deal(patron3, 1 ether);
        vm.deal(patron4, 1 ether);
    }

    function test_Constructor() external view {
        assertEq(fundMeUp.owner(), fundMeUpOwner);
        assertEq(fundMeUp.s_description(), campaignDescription);
        assertEq(fundMeUp.s_fundingGoal(), fundingGoal);
    }

    function test_OnlyOwnerCanAddTier() external {
        vm.prank(fundMeUpOwner);
        fundMeUp.addTier(tierBronze, bronzeAmount);
        FundMeUp.Tier[] memory tiers = fundMeUp.getTiers();
        assertEq(tiers[0].name, "bronze");

        vm.prank(patron1);
        vm.expectRevert();
        fundMeUp.addTier(tierSilver, silverAmount);
    }

    function test_AddingTierEmitsEvent() external {
        vm.expectEmit(true, false, false, false);
        emit TierAdded(0);

        vm.prank(fundMeUpOwner);
        fundMeUp.addTier(tierBronze, bronzeAmount);
    }

    function test_OnlyOwnerCanRemoveTier() external {
        vm.startPrank(fundMeUpOwner);
        fundMeUp.addTier(tierBronze, bronzeAmount);
        fundMeUp.addTier(tierSilver, silverAmount);
        FundMeUp.Tier[] memory tiers = fundMeUp.getTiers();
        assertEq(tiers.length, 2);

        fundMeUp.removeTier(0);
        tiers = fundMeUp.getTiers();
        assertEq(tiers.length, 1);
        vm.stopPrank();

        vm.prank(patron1);
        vm.expectRevert();
        fundMeUp.removeTier(0);
        vm.stopPrank();
    }

    function test_RemovingTierEmitsEvent() external {
        vm.startPrank(fundMeUpOwner);
        fundMeUp.addTier(tierBronze, bronzeAmount);

        vm.expectEmit(true, false, false, false);
        emit TierRemoved(0);
        fundMeUp.removeTier(0);
    }

    function test_PatronsCannotFundWhenContractIsPaused() external {
        vm.startPrank(fundMeUpOwner);
        fundMeUp.addTier(tierBronze, bronzeAmount);
        fundMeUp.togglePause();
        vm.stopPrank();

        vm.prank(patron1);
        vm.expectRevert();
        fundMeUp.fund(0);
    }

    function test_PatronCanFundACampaign() external {
        vm.startPrank(fundMeUpOwner);
        fundMeUp.addTier(tierBronze, bronzeAmount);
        fundMeUp.addTier(tierSilver, silverAmount);
        vm.stopPrank();

        vm.prank(patron1);
        fundMeUp.fund{value: bronzeAmount}(0);

        FundMeUp.Tier[] memory tiers = fundMeUp.getTiers();
        assertEq(tiers[0].patrons, 1);

        bool hasDonated = fundMeUp.hasDonatedToTier(patron1, 0);
        assertTrue(hasDonated);

        uint256 patronTotalDonation = fundMeUp.getPatronTotalDonation(patron1);
        assertEq(patronTotalDonation, bronzeAmount);

        vm.prank(patron1);
        fundMeUp.fund{value: bronzeAmount}(0);

        tiers = fundMeUp.getTiers();
        assertEq(tiers[0].patrons, 1);

        patronTotalDonation = fundMeUp.getPatronTotalDonation(patron1);
        assertEq(patronTotalDonation, bronzeAmount * 2);
    }

    function test_MultiplePatronCanFundACampaign() external {
        vm.startPrank(fundMeUpOwner);
        fundMeUp.addTier(tierBronze, bronzeAmount);
        fundMeUp.addTier(tierSilver, silverAmount);
        fundMeUp.addTier(tierGold, goldAmount);
        vm.stopPrank();

        vm.prank(patron1);
        fundMeUp.fund{value: bronzeAmount}(0);

        vm.prank(patron2);
        fundMeUp.fund{value: silverAmount}(1);

        vm.prank(patron3);
        fundMeUp.fund{value: goldAmount}(2);

        FundMeUp.Tier[] memory tiers = fundMeUp.getTiers();
        assertEq(tiers[0].patrons, 1);
        assertEq(tiers[1].patrons, 1);
        assertEq(tiers[2].patrons, 1);

        bool hasPatron1Donated = fundMeUp.hasDonatedToTier(patron1, 0);
        bool hasPatron2Donated = fundMeUp.hasDonatedToTier(patron2, 1);
        bool hasPatron3Donated = fundMeUp.hasDonatedToTier(patron3, 2);
        assertTrue(hasPatron1Donated);
        assertTrue(hasPatron2Donated);
        assertTrue(hasPatron3Donated);

        uint256 patron1TotalDonation = fundMeUp.getPatronTotalDonation(patron1);
        uint256 patron2TotalDonation = fundMeUp.getPatronTotalDonation(patron2);
        uint256 patron3TotalDonation = fundMeUp.getPatronTotalDonation(patron3);
        assertEq(patron1TotalDonation, bronzeAmount);
        assertEq(patron2TotalDonation, silverAmount);
        assertEq(patron3TotalDonation, goldAmount);
    }

    function test_PatronsCannotFundCampaignOnceGoalIsReached() external {
        vm.startPrank(fundMeUpOwner);
        fundMeUp.addTier(tierBronze, bronzeAmount);
        fundMeUp.addTier(tierSilver, silverAmount);
        fundMeUp.addTier(tierGold, goldAmount);
        vm.stopPrank();

        vm.prank(patron1);
        fundMeUp.fund{value: bronzeAmount}(0);

        vm.prank(patron2);
        fundMeUp.fund{value: silverAmount}(1);

        vm.prank(patron3);
        fundMeUp.fund{value: goldAmount}(2);

        vm.prank(patron4);
        fundMeUp.fund{value: bronzeAmount}(0);

        vm.expectRevert(FundMeUp.FundMeUp_CampaignIsNotActive.selector);
        vm.prank(patron4);
        fundMeUp.fund{value: bronzeAmount}(0);
    }

    function test_fundingCampaignEmitsEvent() external {
        vm.prank(fundMeUpOwner);
        fundMeUp.addTier(tierBronze, bronzeAmount);

        vm.expectEmit(true, true, false, false);
        emit Donated(patron1, 0);

        vm.prank(patron1);
        fundMeUp.fund{value: bronzeAmount}(0);
    }

    function test_OwnerCanWithdrawIfCampaignIsSuccessful() external {
        vm.prank(fundMeUpOwner);
        fundMeUp.addTier(tierGold, goldAmount);

        vm.prank(patron1);
        fundMeUp.fund{value: goldAmount}(0);

        vm.prank(patron2);
        fundMeUp.fund{value: goldAmount}(0);

        FundMeUp.CampaignStatus status = fundMeUp.getCampaignStatus();
        assertEq(uint256(status), uint256(FundMeUp.CampaignStatus.FUNDED));

        vm.warp(fundMeUp.s_deadline());

        uint256 ownerInitialBalance = fundMeUpOwner.balance;
        vm.prank(fundMeUpOwner);
        fundMeUp.withdraw();

        assertEq(fundMeUp.getTotalFundsRaised(), 0);
        assertEq(fundMeUpOwner.balance, ownerInitialBalance + goldAmount * 2);
    }

    function test_CannotWithdrawOtherThanOwner() external {
        vm.prank(fundMeUpOwner);
        fundMeUp.addTier(tierGold, goldAmount);

        vm.prank(patron1);
        fundMeUp.fund{value: goldAmount}(0);

        vm.prank(patron2);
        fundMeUp.fund{value: goldAmount}(0);

        vm.warp(fundMeUp.s_deadline());
        vm.expectRevert();
        vm.prank(patron4);
        fundMeUp.withdraw();
    }

    function test_CannotWithdrawnIfCampaignFailed() external {
        vm.prank(fundMeUpOwner);
        fundMeUp.addTier(tierGold, goldAmount);

        vm.prank(patron1);
        fundMeUp.fund{value: goldAmount}(0);

        vm.warp(fundMeUp.s_deadline());
        vm.expectRevert(FundMeUp.FundMeUp_CampaignNotSuccessful.selector);
        vm.prank(fundMeUpOwner);
        fundMeUp.withdraw();
    }

    function test_CannotWithdrawnIfCampaignIsActive() external {
        vm.prank(fundMeUpOwner);
        fundMeUp.addTier(tierGold, goldAmount);

        vm.prank(patron1);
        fundMeUp.fund{value: goldAmount}(0);

        vm.expectRevert(FundMeUp.FundMeUp_CampaignNotSuccessful.selector);
        vm.prank(fundMeUpOwner);
        fundMeUp.withdraw();
    }

    function test_WithdrawEmitsEvent() external {
        vm.prank(fundMeUpOwner);
        fundMeUp.addTier(tierGold, goldAmount);

        vm.prank(patron1);
        fundMeUp.fund{value: goldAmount}(0);

        vm.prank(patron2);
        fundMeUp.fund{value: goldAmount}(0);

        vm.warp(fundMeUp.s_deadline());
        vm.expectEmit(true, false, false, false);
        emit Withdrawn(fundMeUp.getTotalFundsRaised());
        vm.prank(fundMeUpOwner);
        fundMeUp.withdraw();
    }

    function test_PatronsCanGetRefundIfCampaignFailedAndEmitsEvent() external {
        vm.prank(fundMeUpOwner);
        fundMeUp.addTier(tierGold, goldAmount);

        uint256 patronInitialBalance = patron1.balance;

        vm.prank(patron1);
        fundMeUp.fund{value: goldAmount}(0);

        vm.warp(fundMeUp.s_deadline());

        vm.expectEmit(true, true, false, false);
        emit Refund(patron1, goldAmount);
        vm.prank(patron1);
        fundMeUp.refund();
        assertEq(patronInitialBalance, patron1.balance);
    }

    function test_CannotRefundIfCampaignIsSuccessful() external {
        vm.prank(fundMeUpOwner);
        fundMeUp.addTier(tierGold, goldAmount);

        vm.prank(patron1);
        fundMeUp.fund{value: goldAmount}(0);

        vm.prank(patron2);
        fundMeUp.fund{value: goldAmount}(0);

        vm.warp(fundMeUp.s_deadline());

        vm.expectRevert(FundMeUp.FundMeUp_RefundNotAvailable.selector);
        vm.prank(patron1);
        fundMeUp.refund();
    }

    function test_CannotRefundIfCampaignIsActive() external {
        vm.prank(fundMeUpOwner);
        fundMeUp.addTier(tierGold, goldAmount);

        vm.prank(patron1);
        fundMeUp.fund{value: goldAmount}(0);

        vm.expectRevert(FundMeUp.FundMeUp_RefundNotAvailable.selector);
        vm.prank(patron1);
        fundMeUp.refund();
    }

    function test_CannotRefundIfNotDonated() external {
        vm.prank(fundMeUpOwner);
        fundMeUp.addTier(tierGold, goldAmount);

        vm.prank(patron1);
        fundMeUp.fund{value: goldAmount}(0);

        vm.warp(fundMeUp.s_deadline());

        vm.expectRevert(FundMeUp.FundMeUp_NothingToRefund.selector);
        vm.prank(patron2);
        fundMeUp.refund();
    }

    function test_OwnerCanExtendDeadline() external {
        uint256 initialDeadline = fundMeUp.s_deadline();

        vm.prank(fundMeUpOwner);
        fundMeUp.extendDeadline(2);

        uint256 currentDeadline = fundMeUp.s_deadline();
        assertEq(currentDeadline, initialDeadline + 2 days);
    }

    function test_OnlyOwnerCanExtendDeadline() external {
        vm.expectRevert();
        vm.prank(patron1);
        fundMeUp.extendDeadline(2);
    }

    function test_CannotExtendDeadlineIfCampaignIsSuccessful() external {
        vm.prank(fundMeUpOwner);
        fundMeUp.addTier(tierGold, goldAmount);

        vm.prank(patron1);
        fundMeUp.fund{value: goldAmount}(0);

        vm.prank(patron2);
        fundMeUp.fund{value: goldAmount}(0);

        vm.warp(fundMeUp.s_deadline());

        vm.expectRevert(FundMeUp.FundMeUp_CampaignIsNotActive.selector);
        vm.prank(fundMeUpOwner);
        fundMeUp.extendDeadline(2);
    }

    function test_CannotExtendDeadlineIfCampaignFailed() external {
        vm.prank(fundMeUpOwner);
        fundMeUp.addTier(tierGold, goldAmount);

        vm.prank(patron1);
        fundMeUp.fund{value: goldAmount}(0);

        vm.warp(fundMeUp.s_deadline());

        vm.expectRevert(FundMeUp.FundMeUp_CampaignIsNotActive.selector);
        vm.prank(fundMeUpOwner);
        fundMeUp.extendDeadline(2);
    }
}
