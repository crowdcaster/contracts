// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

struct CampaignData {
  uint256 totalContributions;
  uint256 goalAmount;
  uint256 deadline;
  uint256 minimumDonation;
  bool status;
  address beneficiary;
  address token;
  bytes name;
  bytes description;
  address[] contributors;
}

contract SimpleCampaign {
  address public constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  address public owner;
  mapping(uint256 id => mapping(address contributor => uint256 value)) public contributions;
  mapping(uint256 id => CampaignData campaign) public campaigns;
  uint256 public maxId = 0;

  event CampaignCreated(
    uint256 id,
    uint256 goalAmount,
    uint256 deadline,
    uint256 minimumDonation,
    address beneficiary,
    address token,
    bytes name,
    bytes description
  );

  event Contribution(uint256 id, address contributor, uint256 value);

  event CampaignSuccess(uint256 id, uint256 totalContributions);

  event CampaignFailed(uint256 id, uint256 totalContributions);

  error CampaignClosed(uint256 id);

  error MinimumDonationNotMet(uint256 id);

  error IncorrectValue();

  error CampaignStillOpen(uint256 id);

  constructor() {
    owner = msg.sender;
  }

  function createCampaign(
    uint256 goalAmount,
    uint256 duration,
    uint256 minimumDonation,
    address beneficiary,
    address token,
    bytes calldata name,
    bytes calldata description
  ) public {
    maxId++;
    //solhint-disable-next-line
    campaigns[maxId] = CampaignData(
      0,
      goalAmount,
      block.timestamp + duration,
      minimumDonation,
      true,
      beneficiary,
      token,
      name,
      description,
      new address[](0)
    );
    emit CampaignCreated(maxId, goalAmount, duration, minimumDonation, beneficiary, token, name, description);
  }

  function contribute(uint256 id, uint256 amount) public payable {
    if (block.timestamp >= campaigns[id].deadline) {
      revert CampaignClosed(id);
    }
    if (campaigns[id].status == false) {
      revert CampaignClosed(id);
    }
    if (amount < campaigns[id].minimumDonation) {
      revert MinimumDonationNotMet(id);
    }

    // require(contributions[id][msg.sender] + amount <= campaigns[id].goalAmount, "Contribution exceeds goal amount");

    if (campaigns[id].token != NATIVE_TOKEN) {
      IERC20(campaigns[id].token).transferFrom(msg.sender, address(this), amount);
    } else {
      if (msg.value != amount) {
        revert IncorrectValue();
      }
    }

    contributions[id][msg.sender] += amount;
    campaigns[id].totalContributions += amount;

    emit Contribution(id, msg.sender, amount);

    if (campaigns[id].totalContributions >= campaigns[id].goalAmount) {
      campaigns[id].status = false;
      emit CampaignSuccess(id, campaigns[id].totalContributions);

      if (campaigns[id].token != NATIVE_TOKEN) {
        IERC20(campaigns[id].token).transfer(campaigns[id].beneficiary, campaigns[id].totalContributions);
      } else {
        payable(campaigns[id].beneficiary).transfer(campaigns[id].totalContributions);
      }
    }
  }

  function returnFunds(uint256 id) public {
    if (block.timestamp <= campaigns[id].deadline) {
      revert CampaignStillOpen(id);
    }
    if (campaigns[id].status == false) {
      revert CampaignClosed(id);
    }

    campaigns[id].status = false;
    emit CampaignFailed(id, campaigns[id].totalContributions);

    if (campaigns[id].token != NATIVE_TOKEN) {
      for (uint256 i = 0; i < campaigns[id].contributors.length; i++) {
        IERC20(campaigns[id].token).transfer(
          campaigns[id].contributors[i], contributions[id][campaigns[id].contributors[i]]
        );
      }
    } else {
      for (uint256 i = 0; i < campaigns[id].contributors.length; i++) {
        payable(campaigns[id].contributors[i]).transfer(contributions[id][campaigns[id].contributors[i]]);
      }
    }
  }
}
