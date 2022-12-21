import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: "0.8.17",
  networks: {
    polygon_mumbai: {
      url: "https://polygon-mumbai.g.alchemy.com/v2/A7dHrIBdLyRK2icRvwWxiOH5Jbu2uhqF",
      accounts: ["f1fbaa0737de685ebd722414f8389e9d34f17afeca032a4e66ad37458383866c"]
    },
  }
};

export default config;
