import { readFileSync } from "fs";
import { resolve } from "path";
import dotenv from "dotenv";
import { ethers } from "ethers";

dotenv.config();

// Simple CLI: node ts-node scripts/interact-remote-healthcare.ts <action> [...args]
// Or: npx ts-node scripts/interact-remote-healthcare.ts <action> [...args]
// Environment:
// - RPC_URL: RPC endpoint
// - PRIVATE_KEY: signer private key (hospital/doctor/patient depending on action)
// - CONTRACT_ADDRESS: deployed RemoteHealthcareSystem address

function usage(exitCode = 0) {
  const lines = [
    "Usage:",
    "  npx ts-node scripts/interact-remote-healthcare.ts <action> [...args]",
    "",
    "Env vars:",
    "  RPC_URL, PRIVATE_KEY, CONTRACT_ADDRESS",
    "",
    "Actions:",
    "  info",
    "  getHospital",
    "  getCounts",
    "  addPatient <patientAddr> <name> <age> <homeAddress>",
    "  modifyPatient <patientAddr> <name> <age> <homeAddress>",
    "  removePatient <patientAddr>",
    "  getPatient <patientAddr>",
    "  addDoctor <doctorAddr> <name> <age> <homeAddress>",
    "  modifyDoctor <doctorAddr> <name> <age> <homeAddress>",
    "  removeDoctor <doctorAddr>",
    "  getDoctor <doctorAddr>",
    "  authorizePatientForDoctor <doctorAddr> <patientAddr>",
    "  cancelPatientForDoctor <doctorAddr> <patientAddr>",
    "  getAuthorizePatientForDoctor <doctorAddr> <patientAddr>",
    "  setParameters <parameters:string>   # e.g. '{\"hb\":72,\"bp\":118,\"tmp\":36}'",
    "  getParameters <patientAddr>",
  ];
  console.log(lines.join("\n"));
  process.exit(exitCode);
}

async function getProviderAndSigner() {
  const rpcUrl = process.env.RPC_URL;
  const pk = process.env.PRIVATE_KEY;
  if (!rpcUrl) throw new Error("RPC_URL is required");
  const provider = new ethers.JsonRpcProvider(rpcUrl);
  if (!pk) return { provider, signer: null as unknown as ethers.Wallet };
  const signer = new ethers.Wallet(pk, provider);
  return { provider, signer };
}

function loadAbi() {
  // Try to read the artifact JSON produced by Hardhat
  const artifactPath = resolve(
    process.cwd(),
    "artifacts/contracts/RemoteHealthcareSystem.sol/RemoteHealthcareSystem.json"
  );
  const json = JSON.parse(readFileSync(artifactPath, "utf8"));
  return json.abi;
}

async function getContract(signerOrProvider: ethers.Signer | ethers.Provider) {
  const address = process.env.CONTRACT_ADDRESS;
  if (!address) throw new Error("CONTRACT_ADDRESS is required");
  const abi = loadAbi();
  return new ethers.Contract(address, abi, signerOrProvider);
}

function asUint8(name: string, v: string) {
  const n = Number(v);
  if (!Number.isInteger(n) || n < 0 || n > 255) {
    throw new Error(`${name} must be uint8 (0..255)`);
  }
  return n;
}

