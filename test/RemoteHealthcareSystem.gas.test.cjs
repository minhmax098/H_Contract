const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");

async function main() {
  let artifact;
  // Use a local provider (Hardhat's default node or similar)
  // Since we are running with 'npx hardhat run', a node should be available.
  const provider = new ethers.JsonRpcProvider("http://127.0.0.1:8545");

  // Hardhat's default accounts are deterministic
  const privateKey = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
  const hospital = new ethers.Wallet(privateKey, provider);
  const patient1 = new ethers.Wallet("0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d", provider);
  const doctor1 = new ethers.Wallet("0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a", provider);

  const artifactPath = path.join(__dirname, "../artifacts/contracts/RemoteHealthcareSystem.sol/RemoteHealthcareSystem.json");
  if (!fs.existsSync(artifactPath)) {
      // Try alternative path if run from project root
      const altPath = path.join(process.cwd(), "artifacts/contracts/RemoteHealthcareSystem.sol/RemoteHealthcareSystem.json");
      if (fs.existsSync(altPath)) {
          artifact = JSON.parse(fs.readFileSync(altPath, "utf8"));
      } else {
          throw new Error("Artifact not found. Please run 'npx hardhat compile' first.");
      }
  } else {
      artifact = JSON.parse(fs.readFileSync(artifactPath, "utf8"));
  }

  const factory = new ethers.ContractFactory(artifact.abi, artifact.bytecode, hospital);
  const contract = await factory.deploy();
  await contract.waitForDeployment();
  const contractAddress = await contract.getAddress();

  console.log("\n    --- Gas Usage Report ---");

  async function logGas(txResponse, label) {
    const receipt = await txResponse.wait();
    console.log(`    Gas used for ${label}: ${receipt.gasUsed.toString()}`);
    return receipt;
  }

  let nonceHospital = await hospital.getNonce();
  let noncePatient1 = await patient1.getNonce();

  let tx = await contract.Add_Patient(patient1.address, "Alice", 30, "123 Main St", { nonce: nonceHospital++ });
  await logGas(tx, "Add_Patient");

  tx = await contract.Modify_Patient(patient1.address, "Alice Modified", 31, "456 Oak St", { nonce: nonceHospital++ });
  await logGas(tx, "Modify_Patient");

  tx = await contract.Add_Doctor(doctor1.address, "Dr. Smith", 45, "Medical Center", { nonce: nonceHospital++ });
  await logGas(tx, "Add_Doctor");

  tx = await contract.Modify_Doctor(doctor1.address, "Dr. Smith Modified", 46, "Main Hospital", { nonce: nonceHospital++ });
  await logGas(tx, "Modify_Doctor");

  tx = await contract.Authorize_Patient_For_Doctor(doctor1.address, patient1.address, { nonce: nonceHospital++ });
  await logGas(tx, "Authorize_Patient_For_Doctor");

  tx = await contract.Cancel_Patient_For_Doctor(doctor1.address, patient1.address, { nonce: nonceHospital++ });
  await logGas(tx, "Cancel_Patient_For_Doctor");

  // Re-authorize for later tests
  tx = await contract.Authorize_Patient_For_Doctor(doctor1.address, patient1.address, { nonce: nonceHospital++ });
  await logGas(tx, "Authorize_Patient_For_Doctor (re-auth)");

  tx = await contract.connect(patient1).Authorize_Doctor(doctor1.address, true, { nonce: noncePatient1++ });
  await logGas(tx, "Authorize_Doctor (Patient)");

  tx = await contract.connect(patient1).Set_Parameters("hb=75;bp=120/80;temp=36.6", { nonce: noncePatient1++ });
  await logGas(tx, "Set_Parameters");

  const anonId = ethers.keccak256(ethers.toUtf8Bytes("anon-1"));
  const cid = "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3hlgtifv2ydsqke";
  const timestamp = Math.floor(Date.now() / 1000);
  const cidDigest = ethers.keccak256(ethers.toUtf8Bytes(cid));

  const network = await provider.getNetwork();

  // SolidityPackedKeccak256 in ethers v6
  const msgHash = ethers.solidityPackedKeccak256(
      ["bytes32", "bytes32", "uint256", "address", "uint256"],
      [anonId, cidDigest, timestamp, contractAddress, network.chainId]
  );

  const signature = await patient1.signMessage(ethers.getBytes(msgHash));

  tx = await contract.connect(patient1).setParameters(anonId, cid, timestamp, signature, { nonce: noncePatient1++ });
  await logGas(tx, "setParameters (IPFS)");

  tx = await contract.Remove_Patient(patient1.address, { nonce: nonceHospital++ });
  await logGas(tx, "Remove_Patient");

  tx = await contract.Remove_Doctor(doctor1.address, { nonce: nonceHospital++ });
  await logGas(tx, "Remove_Doctor");

  console.log("    ------------------------\n");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
