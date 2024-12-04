// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin-contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin-contracts/utils/Strings.sol";
import {Pausable} from "@openzeppelin-contracts/utils/Pausable.sol";

contract FundMeUp is Ownable, Pausable {
    /*==============================================================
                                ERRORS
    ==============================================================*/
    error FundMeUp_CannotBeZeroAddress();
    error FundMeUp_NameCannotBeEmpty();
    error FundMeUp_DescriptionCannotBeEmpty();
    error FundMeUp_FundingGoalMustBeGreaterThanZero();
    error FundMeUp_DurationMustBeAtleastForOneDay();
    error FundMeUp_CampaignIsNotActive();
    error FundMeUp_InvalidTier();
    error FundMeUp_InvalidAmount();
    error FundMeUp_AmountMustBeGreaterThanZero();
    error FundMeUp_CampaignNotSuccessful();
    error FundMeUp_NoBalanceToWithDraw();
    error FundMeUp_TransferFailed();
    error FundMeUp_RefundNotAvailable();
    error FundMeUp_NothingToRefund();

    /*==============================================================
                                TYPE DECLARATIONS
    ==============================================================*/
    using Strings for string;

    /*==============================================================
                            STATE VARIABLES
    ==============================================================*/
    string public s_campaignName;
    string public s_description;
    uint256 public s_fundingGoal;
    uint256 public s_deadline;

    enum CampaignStatus {
        ACTIVE,
        FAILED,
        FUNDED
    }
    CampaignStatus public s_currentCampaignStatus;

    struct Tier {
        string name;
        uint256 amount;
        uint256 patrons;
    }

    struct PatronInfo {
        uint256 totalDonation;
        mapping(uint256 => bool) fundedTiers;
    }

    Tier[] private s_tiers;
    mapping(address patron => PatronInfo) private s_patrons;

    /*==============================================================
                                EVENTS
    ==============================================================*/
    event Donated(address indexed patron, uint256 indexed tierIndex);
    event Refund(address indexed patron, uint256 indexed amount);
    event Withdrawn(uint256 amount);
    event TierAdded(uint256 tierIndex);
    event TierRemoved(uint256 tierIndex);

    /*==============================================================
                                MODIFIERS
    ==============================================================*/
    modifier isCampaignActive() {
        require(
            s_currentCampaignStatus == CampaignStatus.ACTIVE,
            FundMeUp_CampaignIsNotActive()
        );
        _;
    }

    /*==============================================================
                                FUNCTIONS
    ==============================================================*/

    constructor(
        address _owner,
        string calldata _campaignName,
        string calldata _description,
        uint256 _fundingGoal,
        uint256 _durationDays
    ) Ownable(_owner) {
        require(_owner != address(0), FundMeUp_CannotBeZeroAddress());
        require(!_campaignName.equal(""), FundMeUp_NameCannotBeEmpty());
        require(!_description.equal(""), FundMeUp_DescriptionCannotBeEmpty());
        require(_fundingGoal != 0, FundMeUp_FundingGoalMustBeGreaterThanZero());
        require(_durationDays > 0, FundMeUp_DurationMustBeAtleastForOneDay());
        s_campaignName = _campaignName;
        s_description = _description;
        s_currentCampaignStatus = CampaignStatus.ACTIVE;
        s_fundingGoal = _fundingGoal;
        s_deadline = block.timestamp + (_durationDays * 1 days);
    }

    /*----------- External Functions -----------*/
    function fund(
        uint256 _tierIndex
    ) external payable whenNotPaused isCampaignActive {
        syncCampaignStatus();
        require(_tierIndex < s_tiers.length, FundMeUp_InvalidTier());
        require(
            msg.value == s_tiers[_tierIndex].amount,
            FundMeUp_InvalidAmount()
        );

        bool hasAlreadyDonated = hasDonatedToTier(msg.sender, _tierIndex);
        if (!hasAlreadyDonated) {
            s_tiers[_tierIndex].patrons++;
            s_patrons[msg.sender].fundedTiers[_tierIndex] = true;
        }
        s_patrons[msg.sender].totalDonation += msg.value;

        emit Donated(msg.sender, _tierIndex);
        syncCampaignStatus();
    }

    function addTier(string calldata _name, uint256 _amount) external onlyOwner {
        require(_amount > 0, FundMeUp_AmountMustBeGreaterThanZero());
        s_tiers.push(Tier(_name, _amount, 0));
        emit TierAdded(s_tiers.length - 1);
    }

    function removeTier(uint256 _tierIndex) external onlyOwner {
        require(_tierIndex < s_tiers.length, FundMeUp_InvalidTier());
        for (uint256 i = _tierIndex; i < s_tiers.length - 1; i++) {
            s_tiers[i] = s_tiers[i + 1];
        }
        s_tiers.pop();

        emit TierRemoved(_tierIndex);
    }

    function withdraw() external onlyOwner {
        syncCampaignStatus();
        require(
            s_currentCampaignStatus == CampaignStatus.FUNDED,
            FundMeUp_CampaignNotSuccessful()
        );

        uint256 totalFund = address(this).balance;
        require(totalFund > 0, FundMeUp_NoBalanceToWithDraw());

        (bool success, ) = payable(owner()).call{value: totalFund}("");
        require(success, FundMeUp_TransferFailed());

        emit Withdrawn(totalFund);
    }

    function refund() external {
        syncCampaignStatus();
        require(
            s_currentCampaignStatus == CampaignStatus.FAILED,
            FundMeUp_RefundNotAvailable()
        );

        uint256 refundAmount = s_patrons[msg.sender].totalDonation;
        require(refundAmount > 0, FundMeUp_NothingToRefund());

        s_patrons[msg.sender].totalDonation = 0;
        (bool success, ) = payable(msg.sender).call{value: refundAmount}("");
        require(success, FundMeUp_TransferFailed());

        emit Refund(msg.sender, refundAmount);
    }

    function togglePause() external onlyOwner {
        if (paused()) {
            _unpause();
        } else {
            _pause();
        }
    }

    function extendDeadline(uint256 _days) external onlyOwner {
        syncCampaignStatus();
        require(
            s_currentCampaignStatus == CampaignStatus.ACTIVE,
            FundMeUp_CampaignIsNotActive()
        );
        s_deadline += _days * 1 days;
    }

    /*----------- Internal Functions -----------*/
    function syncCampaignStatus() internal {
        if (s_currentCampaignStatus == CampaignStatus.ACTIVE) {
            if (block.timestamp >= s_deadline) {
                s_currentCampaignStatus = address(this).balance >= s_fundingGoal
                    ? CampaignStatus.FUNDED
                    : CampaignStatus.FAILED;
            } else {
                s_currentCampaignStatus = address(this).balance >= s_fundingGoal
                    ? CampaignStatus.FUNDED
                    : CampaignStatus.ACTIVE;
            }
        }
    }

    /*----------- View/Pure Functions -----------*/

    function getTotalFundsRaised() public view returns (uint256 fundsRaised) {
        return address(this).balance;
    }

    function getTiers() public view returns (Tier[] memory) {
        return s_tiers;
    }

    function hasDonatedToTier(
        address _patron,
        uint256 _tierIndex
    ) public view returns (bool) {
        return s_patrons[_patron].fundedTiers[_tierIndex];
    }

    function getPatronTotalDonation(
        address _patron
    ) external view returns (uint256) {
        return s_patrons[_patron].totalDonation;
    }

    function getCampaignStatus() public view returns (CampaignStatus) {
        if (
            s_currentCampaignStatus == CampaignStatus.ACTIVE &&
            block.timestamp >= s_deadline
        ) {
            return
                address(this).balance >= s_fundingGoal
                    ? CampaignStatus.FUNDED
                    : CampaignStatus.FAILED;
        }
        return s_currentCampaignStatus;
    }
}
