import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const RemoteHealthcareSystemModule = buildModule("RemoteHealthcareSystemModule", (m) => {
  // The contract has no constructor arguments
  const remoteHealthcareSystem = m.contract("RemoteHealthcareSystem");

  return { remoteHealthcareSystem };
});

export default RemoteHealthcareSystemModule;
