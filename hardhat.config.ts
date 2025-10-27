import "dotenv/config";
import type {HardhatUserConfig} from "hardhat/config";

import hardhatToolboxMochaEthersPlugin from "@nomicfoundation/hardhat-toolbox-mocha-ethers";
import hardhatVerify from "@nomicfoundation/hardhat-verify";
import "@nomicfoundation/hardhat-ethers";
import {configVariable} from "hardhat/config";

const config: HardhatUserConfig = {
    plugins: [hardhatToolboxMochaEthersPlugin, hardhatVerify],
    solidity: {
        profiles: {
            default: {
                version: "0.8.28",
            },
            production: {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
        },
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
