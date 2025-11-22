import { expect } from "chai";

let ethers;

async function deployFixture() {
  if (!ethers) throw new Error("ethers not initialized");
  const [hospital, patient1, patient2, doctor1, stranger] = await ethers.getSigners();
  const Factory = await ethers.getContractFactory("RemoteHealthcareSystem", hospital);
  const contract = await Factory.deploy();
  await contract.waitForDeployment();
  return { contract, hospital, patient1, patient2, doctor1, stranger };
}

describe("RemoteHealthcareSystem", function () {
  before(async function () {
    try {
      const hre = (await import("hardhat")).default ?? (await import("hardhat"));
      ethers = hre.ethers ?? hre.default?.ethers;
      if (!ethers) this.skip();
    } catch (e) {
      this.skip();
    }
  });
  describe("Deployment", function () {
    it("sets Hospital to deployer", async function () {
      const { contract, hospital } = await deployFixture();
      expect(await contract.Hospital()).to.equal(hospital.address);
    });
  });

  describe("Registration: Patient", function () {
    it("only Hospital can add patient", async function () {
      const { contract, patient1, stranger } = await deployFixture();
      await expect(
        contract.connect(stranger).Add_Patient(patient1.address, "Alice", 30, "Addr1")
      ).to.be.reverted; // onlyHospital require fails

      await expect(
        contract.Add_Patient(patient1.address, "Alice", 30, "Addr1")
      ).to.emit(contract, "Patient_Added").withArgs(patient1.address, 1n, "Alice", 30, "Addr1");

      expect(await contract.NumberOfPatients()).to.equal(1n);
      expect(await contract.Patient_Account_IsRegistered(patient1.address)).to.equal(true);
      const res = await contract.Get_Patient(patient1.address);
      expect(res[0]).to.equal(patient1.address);
      expect(res[1]).to.equal(1n);
      expect(res[2]).to.equal("Alice");
      expect(res[3]).to.equal(30);
      expect(res[4]).to.equal("Addr1");
    });

    it("prevents duplicate or cross registration", async function () {
      const { contract, patient1, doctor1 } = await deployFixture();

      await contract.Add_Patient(patient1.address, "Alice", 30, "Addr1");
      await expect(
        contract.Add_Patient(patient1.address, "Alice", 30, "Addr1")
      ).to.be.reverted; // duplicate

      await contract.Add_Doctor(doctor1.address, "Dr Bob", 40, "Clinic");
      await expect(
        contract.Add_Patient(doctor1.address, "Alice", 30, "Addr1")
      ).to.be.reverted; // already a doctor
    });

    it("modify and remove by Hospital only", async function () {
      const { contract, patient1, stranger } = await deployFixture();
      await contract.Add_Patient(patient1.address, "Alice", 30, "Addr1");

      await expect(
        contract.connect(stranger).Modify_Patient(patient1.address, "Alice2", 31, "Addr2")
      ).to.be.reverted;

      await expect(
        contract.Modify_Patient(patient1.address, "Alice2", 31, "Addr2")
      ).to.emit(contract, "Patient_Modified").withArgs(patient1.address, "Alice2", 31, "Addr2");

      const res = await contract.Get_Patient(patient1.address);
      expect(res[2]).to.equal("Alice2");
      expect(res[3]).to.equal(31);
      expect(res[4]).to.equal("Addr2");

      await expect(contract.connect(stranger).Remove_Patient(patient1.address)).to.be.reverted;

      await expect(contract.Remove_Patient(patient1.address))
        .to.emit(contract, "Patient_Removed").withArgs(patient1.address);

      expect(await contract.Patient_Account_IsRegistered(patient1.address)).to.equal(false);
      expect(await contract.NumberOfPatients()).to.equal(0n);
    });

    it("Get_Patient access control: hospital, self, or authorized doctor", async function () {
      const { contract, patient1, doctor1, stranger } = await deployFixture();
      await contract.Add_Patient(patient1.address, "Alice", 30, "Addr1");
      await contract.Add_Doctor(doctor1.address, "Dr Bob", 40, "Clinic");

      // Unauthorized stranger cannot read
      await expect(contract.connect(stranger).Get_Patient(patient1.address)).to.be.reverted;

      // Self can read
      const bySelf = await contract.connect(patient1).Get_Patient(patient1.address);
      expect(bySelf[2]).to.equal("Alice");

      // Authorize doctor, then doctor can read
      await contract.Authorize_Patient_For_Doctor(doctor1.address, patient1.address);
      const byDoc = await contract.connect(doctor1).Get_Patient(patient1.address);
      expect(byDoc[2]).to.equal("Alice");
    });
  });

  describe("Registration: Doctor", function () {
    it("only Hospital can add/modify/remove doctor", async function () {
      const { contract, doctor1, stranger } = await deployFixture();

      await expect(
        contract.connect(stranger).Add_Doctor(doctor1.address, "Dr Bob", 40, "Clinic")
      ).to.be.reverted;

      await expect(
        contract.Add_Doctor(doctor1.address, "Dr Bob", 40, "Clinic")
      ).to.emit(contract, "Doctor_Added").withArgs(doctor1.address, 1n, "Dr Bob", 40, "Clinic");

      await expect(
        contract.connect(stranger).Modify_Doctor(doctor1.address, "Dr Robert", 41, "New Clinic")
      ).to.be.reverted;

      await expect(
        contract.Modify_Doctor(doctor1.address, "Dr Robert", 41, "New Clinic")
      ).to.emit(contract, "Doctor_Modified").withArgs(doctor1.address, "Dr Robert", 41, "New Clinic");

      const info = await contract.Get_Doctor(doctor1.address);
      expect(info[2]).to.equal("Dr Robert");
      expect(info[3]).to.equal(41);
      expect(info[4]).to.equal("New Clinic");

      await expect(contract.connect(stranger).Remove_Doctor(doctor1.address)).to.be.reverted;
      await expect(contract.Remove_Doctor(doctor1.address))
        .to.emit(contract, "Doctor_Removed").withArgs(doctor1.address);
    });

    it("Get_Doctor: only hospital or self", async function () {
      const { contract, doctor1, stranger } = await deployFixture();
      await contract.Add_Doctor(doctor1.address, "Dr Bob", 40, "Clinic");

      await expect(contract.connect(stranger).Get_Doctor(doctor1.address)).to.be.reverted;
      const selfView = await contract.connect(doctor1).Get_Doctor(doctor1.address);
      expect(selfView[2]).to.equal("Dr Bob");
    });
  });

  describe("Authorization mapping", function () {
    it("only Hospital can authorize/cancel", async function () {
      const { contract, patient1, doctor1, stranger } = await deployFixture();
      await contract.Add_Patient(patient1.address, "Alice", 30, "Addr1");
      await contract.Add_Doctor(doctor1.address, "Dr Bob", 40, "Clinic");

      await expect(
        contract.connect(stranger).Authorize_Patient_For_Doctor(doctor1.address, patient1.address)
      ).to.be.reverted;

      await contract.Authorize_Patient_For_Doctor(doctor1.address, patient1.address);
      expect(
        await contract.Get_Authorize_Patient_For_Doctor(doctor1.address, patient1.address)
      ).to.equal(true);

      await expect(
        contract.connect(stranger).Cancel_Patient_For_Doctor(doctor1.address, patient1.address)
      ).to.be.reverted;

      await contract.Cancel_Patient_For_Doctor(doctor1.address, patient1.address);
      expect(
        await contract.Get_Authorize_Patient_For_Doctor(doctor1.address, patient1.address)
      ).to.equal(false);
    });
  });

  describe("Patient Monitoring", function () {
    it("only registered patient can Set_Parameters(string); reads allowed to hospital/self/authorized doctor", async function () {
      const { contract, patient1, patient2, doctor1, stranger } = await deployFixture();

      await contract.Add_Patient(patient1.address, "Alice", 30, "Addr1");
      await contract.Add_Patient(patient2.address, "Beth", 28, "Addr2");
      await contract.Add_Doctor(doctor1.address, "Dr Bob", 40, "Clinic");

      await expect(
        contract.connect(stranger).Set_Parameters("hb=70;bp=110;tmp=36")
      ).to.be.reverted; // not a patient

      const payload = JSON.stringify({ hb: 72, bp: 115, tmp: 37 });
      await expect(
        contract.connect(patient1).Set_Parameters(payload)
      ).to.emit(contract, "Sensor_Data_Collected").withArgs(patient1.address, payload);

      // Hospital can read
      let params = await contract.Get_Parameters(patient1.address);
      expect(params).to.equal(payload);

      // Self can read
      const selfParams = await contract.connect(patient1).Get_Parameters(patient1.address);
      expect(selfParams).to.equal(payload);

      // Unauthorized doctor cannot read until authorized
      await expect(contract.connect(doctor1).Get_Parameters(patient1.address)).to.be.reverted;

      await contract.Authorize_Patient_For_Doctor(doctor1.address, patient1.address);
      const docParams = await contract.connect(doctor1).Get_Parameters(patient1.address);
      expect(docParams).to.equal(payload);
    });
  });
});
