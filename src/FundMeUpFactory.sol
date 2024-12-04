// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {FundMeUp} from "./FundMeUp.sol";
import {Ownable} from "@openzeppelin-contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin-contracts/utils/Pausable.sol";

contract FundMeUpFactory is Ownable, Pausable {
    /*==============================================================
                            STATE VARIABLES
    ==============================================================*/
    struct Campaign {
        address campaignAddress;
        string name;
        address owner;
        uint256 creationTime;
    }
    Campaign[] private s_campaigns;
    mapping(address user => Campaign[]) private s_userCampaigns;

    /*==============================================================
                                EVENTS
    ==============================================================*/
    event CampaignCreated(
        address indexed owner,
        string name,
        uint256 indexed fundingGoal
    );

    /*==============================================================
                                FUNCTIONS
    ==============================================================*/
    constructor() Ownable(msg.sender) {}

    /*----------- External Functions -----------*/
    function createNewCampaign(
        string memory _campaignName,
        string memory _description,
        uint256 _fundingGoal,
        uint256 _durationDays
    ) external whenNotPaused {
        FundMeUp fundMeUp = new FundMeUp(
            msg.sender,
            _campaignName,
            _description,
            _fundingGoal,
            _durationDays
        );
        Campaign memory campaign = Campaign({
            campaignAddress: address(fundMeUp),
            name: _campaignName,
            owner: msg.sender,
            creationTime: block.timestamp
        });

        s_campaigns.push(campaign);
        s_userCampaigns[msg.sender].push(campaign);
        emit CampaignCreated(msg.sender, _campaignName, _fundingGoal);
    }

    function togglePause() external onlyOwner {
        if (paused()) {
            _unpause();
        } else {
            _pause();
        }
    }
    
    /*----------- View/Pure Functions -----------*/
    function getUserCampaigns(
        address _user
    ) external view returns (Campaign[] memory) {
        return s_userCampaigns[_user];
    }

    function getAllCampaigns() external view returns (Campaign[] memory) {
        return s_campaigns;
    }
}
