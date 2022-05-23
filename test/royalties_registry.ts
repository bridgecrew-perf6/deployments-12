import {expect} from "chai";
import { Contract } from "ethers";
import { upgrades, ethers } from "hardhat";
 
let RoyaltiesRegistry;
let royaltiesRegistry: Contract;
 
// Start test block
describe('RoyaltiesRegistry (proxy)', function () {
  beforeEach(async function () {
    RoyaltiesRegistry = await ethers.getContractFactory("RoyaltiesRegistry");
    royaltiesRegistry = await upgrades.deployProxy(RoyaltiesRegistry, [], {initializer: '__RoyaltiesRegistry_init'});
    await royaltiesRegistry.deployed();
    console.log("deployed to address:", royaltiesRegistry.address)
});
 
  // Test case
  it('should have an address if deployed', async function () {
    expect((await royaltiesRegistry.address)).not.empty;
  });
});