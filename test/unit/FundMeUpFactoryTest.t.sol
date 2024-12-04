// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {FundMeUpFactory} from "../../src/FundMeUpFactory.sol";

contract FundMeUpFactoryTest is Test {
    FundMeUpFactory fundMeUpFactory;
    address factoryOwner = makeAddr("factoryOwner");
    address campaignOwner1 = makeAddr("campaignOwner1");

    event CampaignCreated(
        address indexed owner,
        string name,
        uint256 indexed fundingGoal
    );

    function setUp() external {
        vm.prank(factoryOwner);
        vm.deal(factoryOwner, 10 ether);
        vm.deal(campaignOwner1, 1 ether);
        fundMeUpFactory = new FundMeUpFactory();
    }

    function test_factoryOwnerIsCorrect() external view {
        assertEq(fundMeUpFactory.owner(), factoryOwner);
    }

    function test_CreateNewCampaign() external {
        string memory campaignName = "My Campaign";
        string memory campaignDescription = "This is my campaign";
        uint256 fundingGoal = 1 ether;
        uint256 duration = 1 days;

        vm.prank(campaignOwner1);
        fundMeUpFactory.createNewCampaign(
            campaignName,
            campaignDescription,
            fundingGoal,
            duration
        );

        FundMeUpFactory.Campaign[] memory campaigns = fundMeUpFactory
            .getAllCampaigns();

        assertEq(campaigns.length, 1);
        FundMeUpFactory.Campaign[] memory userCampaigns = fundMeUpFactory
            .getUserCampaigns(campaignOwner1);
        assertEq(userCampaigns.length, 1);
        assertEq(userCampaigns[0].name, campaignName);
        assertEq(userCampaigns[0].owner, campaignOwner1);
    }

    function test_CannotCreateNewCampaignWhenContractIsPaused() external {
        vm.prank(factoryOwner);
        fundMeUpFactory.togglePause();

        string memory campaignName = "My Campaign";
        string memory campaignDescription = "This is my campaign";
        uint256 fundingGoal = 1 ether;
        uint256 duration = 1 days;

        vm.prank(campaignOwner1);
        vm.expectRevert();
        fundMeUpFactory.createNewCampaign(
            campaignName,
            campaignDescription,
            fundingGoal,
            duration
        );
    }

    function test_CreatingNewCampaignEmitsEvent() external {
        string memory campaignName = "My Campaign";
        string memory campaignDescription = "This is my campaign";
        uint256 fundingGoal = 1 ether;
        uint256 duration = 1 days;

        vm.expectEmit(true, true, true, false);
        emit CampaignCreated(campaignOwner1, campaignName, fundingGoal);

        vm.prank(campaignOwner1);
        fundMeUpFactory.createNewCampaign(
            campaignName,
            campaignDescription,
            fundingGoal,
            duration
        );
    }

    function test_OnlyOwnerCanTogglePause() external {
        vm.prank(factoryOwner);
        fundMeUpFactory.togglePause();

        bool isPaused = fundMeUpFactory.paused();
        assertEq(isPaused, true);

        vm.prank(campaignOwner1);
        vm.expectRevert();
        fundMeUpFactory.togglePause();
    }
}
