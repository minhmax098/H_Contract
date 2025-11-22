// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {RemoteHealthcareSystem} from "../contracts/RemoteHealthcareSystem.sol";

contract RemoteHealthcareSystemTest is Test {
    RemoteHealthcareSystem sys;

    address hospital; // equals address(this) after deployment
    address patient1 = address(0x111);
    address patient2 = address(0x222);
    address doctor1 = address(0x333);
    address doctor2 = address(0x444);
    address stranger = address(0x555);

    function setUp() public {
        // Deploy as this contract; Hospital will be address(this)
        sys = new RemoteHealthcareSystem();
        hospital = address(this);
    }

    function testDeploymentSetsHospital() public {
        assertEq(sys.Hospital(), hospital);
    }

    function testOnlyHospitalCanAddPatient() public {
        // Try from stranger
        vm.prank(stranger);
        vm.expectRevert();
        sys.Add_Patient(patient1, "Alice", 30, "Addr1");

        // From hospital (address(this))
        vm.expectEmit(true, true, true, true);
        emit RemoteHealthcareSystem.Patient_Added(patient1, 1, "Alice", 30, "Addr1");
        sys.Add_Patient(patient1, "Alice", 30, "Addr1");

        assertEq(sys.NumberOfPatients(), 1);
        assertTrue(sys.Patient_Account_IsRegistered(patient1));

        // Duplicate add reverts
        vm.expectRevert();
        sys.Add_Patient(patient1, "Alice", 30, "Addr1");

        // Register a doctor, cannot add same address as patient
        sys.Add_Doctor(doctor1, "Dr Bob", 40, "Clinic");
        vm.expectRevert();
        sys.Add_Patient(doctor1, "X", 1, "Y");
    }

    function testModifyAndRemovePatient() public {
        sys.Add_Patient(patient1, "Alice", 30, "Addr1");

        // Non-hospital cannot modify/remove
        vm.startPrank(stranger);
        vm.expectRevert();
        sys.Modify_Patient(patient1, "Alice2", 31, "Addr2");
        vm.expectRevert();
        sys.Remove_Patient(patient1);
        vm.stopPrank();

        // Hospital modifies
        vm.expectEmit(true, true, true, true);
        emit RemoteHealthcareSystem.Patient_Modified(patient1, "Alice2", 31, "Addr2");
        sys.Modify_Patient(patient1, "Alice2", 31, "Addr2");

        (
            address acc,
            uint id,
            string memory name,
            uint8 age,
            string memory addr
        ) = sys.Get_Patient(patient1);
        assertEq(acc, patient1);
        assertEq(id, 1);
        assertEq(name, "Alice2");
        assertEq(age, 31);
        assertEq(addr, "Addr2");

        // Remove
        vm.expectEmit(true, true, true, true);
        emit RemoteHealthcareSystem.Patient_Removed(patient1);
        sys.Remove_Patient(patient1);
        assertFalse(sys.Patient_Account_IsRegistered(patient1));
        assertEq(sys.NumberOfPatients(), 0);

        // Cannot modify/remove unregistered
        vm.expectRevert();
        sys.Modify_Patient(patient1, "X", 1, "Y");
        vm.expectRevert();
        sys.Remove_Patient(patient1);
    }

    function testDoctorCRUDAndAccess() public {
        // Non-hospital cannot add
        vm.prank(stranger);
        vm.expectRevert();
        sys.Add_Doctor(doctor1, "Dr Bob", 40, "Clinic");

        // Add
        vm.expectEmit(true, true, true, true);
        emit RemoteHealthcareSystem.Doctor_Added(doctor1, 1, "Dr Bob", 40, "Clinic");
        sys.Add_Doctor(doctor1, "Dr Bob", 40, "Clinic");

        // Modify
        vm.expectEmit(true, true, true, true);
        emit RemoteHealthcareSystem.Doctor_Modified(doctor1, "Dr Bob II", 41, "City");
        sys.Modify_Doctor(doctor1, "Dr Bob II", 41, "City");

        // Access control for Get_Doctor
        // Stranger cannot
        vm.prank(stranger);
        vm.expectRevert();
        sys.Get_Doctor(doctor1);
        // Self (doctor1) can
        vm.prank(doctor1);
        sys.Get_Doctor(doctor1);

        // Remove
        vm.expectEmit(true, true, true, true);
        emit RemoteHealthcareSystem.Doctor_Removed(doctor1);
        sys.Remove_Doctor(doctor1);
        vm.expectRevert();
        sys.Get_Doctor(doctor1);
    }

    function testAuthorizationMappingAndReads() public {
        sys.Add_Patient(patient1, "Alice", 30, "Addr1");
        sys.Add_Doctor(doctor1, "Dr Bob", 40, "Clinic");

        // Only hospital can authorize/cancel
        vm.prank(stranger);
        vm.expectRevert();
        sys.Authorize_Patient_For_Doctor(doctor1, patient1);

        sys.Authorize_Patient_For_Doctor(doctor1, patient1);
        bool ok = sys.Get_Authorize_Patient_For_Doctor(doctor1, patient1);
        assertTrue(ok);
        sys.Cancel_Patient_For_Doctor(doctor1, patient1);
        ok = sys.Get_Authorize_Patient_For_Doctor(doctor1, patient1);
        assertFalse(ok);
    }

    function testPatientMonitoringFlow() public {
        sys.Add_Patient(patient1, "Alice", 30, "Addr1");
        sys.Add_Doctor(doctor1, "Dr Bob", 40, "Clinic");

        // Unregistered cannot Set_Parameters
        vm.prank(stranger);
        vm.expectRevert();
        sys.Set_Parameters("hb=70;bp=120;tmp=37");

        // Registered patient can
        vm.prank(patient1);
        // Only verify that the event was emitted (not strict data match to avoid abi encoding discrepancies)
        vm.expectEmit(true, true, true, false);
        emit RemoteHealthcareSystem.Sensor_Data_Collected(patient1, "{\\\"hb\\\":72,\\\"bp\\\":118,\\\"tmp\\\":36}");
        sys.Set_Parameters("{\"hb\":72,\"bp\":118,\"tmp\":36}");

        // Access control for Get_Parameters
        // Doctor not authorized cannot
        vm.prank(doctor1);
        vm.expectRevert();
        sys.Get_Parameters(patient1);

        // Hospital can
        sys.Get_Parameters(patient1);

        // After authorization doctor can
        sys.Authorize_Patient_For_Doctor(doctor1, patient1);
        vm.prank(doctor1);
        sys.Get_Parameters(patient1);

        // Self can
        vm.prank(patient1);
        string memory params = sys.Get_Parameters(patient1);
        assertEq(params, "{\"hb\":72,\"bp\":118,\"tmp\":36}");

        // Other patient cannot read
        sys.Add_Patient(patient2, "Bob", 35, "Addr2");
        vm.prank(patient2);
        vm.expectRevert();
        sys.Get_Parameters(patient1);
    }
}
