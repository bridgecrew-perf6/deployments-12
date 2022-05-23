import { Contract } from "ethers";
import { upgrades, ethers } from "hardhat";
 
let RoyaltiesRegistry;
let royaltiesRegistry: Contract;

async function main() {
    RoyaltiesRegistry = await ethers.getContractFactory("RoyaltiesRegistry");
    console.log("Deploying RoyaltiesRegistry...");
    royaltiesRegistry = await upgrades.deployProxy(RoyaltiesRegistry, [], {initializer: '__RoyaltiesRegistry_init'});
    console.log("RoyaltiesRegistry deployed to:", royaltiesRegistry.address);
  }
  
  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });
