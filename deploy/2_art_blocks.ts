import { Contract } from "ethers";
import { ethers } from "hardhat";

let RoyaltiesRegistryArtBlock;
// eslint-disable-next-line no-unused-vars
let royaltiesRegistryArtBlock: Contract;
const RoyaltiesRegistryAddr = "0x3CCea22dD0179ae49097Fd42D85c6e15462934C4";

async function main() {
  RoyaltiesRegistryArtBlock = await ethers.getContractFactory(
    "RoyaltiesProviderArtBlocks"
  );
  console.log("Deploying RoyaltiesRegistryArtBlocks...");
  royaltiesRegistryArtBlock = await RoyaltiesRegistryArtBlock.deploy();

  await royaltiesRegistryArtBlock.deployed();
  console.log(
    "RoyaltiesRegistry deployed to:",
    royaltiesRegistryArtBlock.address
  );

  const rAddress = royaltiesRegistryArtBlock.address;
  const RoyaltiesRegistry = await ethers.getContractFactory(
    "RoyaltiesRegistry"
  );
  const royaltiesRegistry = await RoyaltiesRegistry.attach(
    RoyaltiesRegistryAddr
  );
  await royaltiesRegistry.transferOwnership(rAddress);

  console.log("artblock ownership transfered to:", rAddress);

}

main()
  // eslint-disable-next-line no-process-exit
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    // eslint-disable-next-line no-process-exit
    process.exit(1);
  });
