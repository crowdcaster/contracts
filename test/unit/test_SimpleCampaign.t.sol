// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import 'forge-std/Test.sol';
import 'contracts/SimpleCampaign.sol';

contract SimpleCampaignTest is Test {
  SimpleCampaign campaign;
  address beneficiary;
  bytes sampleName = bytes('Save the Whales');
  bytes sampleDescription = bytes('A campaign to save whales.');
  address token = address(0x1); // Mock token address

  function setUp() public {
    campaign = new SimpleCampaign();
    beneficiary = address(new SimpleCampaign()); // Just a placeholder
    token = address(this); // Using this contract's address as a mock token
  }

  function testCreateCampaign() public {
    uint256 goalAmount = 100 ether;
    uint256 duration = 30 days;
    uint256 minimumDonation = 1 ether;
    campaign.createCampaign(goalAmount, duration, minimumDonation, beneficiary, token, sampleName, sampleDescription);
    // CampaignData memory data = campaign.campaigns(1);
    // assertEq(data.goalAmount, goalAmount);
    // assertEq(data.deadline, block.timestamp + duration);
    // assertEq(data.minimumDonation, minimumDonation);
    // assertEq(data.beneficiary, beneficiary);
    // assertEq(data.token, token);
    // assertTrue(data.status);
  }

  function testContribute() public {
    testCreateCampaign(); // First create a campaign
    vm.prank(address(0xABC));
    campaign.contribute{value: 10 ether}(1, 10 ether);
    assertEq(campaign.contributions(1, address(0xABC)), 10 ether);
    // assertEq(campaign.campaigns(1).totalContributions, 10 ether);
  }

  function testFailContributeAfterDeadline() public {
    testCreateCampaign(); // First create a campaign
    vm.warp(block.timestamp + 31 days); // Move time beyond the campaign deadline
    vm.prank(address(0xABC));
    campaign.contribute{value: 10 ether}(1, 10 ether);
  }

  function testFailContributeBelowMinimum() public {
    testCreateCampaign(); // First create a campaign
    vm.prank(address(0xABC));
    campaign.contribute{value: 0.5 ether}(1, 0.5 ether); // Below minimum donation amount
  }

  function testSuccessfulCampaign() public {
    testCreateCampaign(); // First create a campaign
    vm.prank(address(0xABC));
    campaign.contribute{value: 100 ether}(1, 100 ether); // Reach the goal exactly
      // assertFalse(campaign.campaigns(1).status); // Check if campaign is closed after reaching goal
  }

  function testFailReturnFundsWhileOpen() public {
    testCreateCampaign(); // First create a campaign
    vm.prank(address(0xABC));
    campaign.contribute{value: 10 ether}(1, 10 ether);
    campaign.returnFunds(1); // Should fail since campaign is still open
  }

  function testReturnFundsAfterFailure() public {
    testCreateCampaign(); // First create a campaign
    vm.warp(block.timestamp + 31 days); // Move time beyond the campaign deadline
    vm.prank(address(0xABC));
    campaign.contribute{value: 10 ether}(1, 10 ether); // Initial contribution
    campaign.returnFunds(1); // Attempt to return funds after campaign failed
    assertEq(address(0xABC).balance, 10 ether); // Check if funds are returned
  }

  receive() external payable {} // To allow receiving ETH for testing
}
