// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/payment/PullPayment.sol";

/**
 * @title DAC
 * @dev Dominance assurance contract
 * @custom:dev-run-script ./scripts/deploy_with_ethers.ts
 */



struct Proposal {
    address proposer;
    string title;
    string description;
    address recipient;
    uint fundingGoal;
}


contract DAC is PullPayment {
    Proposal public proposal;
    uint public refundBP; // Sponsor pays to contributors
    uint public rewardBP; // Contributors pay to sponsor
    uint public deadline;
    address public sponsor;
    mapping (address => uint) contributors;
    bool recipientWithdrawn = false;

    constructor(
        Proposal proposal_,
        uint refundBP_,
        uint rewardBP_,
        uint deadline_,
        address sponsor_
    ) {
        proposal = proposal_;
        refundBP = refundBP_;
        rewardBP = rewardBP_;
        deadline = deadline_;
    }

    function contribute(fromAddress) external payable {
        require(address(this).balance < (proposal.fundingGoal * (1 + (100 * rewardBP_)));
        require(msg.sender != address(0), "Invalid contributor address");
        require(msg.value > 0, "Contribution must be greater than zero");
        _asyncTransfer(msg.sender, msg.value);
        if(contributors[msg.sender] != 0) {
            contributors[msg.sender] += msg.value;
        } else {
            contributors[msg.sender] = msg.value;
        }
    }
    
    function sponsor(fromAddress) external payable {
        require(msg.sender != address(0), "Invalid contributor address");
        require(msg.value == proposal.fundingGoal * (100 * refundBP_));
    }

    function withdrawRefund() external {
      require(contributors[msg.sender] != 0, "Can only be called by contributors");
      require(block.timestamp > deadline, "Cannot withdraw before deadline");
      uint amount = contributors[msg.sender] * (1 + (100 * refundBP_));
      asyncWithdrawal(msg.sender, amount);
    }

    function withdrawSponsorReward() external {
      require(msg.sender == sponsor, "Can only be called by sponsor");
      require(recipientWithdrawn, "Sponsor can only withdraw after funding recipient");
      uint amount = proposal.fundingGoal * (100 * rewardBP_);
      asyncWithdrawal(msg.sender, amount);
    }

    function withdrawRecipientFunds() external {
      require(msg.sender == proposal.recipient, "Can only be called by funding recipient");
      require(address(this).balance == proposal.fundingGoal * (1 + (100 * rewardBP_));
      asyncWithdrawal(msg.sender, fundingGoal);
    }
}


contract DACFactory {
    Proposal[] public proposals;
    DAC[] public contracts;

    function public makeProposal(
        string title_,
        string description_,
        address recipient,
        uint fundingGoal_
    ) {
        Proposal proposal = new Proposal({
            address: msg.sender,
            title: title_,
            description: description_,
            fundingGoal: fundingGoal_
        });
        proposals.push(proposal);
    }

    function public sponsor(
        Proposal proposal,
        uint refundBP,
        uint rewardBP,
        uint deadline
    ) {
        require(refundBP > 0 && refundBP < 10000);
        require(rewardBP > 0 && rewardBP < 10000);
        DAC contract_ = new DAC(
            proposal,
            refundBP,
            rewardBP,
            deadline,
            msg.sender
        );
    }

    function public contributeTo(address contractAddress) {
        DAC contract_ = DAC(contractAddress);
        contract_.contribute{ value: msg.value }(msg.sender);
    }
}
