import { expect } from "chai";
import hre from "hardhat";

const { ethers } = hre;

describe.skip("RemoteHealthcareSystem", function () {
  async function deployFixture() {
    const [hospital, patient1, patient2, doctor1, doctor2, stranger] = await ethers.getSigners();

    const RemoteHealthcareSystem = await ethers.getContractFactory("RemoteHealthcareSystem", hospital);
    const contract = await RemoteHealthcareSystem.deploy();

    return { contract, hospital, patient1, patient2, doctor1, doctor2, stranger };
  }

  describe("Deployment", function () {
    it("sets Hospital to deployer", async function () {
      const { contract, hospital } = await deployFixture();
      const hospitalAddr = await contract.Hospital();
      expect(hospitalAddr).to.equal(hospital.address);
    });
  });

  describe("Patient management", function () {
    it("only Hospital can add patient", async function () {
      const { contract, patient1, doctor1, stranger } = await deployFixture();
      await expect(
        contract.connect(stranger).Add_Patient(patient1.address, "Alice", 30, "123 Main")
      ).to.be.reverted;

      await expect(
        contract.Add_Patient(patient1.address, "Alice", 30, "123 Main")
      ).to.emit(contract, "Patient_Added").withArgs(
        patient1.address,
        1n,
        "Alice",
        30,
        "123 Main"
      );

      expect(await contract.NumberOfPatients()).to.equal(1n);
      expect(await contract.Patient_Account_IsRegistered(patient1.address)).to.equal(true);

      // cannot add same address again
      await expect(
        contract.Add_Patient(patient1.address, "Alice", 30, "123 Main")
      ).to.be.reverted;

      // cannot add if address is a registered doctor
      await contract.Add_Doctor(doctor1.address, "Dr Who", 40, "Clinic");
      await expect(
        contract.Add_Patient(doctor1.address, "Someone", 22, "Somewhere")
      ).to.be.reverted;
    });

    it("modify and remove patient (only Hospital)", async function () {
      const { contract, patient1 } = await deployFixture();
      await contract.Add_Patient(patient1.address, "Alice", 30, "123 Main");

      await expect(
        contract.Modify_Patient(patient1.address, "Alice B", 31, "456 Oak")
      ).to.emit(contract, "Patient_Modified").withArgs(
        patient1.address,
        "Alice B",
        31,
        "456 Oak"
      );

      const patient = await contract.Get_Patient(patient1.address);
      expect(patient[2]).to.equal("Alice B");
      expect(patient[3]).to.equal(31);
      expect(patient[4]).to.equal("456 Oak");

      await expect(contract.Remove_Patient(patient1.address))
        .to.emit(contract, "Patient_Removed")
        .withArgs(patient1.address);

      expect(await contract.Patient_Account_IsRegistered(patient1.address)).to.equal(false);
      expect(await contract.NumberOfPatients()).to.equal(0n);

      // cannot modify/remove unregistered
      await expect(
        contract.Modify_Patient(patient1.address, "X", 1, "Y")
      ).to.be.reverted;
      await expect(contract.Remove_Patient(patient1.address)).to.be.reverted;
    });

    it("Get_Patient access control", async function () {
      const { contract, hospital, patient1, doctor1, stranger } = await deployFixture();

      await contract.Add_Patient(patient1.address, "Alice", 30, "123 Main");
      await contract.Add_Doctor(doctor1.address, "Dr Who", 40, "Clinic");

      // hospital can read
      await expect(contract.connect(hospital).Get_Patient(patient1.address)).to.not.be.reverted;
      // patient self can read
      await expect(contract.connect(patient1).Get_Patient(patient1.address)).to.not.be.reverted;
      // doctor not authorized cannot read
      await expect(contract.connect(doctor1).Get_Patient(patient1.address)).to.be.reverted;
      // after authorization, doctor can read
      await contract.Authorize_Patient_For_Doctor(doctor1.address, patient1.address);
      await expect(contract.connect(doctor1).Get_Patient(patient1.address)).to.not.be.reverted;
      // random stranger cannot read
      await expect(contract.connect(stranger).Get_Patient(patient1.address)).to.be.reverted;
    });
  });

  describe("Doctor management", function () {
    it("add/modify/remove doctor only by Hospital", async function () {
      const { contract, doctor1, patient1, stranger } = await deployFixture();

      // non-hospital cannot add
      await expect(
        contract.connect(stranger).Add_Doctor(doctor1.address, "Dr Who", 40, "Clinic")
      ).to.be.reverted;

      await expect(
        contract.Add_Doctor(doctor1.address, "Dr Who", 40, "Clinic")
      ).to.emit(contract, "Doctor_Added").withArgs(
        doctor1.address,
        1n,
        "Dr Who",
        40,
        "Clinic"
      );

      // cannot add if address is already a registered patient
      await contract.Add_Patient(patient1.address, "Alice", 30, "123 Main");
      await expect(
        contract.Add_Doctor(patient1.address, "Dr Not", 50, "Somewhere")
      ).to.be.reverted;

      await expect(
        contract.Modify_Doctor(doctor1.address, "Dr Who II", 41, "City Hospital")
      ).to.emit(contract, "Doctor_Modified").withArgs(
        doctor1.address,
        "Dr Who II",
        41,
        "City Hospital"
      );

      const doc = await contract.Get_Doctor(doctor1.address);
      expect(doc[2]).to.equal("Dr Who II");
      expect(doc[3]).to.equal(41);
      expect(doc[4]).to.equal("City Hospital");

      await expect(contract.Remove_Doctor(doctor1.address))
        .to.emit(contract, "Doctor_Removed")
        .withArgs(doctor1.address);

      // cannot get removed doctor
      await expect(contract.Get_Doctor(doctor1.address)).to.be.reverted;
    });

    it("Get_Doctor access control", async function () {
      const { contract, hospital, doctor1, stranger } = await deployFixture();
      await contract.Add_Doctor(doctor1.address, "Dr Who", 40, "Clinic");

      // hospital can read
      await expect(contract.connect(hospital).Get_Doctor(doctor1.address)).to.not.be.reverted;
      // doctor self can read
      await expect(contract.connect(doctor1).Get_Doctor(doctor1.address)).to.not.be.reverted;
      // stranger cannot
      await expect(contract.connect(stranger).Get_Doctor(doctor1.address)).to.be.reverted;
    });
  });

  describe("Authorization mapping", function () {
    it("only Hospital can authorize/cancel and view mapping", async function () {
      const { contract, patient1, doctor1, stranger } = await deployFixture();

      await contract.Add_Patient(patient1.address, "Alice", 30, "123 Main");
      await contract.Add_Doctor(doctor1.address, "Dr Who", 40, "Clinic");

      await expect(
        contract.connect(stranger).Authorize_Patient_For_Doctor(doctor1.address, patient1.address)
      ).to.be.reverted;

      await contract.Authorize_Patient_For_Doctor(doctor1.address, patient1.address);

      await expect(
        contract.Get_Authorize_Patient_For_Doctor(doctor1.address, patient1.address)
      ).to.not.be.reverted;

      expect(
        await contract.Get_Authorize_Patient_For_Doctor(doctor1.address, patient1.address)
      ).to.equal(true);

      await contract.Cancel_Patient_For_Doctor(doctor1.address, patient1.address);
      expect(
        await contract.Get_Authorize_Patient_For_Doctor(doctor1.address, patient1.address)
      ).to.equal(false);
    });
  });

  describe("Patient monitoring", function () {
    it("only registered patient can Set_Parameters and access controls on Get_Parameters", async function () {
      const { contract, patient1, patient2, doctor1, hospital, stranger } = await deployFixture();

      await contract.Add_Patient(patient1.address, "Alice", 30, "123 Main");
      await contract.Add_Patient(patient2.address, "Bob", 35, "456 Oak");
      await contract.Add_Doctor(doctor1.address, "Dr Who", 40, "Clinic");

      // Unregistered cannot call Set_Parameters
      await expect(contract.connect(stranger).Set_Parameters(70, 120, 37)).to.be.reverted;

      // Registered patient can Set_Parameters and emits event
      await expect(contract.connect(patient1).Set_Parameters(72, 118, 36))
        .to.emit(contract, "Sensor_Data_Collected")
        .withArgs(patient1.address, 72, 118, 36);

      // Access control for Get_Parameters
      // patient self
      await expect(contract.connect(patient1).Get_Parameters(patient1.address)).to.not.be.reverted;
      // hospital
      await expect(contract.connect(hospital).Get_Parameters(patient1.address)).to.not.be.reverted;
      // unrelated doctor not authorized
      await expect(contract.connect(doctor1).Get_Parameters(patient1.address)).to.be.reverted;
      // after authorization
      await contract.Authorize_Patient_For_Doctor(doctor1.address, patient1.address);
      await expect(contract.connect(doctor1).Get_Parameters(patient1.address)).to.not.be.reverted;

      const params = await contract.Get_Parameters(patient1.address);
      expect(params[0]).to.equal(patient1.address);
      expect(params[1]).to.equal(72);
      expect(params[2]).to.equal(118);
      expect(params[3]).to.equal(36);

      // other patient cannot read patient1 data
      await expect(contract.connect(patient2).Get_Parameters(patient1.address)).to.be.reverted;
    });
  });
});
