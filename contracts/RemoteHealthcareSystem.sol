// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract RemoteHealthcareSystem {

    address public Hospital;

    modifier onlyHospital() {
        require(msg.sender == Hospital);
        _;
    }

    constructor() {
        Hospital = msg.sender;
    }

    // Paitent Register Smart Contract

    uint    public NumberOfPatients;
    mapping (address => bool)   public Patient_Account_IsRegistered;
    uint    public Patient_Id;

    event Patient_Added(address _address,uint _Patient_ID,string _Patient_Name, uint8 _Patient_Age,string _Patient_Address);
    event Patient_Modified(address _address,string _Patient_Name, uint8 _Patient_Age,string _Patient_Address);
    event Patient_Removed(address _address);

    struct Patient {
        address Patient_Account;
        uint    Patient_ID;
        string  Patient_Name;
        uint8   Patient_Age;
        string  Patient_Address;
    }

    mapping (address => Patient) patients;

    function Add_Patient(address _address,string memory _Patient_Name, uint8 _Patient_Age,string memory _Patient_Address) onlyHospital public {

        require(_address != address(0));
        require(Patient_Account_IsRegistered[_address] != true);
        require(Doctor_Account_IsRegistered[_address] != true);
        Patient_Account_IsRegistered[_address] = true;

        Patient storage patient  = patients[_address];
        patient.Patient_Account = _address;
        Patient_Id++;
        patient.Patient_ID      = Patient_Id;
        patient.Patient_Name    = _Patient_Name;
        patient.Patient_Age     = _Patient_Age;
        patient.Patient_Address = _Patient_Address;

        NumberOfPatients++;

        emit Patient_Added(_address, Patient_Id,_Patient_Name,_Patient_Age,_Patient_Address);

    }

    function Modify_Patient(address _address,string memory _Patient_Name, uint8 _Patient_Age,string memory _Patient_Address) onlyHospital public {

        require(Patient_Account_IsRegistered[_address] == true);

        patients[_address].Patient_Name     = _Patient_Name;
        patients[_address].Patient_Age      = _Patient_Age;
        patients[_address].Patient_Address  = _Patient_Address;

        emit Patient_Modified(_address,_Patient_Name,_Patient_Age,_Patient_Address);

    }

    function Remove_Patient(address _address) onlyHospital public {

        require(Patient_Account_IsRegistered[_address] == true);

        Patient_Account_IsRegistered[_address] = false;
        delete patients[_address];
        NumberOfPatients--;
        emit Patient_Removed(_address);
    }

    function Get_Patient(address _address) view public returns (address, uint, string memory, uint8, string memory) {

        require(Patient_Account_IsRegistered[_address]);
        require((msg.sender == Hospital)||(listpatientfordoctors[msg.sender].Patient_Account_IsAuthorized[_address]==true)|| (msg.sender == _address));

        return (patients[_address].Patient_Account,patients[_address].Patient_ID, patients[_address].Patient_Name, patients[_address].Patient_Age, patients[_address].Patient_Address);
    }

    // Doctor Register Smart Contract

    uint    public NumberOfDoctors;
    mapping (address => bool) public Doctor_Account_IsRegistered;
    uint    public Doctor_Id;

    event Doctor_Added(address _address,uint _Doctor_ID,string _Doctor_Name, uint8 _Doctor_Age,string _Doctor_Address);
    event Doctor_Modified(address _address,string _Doctor_Name, uint8 _Doctor_Age,string _Doctor_Address);
    event Doctor_Removed(address _address);

    struct Doctor {
        address Doctor_Account;
        uint    Doctor_ID;
        string  Doctor_Name;
        uint8   Doctor_Age;
        string  Doctor_Address;
    }

    mapping (address => Doctor) doctors;

    function Add_Doctor(address _address,string memory _Doctor_Name, uint8 _Doctor_Age,string memory _Doctor_Address) onlyHospital public {

        require(_address != address(0));
        require(Doctor_Account_IsRegistered[_address] != true);
        require(Patient_Account_IsRegistered[_address] != true);
        Doctor_Account_IsRegistered[_address] = true;

        Doctor storage doctor   = doctors[_address];
        doctor.Doctor_Account   = _address;
        Doctor_Id++;
        doctor.Doctor_ID        = Doctor_Id;
        doctor.Doctor_Name      = _Doctor_Name;
        doctor.Doctor_Age       = _Doctor_Age;
        doctor.Doctor_Address   = _Doctor_Address;

        NumberOfDoctors++;
        emit Doctor_Added(_address, Doctor_Id,_Doctor_Name,_Doctor_Age,_Doctor_Address);

    }

    function Modify_Doctor(address _address,string memory _Doctor_Name, uint8 _Doctor_Age,string memory _Doctor_Address) onlyHospital public {

        require(Doctor_Account_IsRegistered[_address] == true);

        doctors[_address].Doctor_Name       = _Doctor_Name;
        doctors[_address].Doctor_Age        = _Doctor_Age;
        doctors[_address].Doctor_Address    = _Doctor_Address;

        emit Doctor_Modified(_address,_Doctor_Name,_Doctor_Age,_Doctor_Address);

    }
    function Remove_Doctor(address _address) onlyHospital public {

        require(Doctor_Account_IsRegistered[_address] == true);
        Doctor_Account_IsRegistered[_address] = false;
        delete doctors[_address];
        emit Doctor_Removed(_address);
    }
    function Get_Doctor(address _address) view public returns (address, uint, string memory, uint8, string memory) {
        require( Doctor_Account_IsRegistered[_address]);
        require((msg.sender == Hospital)||(msg.sender == _address));
        return (doctors[_address].Doctor_Account,doctors[_address].Doctor_ID, doctors[_address].Doctor_Name, doctors[_address].Doctor_Age, doctors[_address].Doctor_Address);
    }

    // Authorized Patient for Doctor Smart Contract

    struct ListPatientForDoctor {
        mapping (address => bool)  Patient_Account_IsAuthorized;
    }
    mapping (address => ListPatientForDoctor) listpatientfordoctors;

    function Authorize_Patient_For_Doctor (address _Doctor_address,address _Patient_address) onlyHospital public {

        require(Patient_Account_IsRegistered[_Patient_address] == true);
        require(Doctor_Account_IsRegistered[_Doctor_address] == true);

        ListPatientForDoctor storage listpatientfordoctor = listpatientfordoctors[_Doctor_address];
        listpatientfordoctor.Patient_Account_IsAuthorized[_Patient_address] = true;
    }

    function Cancel_Patient_For_Doctor (address _Doctor_address,address _Patient_address) onlyHospital public {

        require(Patient_Account_IsRegistered[_Patient_address] == true);
        require(Doctor_Account_IsRegistered[_Doctor_address] == true);

        ListPatientForDoctor storage listpatientfordoctor = listpatientfordoctors[_Doctor_address];
        listpatientfordoctor.Patient_Account_IsAuthorized[_Patient_address] = false;
    }

    function Get_Authorize_Patient_For_Doctor (address _Doctor_address,address _Patient_address) onlyHospital view public returns(bool) {

        require(Patient_Account_IsRegistered[_Patient_address] == true);
        require(Doctor_Account_IsRegistered[_Doctor_address] == true);

        return (listpatientfordoctors[_Doctor_address].Patient_Account_IsAuthorized[_Patient_address]);
    }

    // New: Patient self authorize / revoke doctor (RBAC)
    event Doctor_Access_Updated(address indexed patient, address indexed doctor, bool allowed);

    // Patient Monitoring Smart Contract

    modifier onlyPatient() {
        require(Patient_Account_IsRegistered[msg.sender] == true);
        _;
    }

    function Authorize_Doctor(address doctor, bool allowed) external onlyPatient {
        require(Doctor_Account_IsRegistered[doctor] == true, "Doctor not registered");
        listpatientfordoctors[doctor].Patient_Account_IsAuthorized[msg.sender] = allowed;
        emit Doctor_Access_Updated(msg.sender, doctor, allowed); 
    }

    // helper view: can check
    function IsDoctorAuthorizedForPatient(address doctor, address patient) external view returns (bool) {
        if (!Doctor_Account_IsRegistered[doctor]) return false;
        if (!Patient_Account_IsRegistered[patient]) return false;
        return listpatientfordoctors[doctor].Patient_Account_IsAuthorized[patient];
    }

    event Sensor_Data_Collected (address _Patient_Account, string _Parameters);
    event Alert_Patient_HeartBeat(address _address);
    event Alert_Patient_BloodPressure(address _address);
    event Alert_Patient_Temperature(address _address);

    struct Patient_Monitoring {
        address     Patient_Account;
        string      Parameters; // free-form parameters payload (e.g., JSON or CSV)
    }

    mapping (address => Patient_Monitoring) patients_monitoring;

    function Set_Parameters(string memory _Parameters) onlyPatient public{

        Patient_Monitoring storage patient_monitoring = patients_monitoring[msg.sender];
        patient_monitoring.Patient_Account  = msg.sender;
        patient_monitoring.Parameters       = _Parameters;
        emit Sensor_Data_Collected (msg.sender, _Parameters);

    }
    
    function Get_Parameters(address _address) view public returns (string memory) {

        require((msg.sender == Hospital)||(listpatientfordoctors[msg.sender].Patient_Account_IsAuthorized[_address]==true)|| (msg.sender == _address));

        return (patients_monitoring[_address].Parameters);
    }

    // IPFS-based Storage (Minimal On-chain)
    struct MinimalRecord {
        address patient;    // owner of record
        string cid;         // IPFS CID (bafy...)
        uint256 timestamp;  // client timestamp
        bytes signature;    // patient signature
    }

    // Key: Pseudonym (R_i - bytes32), Value: minimal record
    mapping(bytes32 => MinimalRecord) public dataRecords;

    // Key: patient's wallet => latest pseudonym ID used
    mapping(address => bytes32) public latestAnonId;

    event Record_Stored(address indexed patient, bytes32 indexed anonId, string cid, uint256 timestamp);

    function _toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    function _recoverSigner(bytes32 ethSignedHash, bytes memory sig) internal pure returns (address) {
        require(sig.length == 65, "Invalid signature length");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(sig, 0x20))
            s := mload(add(sig, 0x40))
            v := byte(0, mload(add(sig, 0x60)))
        }

        if (v < 27) v += 27;
        require(v == 27 || v == 28, "Invalid v");

        return ecrecover(ethSignedHash, v, r, s);
    }

    // Sendata, called by Patient. Not use onlyOwner/onlyHospital.
    function setParameters(
        bytes32 _anonId,
        string calldata _cid,
        uint256 _timestamp,
        bytes calldata _signature
    ) external onlyPatient {
        require(bytes(_cid).length > 0, "Empty CID");

        // domain separation (chống replay)
        bytes32 cidDigest = keccak256(bytes(_cid));
        bytes32 msgHash = keccak256(
            abi.encodePacked(_anonId, cidDigest, _timestamp, address(this), block.chainid)
        );

        bytes32 ethSigned = _toEthSignedMessageHash(msgHash);
        address signer = _recoverSigner(ethSigned, _signature);
        require(signer == msg.sender, "Bad signature");

        dataRecords[_anonId] = MinimalRecord({
            patient: msg.sender,
            cid: _cid,
            timestamp: _timestamp,
            signature: _signature
        });

        latestAnonId[msg.sender] = _anonId;

        emit Record_Stored(msg.sender, _anonId, _cid, _timestamp);
    }

    // Query the most patient data by patient wallet address
    // Return: (anonId, heartBeat, bloodPressure, temperature)
    function getParameters(address _patientAccount)
        public
        view
        returns (bytes32, string memory, uint256)
    {
        require(
            (msg.sender == Hospital) ||
            (listpatientfordoctors[msg.sender].Patient_Account_IsAuthorized[_patientAccount] == true) ||
            (msg.sender == _patientAccount),
            "Unauthorized access."
        );

        bytes32 anonId = latestAnonId[_patientAccount];
        MinimalRecord storage r = dataRecords[anonId];
        return (anonId, r.cid, r.timestamp);
    }


    // function to query history data using AnonID
    // Query historical data using Pseudonym (R_i). Backend Doctor will call this function.
    // RBAC: RBAC is "truly" historically accurate according to anonId.
    function getDataByAnonId(bytes32 _anonId)
        public
        view
        returns (string memory, uint256, bytes memory)
    {
        MinimalRecord storage r = dataRecords[_anonId];
        require(r.timestamp != 0, "Record not found. No record");
        
        // Hospital can watch all
        if (msg.sender == Hospital) {
            return (r.cid, r.timestamp, r.signature);
        }

        // Patient watch record of self only
        if (msg.sender == r.patient) {
            return (r.cid, r.timestamp, r.signature);
        }

        // Doctor have to register + was authorized by patient at that time

        require(Doctor_Account_IsRegistered[msg.sender] == true, "Only Hospital/Doctor/Patient");
        require(
            listpatientfordoctors[msg.sender].Patient_Account_IsAuthorized[r.patient] == true,
            "Doctor not authorized for this patient."
        );
        return (r.cid, r.timestamp, r.signature);
    }
}
