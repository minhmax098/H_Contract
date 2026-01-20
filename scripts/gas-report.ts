import hre from "hardhat";

async function main() {
  const { ethers } = hre;
  console.log("HRE keys:", Object.keys(hre));
  const [hospital, patient1, patient2, doctor1] = await ethers.getSigners();
  const RemoteHealthcareSystem = await ethers.getContractFactory("RemoteHealthcareSystem", hospital);
  const contract = await RemoteHealthcareSystem.deploy();
  await contract.waitForDeployment();

  console.log("\n    --- Gas Usage Report ---");

  async function logGas(txResponse, label) {
    const receipt = await txResponse.wait();
    console.log(`    Gas used for ${label}: ${receipt.gasUsed.toString()}`);
    return receipt;
  }

  // Workflow
  let tx = await contract.Add_Patient(patient1.address, "Alice", 30, "123 Main St");
  await logGas(tx, "Add_Patient");

  tx = await contract.Modify_Patient(patient1.address, "Alice Modified", 31, "456 Oak St");
  await logGas(tx, "Modify_Patient");

  tx = await contract.Add_Doctor(doctor1.address, "Dr. Smith", 45, "Medical Center");
  await logGas(tx, "Add_Doctor");

  tx = await contract.Authorize_Patient_For_Doctor(doctor1.address, patient1.address);
  await logGas(tx, "Authorize_Patient_For_Doctor");

  tx = await contract.connect(patient1).Authorize_Doctor(doctor1.address, true);
  await logGas(tx, "Authorize_Doctor (Patient)");

  tx = await contract.connect(patient1).Set_Parameters("hb=75;bp=120/80;temp=36.6");
  await logGas(tx, "Set_Parameters");

  const anonId = ethers.keccak256(ethers.toUtf8Bytes("anon-1"));
  const cid = "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3hlgtifv2ydsqke";
  const timestamp = Math.floor(Date.now() / 1000);
  const cidDigest = ethers.keccak256(ethers.toUtf8Bytes(cid));
  const network = await ethers.provider.getNetwork();

  const msgHash = ethers.solidityPackedKeccak256(
      ["bytes32", "bytes32", "uint256", "address", "uint256"],
      [anonId, cidDigest, timestamp, await contract.getAddress(), network.chainId]
  );
  const signature = await patient1.signMessage(ethers.toBeArray(msgHash));

  tx = await contract.connect(patient1).setParameters(anonId, cid, timestamp, signature);
  await logGas(tx, "setParameters (IPFS)");

  tx = await contract.Remove_Patient(patient1.address);
  await logGas(tx, "Remove_Patient");

  console.log("    ------------------------\n");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
