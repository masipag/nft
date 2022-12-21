import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: "0.8.17",
  networks: {
    goerli: {
      url: "https://eth-goerli.g.alchemy.com/v2/5V3Su4CDBnyLjb5Am3Wtasg_C6qi7SlI",
      accounts: ["f1fbaa0737de685ebd722414f8389e9d34f17afeca032a4e66ad37458383866c"]
    }
  }
};

export default config;
