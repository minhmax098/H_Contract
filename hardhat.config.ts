import "@nomicfoundation/hardhat-ethers";
import "@nomicfoundation/hardhat-ethers-chai-matchers";
import "@nomicfoundation/hardhat-ignition-ethers";
import "@nomicfoundation/hardhat-verify";
import "@nomicfoundation/hardhat-mocha";
import "dotenv/config";
import type {HardhatUserConfig} from "hardhat/config";
import {configVariable} from "hardhat/config";

const config: HardhatUserConfig = {
    solidity: {
        version: "0.8.28",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },
            viaIR: true,
        },
    },
    mocha: {
        timeout: 40000
    },
    networks: {
        hardhatMainnet: {
            type: "edr-simulated",
            chainType: "l1",
        },
        hardhatOp: {
            type: "edr-simulated",
            chainType: "op",
        },
        bsctestnet: {
            type: "http",
            chainType: "l1",
            url: configVariable("RPC_URL"),
            accounts: [configVariable("PRIVATE_KEY")],
        },
    },
    verify: {
        etherscan: {
            apiKey: "WKYFUHQV4M9SBRQEAQCUSI2HZE1ICHFI9Z",
        },
    },
};

export default config;
