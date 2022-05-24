import { upgrades, ethers, network } from "hardhat";

async function main() {
  const TransferProxy = await ethers.getContractFactory("TransferProxy");
  const transferProxy = await upgrades.deployProxy(TransferProxy);
  await transferProxy.deployed();
  await transferProxy.__OperatorRole_init();
  console.log("transfer proxy deployed to:", transferProxy.address);

  const ERC20Proxy = await ethers.getContractFactory("ERC20TransferProxy");
  const erc20Proxy = await upgrades.deployProxy(ERC20Proxy);
  await erc20Proxy.deployed();
  erc20Proxy.__OperatorRole_init();
  console.log("deployed erc20TransferProxy at", erc20Proxy.address);

  const Erc721Proxy = await ethers.getContractFactory(
    "ERC721LazyMintTransferProxy"
  );
  const erc721proxy = await upgrades.deployProxy(Erc721Proxy);
  await erc721proxy.deployed();
  erc721proxy.__OperatorRole_init();
  console.log("deployed erc721LazyMintProxy at", erc721proxy.address);
  const Erc1155Proxy = await ethers.getContractFactory(
    "ERC1155LazyMintTransferProxy"
  );
  /* const erc1155proxy = await Erc1155Proxy.deploy();
  await erc1155proxy.deployed();
  erc1155proxy.__OperatorRole_init();
  console.log("deployed erc1155LazyMintProxy at", erc1155proxy.address); */
  const AKX721 = await ethers.getContractFactory("ERC721AKX");
  const akx721 = await upgrades.deployProxy(
    AKX721,
    [
      "AKX Lab",
      "AKX",
      "ipfs:/",
      "",
      transferProxy.address,
      erc721proxy.address,
    ],
    { initializer: "__ERC721AKX_init" }
  );
  await akx721.deployed();

  console.log("token deployed at:", akx721.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
