const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture, mine, time } = require("@nomicfoundation/hardhat-toolbox/network-helpers");


async function deployCrowdFundingFixture() {
    const [owner, addr1, addr2] = await ethers.getSigners();
    const CrowdFunding = await ethers.getContractFactory("CrowdFunding");
    const crowdFunding = await CrowdFunding.deploy();
    await crowdFunding.waitForDeployment();
    return { crowdFunding, owner, addr1, addr2 };
}

// Helper to extract campaignId from receipt (ethers v6 compatible)
function getCampaignId(crowdFunding, receipt) {
    const event = receipt.logs
        .map(log => { try { return crowdFunding.interface.parseLog(log) } catch { return null } })
        .find(e => e?.name === "CampaignCreated");
    if (!event) throw new Error("CampaignCreated event not found in receipt");
    return event.args.campaign_id;
}

describe("CrowdFunding", function () {
  describe("Creating a Campaign", function() {
    it("Should create a campaign successfully", async function() {
      const { crowdFunding, owner } = await loadFixture(deployCrowdFundingFixture);
      const goal = ethers.parseEther("1");
      const deadline = (await time.latest()) + 7 * 24 * 60 * 60;
      const tx = await crowdFunding.connect(owner).createCampaign(goal, deadline);
      const receipt = await tx.wait();
      expect(receipt).to.not.be.undefined;
    }); 

    it("Should fail to create a campaign with Negative or zero goal", async function() {
      const { crowdFunding, owner } = await loadFixture(deployCrowdFundingFixture);
      const goal = ethers.parseEther("0");
      const deadline = (await time.latest()) + 7 * 24 * 60 * 60;
      await expect(crowdFunding.connect(owner).createCampaign(goal, deadline)).to.be.revertedWith("Funds requested invalid"); 
    });

    it("Should fail to create a campaign with past deadline", async function() {
      const { crowdFunding, owner } = await loadFixture(deployCrowdFundingFixture);
      const goal = ethers.parseEther("1");
      const deadline = (await time.latest()) - 60;
      await expect(crowdFunding.connect(owner).createCampaign(goal, deadline)).to.be.revertedWith("Deadline invalid");
    }); 
  }); 
  
  describe("Contributing to a Campaign", function() {
    it("Should allow contributions to an active campaign", async function() {
      const { crowdFunding, owner, addr1 } = await loadFixture(deployCrowdFundingFixture);
      const goal = ethers.parseEther("1");
      const deadline = (await time.latest()) + 7 * 24 * 60 * 60;
      const tx = await crowdFunding.connect(owner).createCampaign(goal, deadline);
      const receipt = await tx.wait();

      const campaignId = getCampaignId(crowdFunding, receipt);

      await expect(
        crowdFunding.connect(addr1).contribute(campaignId, {
            value: ethers.parseEther("0.1"),
        })
      )
      .to.emit(crowdFunding, "Contributed")
      .withArgs(
          addr1.address,
          campaignId,
          ethers.parseEther("0.1")
      );
    });
    
    it("Should fail to contribute when campaign is not Active (status enum check)", async function () {
      const { crowdFunding, owner, addr1 } = await loadFixture(deployCrowdFundingFixture);
      const goal = ethers.parseEther("1");
      const deadline = (await time.latest()) + 1000;
      const tx = await crowdFunding.connect(owner).createCampaign(goal, deadline);
      const receipt = await tx.wait();

      const campaignId = getCampaignId(crowdFunding, receipt);

      await time.increase(2000);

      await expect(
          crowdFunding.connect(addr1).contribute(campaignId, {
              value: ethers.parseEther("0.1"),
          })
      ).to.be.revertedWith("Campaign expired");
    });
    
    it("Should fail to contribute after the campaign deadline", async function() {
      const { crowdFunding, owner, addr1 } = await loadFixture(deployCrowdFundingFixture);
      const goal = ethers.parseEther("1");
      const deadline = (await time.latest()) + 7 * 24 * 60 * 60;
      const tx = await crowdFunding.connect(owner).createCampaign(goal, deadline);
      const receipt = await tx.wait();

      const campaignId = getCampaignId(crowdFunding, receipt);
    
      await time.increase(7 * 24 * 60 * 60 + 100); 

      await expect(
          crowdFunding.connect(addr1).contribute(campaignId, {
              value: ethers.parseEther("1"),
          })
      ).to.be.revertedWith("Campaign expired");
    });  
    
    it("Should fail to contribute with zero amount", async function() {
      const { crowdFunding, owner, addr1 } = await loadFixture(deployCrowdFundingFixture);
      const goal = ethers.parseEther("1");
      const deadline = (await time.latest()) + 7 * 24 * 60 * 60;
      const tx = await crowdFunding.connect(owner).createCampaign(goal, deadline);
      const receipt = await tx.wait();

      const campaignId = getCampaignId(crowdFunding, receipt);

      await expect(
          crowdFunding.connect(addr1).contribute(campaignId, {
              value: ethers.parseEther("0"),
          })
      ).to.be.revertedWith("Invalid amount");
    });
  });
  
  describe("Withdrawing Funds", function() {
    it("Should allow the campaign creator to withdraw funds if the goal is met AND deadline passed", async function() {
      const { crowdFunding, owner, addr1 } = await loadFixture(deployCrowdFundingFixture);
      const goal = ethers.parseEther("100");
      const deadline = (await time.latest()) + 7 * 24 * 60 * 60;
      const tx = await crowdFunding.connect(owner).createCampaign(goal, deadline);
      const receipt = await tx.wait();

      const campaignId = getCampaignId(crowdFunding, receipt);

      await crowdFunding.connect(addr1).contribute(campaignId, {
          value: ethers.parseEther("100"),
      });

      await time.increase(7 * 24 * 60 * 60 + 100);

      await expect(
          crowdFunding.connect(owner).withdraw(campaignId)
      )
      .to.emit(crowdFunding, "FundsWithdrawn")
      .withArgs(owner.address, campaignId);
    });

    it("Should fail to withdraw funds if the goal is not met", async function () {
      const { crowdFunding, owner, addr1 } = await loadFixture(deployCrowdFundingFixture);
      const goal = ethers.parseEther("100");
      const deadline = (await time.latest()) + 7 * 24 * 60 * 60;
      const tx = await crowdFunding.connect(owner).createCampaign(goal, deadline);
      const receipt = await tx.wait();

      const campaignId = getCampaignId(crowdFunding, receipt);

      await crowdFunding.connect(addr1).contribute(campaignId, {
          value: ethers.parseEther("1"),
      });

      await time.increase(7 * 24 * 60 * 60 + 100);

      await expect(
          crowdFunding.connect(owner).withdraw(campaignId)
      ).to.be.revertedWith("Campaign not successful");
    });
    
    it("Should fail to withdraw funds if deadline is in the future", async function () {
      const { crowdFunding, owner, addr1 } = await loadFixture(deployCrowdFundingFixture);
      const goal = ethers.parseEther("1");
      const deadline = (await time.latest()) + 7 * 24 * 60 * 60;
      const tx = await crowdFunding.connect(owner).createCampaign(goal, deadline);
      const receipt = await tx.wait();

      const campaignId = getCampaignId(crowdFunding, receipt);

      await crowdFunding.connect(addr1).contribute(campaignId, {
          value: ethers.parseEther("1"),
      });

      await time.increase(1000);

      await expect(
          crowdFunding.connect(owner).withdraw(campaignId)
      ).to.be.revertedWith("Campaign ongoing");
    });

    it("Should fail to withdraw funds if caller is not campaign creator", async function () {
      const { crowdFunding, owner, addr1 } = await loadFixture(deployCrowdFundingFixture);
      const goal = ethers.parseEther("100");
      const deadline = (await time.latest()) + 7 * 24 * 60 * 60;
      const tx = await crowdFunding.connect(owner).createCampaign(goal, deadline);
      const receipt = await tx.wait();

      const campaignId = getCampaignId(crowdFunding, receipt);

      await crowdFunding.connect(addr1).contribute(campaignId, {
          value: ethers.parseEther("100"),
      });

      await time.increase(1000 + 7 * 24 * 60 * 60);

      await expect(
          crowdFunding.connect(addr1).withdraw(campaignId)
      ).to.be.revertedWith("Only owner can withdraw");
    });

    it("Should fail on double withdrawal attempt", async function () {
      const { crowdFunding, owner, addr1 } = await loadFixture(deployCrowdFundingFixture);
      const goal = ethers.parseEther("1");
      const deadline = (await time.latest()) + 1000;
      const tx = await crowdFunding.connect(owner).createCampaign(goal, deadline);
      const receipt = await tx.wait();

      // Fixed: was using receipt.events (ethers v5 API) — now uses ethers v6 log parsing
      const campaignId = getCampaignId(crowdFunding, receipt);

      await crowdFunding.connect(addr1).contribute(campaignId, {
          value: ethers.parseEther("1"),
      });

      await time.increase(2000);

      await crowdFunding.connect(owner).withdraw(campaignId);

      await expect(
          crowdFunding.connect(owner).withdraw(campaignId)
      ).to.be.revertedWith("Campaign already withdrawn");
    });
  });

  describe("Refunding Contributors", function() {
    it("Should refund contributor correctly when campaign fails", async function () {
      const { crowdFunding, owner, addr1 } = await loadFixture(deployCrowdFundingFixture);
      const goal = ethers.parseEther("1");
      const deadline = (await time.latest()) + 1000;
      const tx = await crowdFunding.connect(owner).createCampaign(goal, deadline);
      const receipt = await tx.wait();

      const campaignId = getCampaignId(crowdFunding, receipt);

      await crowdFunding.connect(addr1).contribute(campaignId, {
          value: ethers.parseEther("0.1"),
      });

      expect(
          await crowdFunding.getContribution(campaignId, addr1.address)
      ).to.equal(ethers.parseEther("0.1"));

      await time.increase(2000);

      await expect(
          crowdFunding.connect(addr1).refund(campaignId)
      )
      .to.emit(crowdFunding, "Refunded");

      expect(
          await crowdFunding.getContribution(campaignId, addr1.address)
      ).to.equal(0);
    });
    
    it("Should fail to refund contributors if the campaign is successful", async function () {
      const { crowdFunding, owner, addr1 } = await loadFixture(deployCrowdFundingFixture);
      const goal = ethers.parseEther("1");
      const deadline = (await time.latest()) + 7 * 24 * 60 * 60;
      const tx = await crowdFunding.connect(owner).createCampaign(goal, deadline);
      const receipt = await tx.wait();

      const campaignId = getCampaignId(crowdFunding, receipt);

      await crowdFunding.connect(addr1).contribute(campaignId, {
          value: ethers.parseEther("1"),
      });

      await time.increase(7 * 24 * 60 * 60 + 100);

      await expect(
          crowdFunding.connect(addr1).refund(campaignId)
      ).to.be.revertedWith("Campaign was Successful");
    });  

    it("Should fail to refund if caller is not a contributor", async function () {
      const { crowdFunding, owner, addr1, addr2 } = await loadFixture(deployCrowdFundingFixture);

      // Goal is 100 ETH but addr1 only contributes 1 ETH — campaign will FAIL
      const goal = ethers.parseEther("100");
      const deadline = (await time.latest()) + 7 * 24 * 60 * 60;

      const tx = await crowdFunding.connect(owner).createCampaign(goal, deadline);
      const receipt = await tx.wait();

      const campaignId = getCampaignId(crowdFunding, receipt);

      await crowdFunding.connect(addr1).contribute(campaignId, {
          value: ethers.parseEther("1"),   // goal not met → campaign fails
      });

      await time.increase(7 * 24 * 60 * 60 + 100);

      // addr2 never contributed, so should be rejected as non-contributor
      await expect(
          crowdFunding.connect(addr2).refund(campaignId)
      ).to.be.revertedWith("Only contributors can get a refund");
    });
  });
});