async function main() {
  const [, , action, ...args] = process.argv;
  if (!action) usage(1);

  const { provider, signer } = await getProviderAndSigner();
  const signerOrProvider = signer ?? provider;
  const contract = await getContract(signerOrProvider);

  switch (action) {
    case "info": {
      const network = await provider.getNetwork();
      const block = await provider.getBlockNumber();
      const address = await contract.getAddress();
      let signerAddr: string | undefined;
      if (signer) signerAddr = await signer.getAddress();
      console.log({
        network: { name: network.name, chainId: Number(network.chainId) },
        block,
        contract: address,
        signer: signerAddr ?? null,
      });
      break;
    }
    case "getHospital": {
      const hospital = await contract.Hospital();
      console.log({ hospital });
      break;
    }
    case "getCounts": {
      const numPatients = await contract.NumberOfPatients();
      const numDoctors = await contract.NumberOfDoctors();
      console.log({ NumberOfPatients: Number(numPatients), NumberOfDoctors: Number(numDoctors) });
      break;
    }
    case "addPatient": {
      if (!signer) throw new Error("PRIVATE_KEY (Hospital) required");
      const [patientAddr, name, ageStr, homeAddr] = args;
      if (!patientAddr || !name || !ageStr || !homeAddr) usage(1);
      const age = asUint8("age", ageStr);
      const tx = await contract.Add_Patient(patientAddr, name, age, homeAddr);
      console.log("sent:", tx.hash);
      const rc = await tx.wait();
      console.log("confirmed in", rc?.blockNumber);
      break;
    }
    case "modifyPatient": {
      if (!signer) throw new Error("PRIVATE_KEY (Hospital) required");
      const [patientAddr, name, ageStr, homeAddr] = args;
      if (!patientAddr || !name || !ageStr || !homeAddr) usage(1);
      const age = asUint8("age", ageStr);
      const tx = await contract.Modify_Patient(patientAddr, name, age, homeAddr);
      console.log("sent:", tx.hash);
      const rc = await tx.wait();
      console.log("confirmed in", rc?.blockNumber);
      break;
    }
    case "removePatient": {
      if (!signer) throw new Error("PRIVATE_KEY (Hospital) required");
      const [patientAddr] = args;
      if (!patientAddr) usage(1);
      const tx = await contract.Remove_Patient(patientAddr);
      console.log("sent:", tx.hash);
      const rc = await tx.wait();
      console.log("confirmed in", rc?.blockNumber);
      break;
    }
    case "getPatient": {
      const [patientAddr] = args;
      if (!patientAddr) usage(1);
      const res = await contract.Get_Patient(patientAddr);
      // returns: (address, uint, string, uint8, string)
      const [acct, id, name, age, addr] = res as [string, bigint, string, number, string];
      console.log({
        Patient_Account: acct,
        Patient_ID: Number(id),
        Patient_Name: name,
        Patient_Age: Number(age),
        Patient_Address: addr,
      });
      break;
    }
    case "addDoctor": {
      if (!signer) throw new Error("PRIVATE_KEY (Hospital) required");
      const [doctorAddr, name, ageStr, homeAddr] = args;
      if (!doctorAddr || !name || !ageStr || !homeAddr) usage(1);
      const age = asUint8("age", ageStr);
      const tx = await contract.Add_Doctor(doctorAddr, name, age, homeAddr);
      console.log("sent:", tx.hash);
      const rc = await tx.wait();
      console.log("confirmed in", rc?.blockNumber);
      break;
    }
    case "modifyDoctor": {
      if (!signer) throw new Error("PRIVATE_KEY (Hospital) required");
      const [doctorAddr, name, ageStr, homeAddr] = args;
      if (!doctorAddr || !name || !ageStr || !homeAddr) usage(1);
      const age = asUint8("age", ageStr);
      const tx = await contract.Modify_Doctor(doctorAddr, name, age, homeAddr);
      console.log("sent:", tx.hash);
      const rc = await tx.wait();
      console.log("confirmed in", rc?.blockNumber);
      break;
    }
    case "removeDoctor": {
      if (!signer) throw new Error("PRIVATE_KEY (Hospital) required");
      const [doctorAddr] = args;
      if (!doctorAddr) usage(1);
      const tx = await contract.Remove_Doctor(doctorAddr);
      console.log("sent:", tx.hash);
      const rc = await tx.wait();
      console.log("confirmed in", rc?.blockNumber);
      break;
    }
    case "getDoctor": {
      const [doctorAddr] = args;
      if (!doctorAddr) usage(1);
      const res = await contract.Get_Doctor(doctorAddr);
      const [acct, id, name, age, addr] = res as [string, bigint, string, number, string];
      console.log({
        Doctor_Account: acct,
        Doctor_ID: Number(id),
        Doctor_Name: name,
        Doctor_Age: Number(age),
        Doctor_Address: addr,
      });
      break;
    }
    case "authorizePatientForDoctor": {
      if (!signer) throw new Error("PRIVATE_KEY (Hospital) required");
      const [doctorAddr, patientAddr] = args;
      if (!doctorAddr || !patientAddr) usage(1);
      const tx = await contract.Authorize_Patient_For_Doctor(doctorAddr, patientAddr);
      console.log("sent:", tx.hash);
      const rc = await tx.wait();
      console.log("confirmed in", rc?.blockNumber);
      break;
    }
    case "cancelPatientForDoctor": {
      if (!signer) throw new Error("PRIVATE_KEY (Hospital) required");
      const [doctorAddr, patientAddr] = args;
      if (!doctorAddr || !patientAddr) usage(1);
      const tx = await contract.Cancel_Patient_For_Doctor(doctorAddr, patientAddr);
      console.log("sent:", tx.hash);
      const rc = await tx.wait();
      console.log("confirmed in", rc?.blockNumber);
      break;
    }
    case "getAuthorizePatientForDoctor": {
      const [doctorAddr, patientAddr] = args;
      if (!doctorAddr || !patientAddr) usage(1);
      const allowed = await contract.Get_Authorize_Patient_For_Doctor(doctorAddr, patientAddr);
      console.log({ allowed });
      break;
    }
    case "setParameters": {
      if (!signer) throw new Error("PRIVATE_KEY (Patient) required");
      const [payload] = args;
      if (!payload) usage(1);
      const tx = await contract.Set_Parameters(payload);
      console.log("sent:", tx.hash);
      const rc = await tx.wait();
      console.log("confirmed in", rc?.blockNumber);
      break;
    }
    case "getParameters": {
      const [patientAddr] = args;
      if (!patientAddr) usage(1);
      const res = await contract.Get_Parameters(patientAddr);
      console.log({ Parameters: res });
      break;
    }
    default:
      console.error(`Unknown action: ${action}`);
      usage(1);
  }
}

main().catch((err) => {
  console.error("Error:", err?.message ?? err);
  process.exit(1);
});
