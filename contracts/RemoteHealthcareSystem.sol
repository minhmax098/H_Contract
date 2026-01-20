// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract RemoteHealthcareSystem {

    // Custom errors (saves gas vs require strings)
    error Unauthorized();
    error InvalidAddress();
    error AlreadyRegistered();
    error NotRegistered();
    error EmptyCID();
    error InvalidSignatureLength();
    error InvalidSignature();
    error RecordNotFound();

    address public Hospital;

    modifier onlyHospital() {
        if (msg.sender != Hospital) revert Unauthorized();
        _;
    }

    constructor() {
        Hospital = msg.sender;
    }

    // Paitent Register Smart Contract
    uint128 public NumberOfPatients;
    uint128 public Patient_Id;

    event Patient_Added(address indexed _address, uint256 _Patient_ID, string _Patient_Name, uint8 _Patient_Age, string _Patient_Address);
    event Patient_Modified(address indexed _address, string _Patient_Name, uint8 _Patient_Age, string _Patient_Address);
    event Patient_Removed(address indexed _address);

    struct Patient {
        address Patient_Account; // 20 bytes
        uint8 Patient_Age;       // 1 byte
        uint32 Patient_ID;      // 4 bytes - total 25 bytes, fits in 1 slot
        string Patient_Name;
        string Patient_Address;
    }

    mapping(address => Patient) patients;

    function Add_Patient(address _address, string calldata _Patient_Name, uint8 _Patient_Age, string calldata _Patient_Address) onlyHospital external {
        if (_address == address(0)) revert InvalidAddress();
        if (patients[_address].Patient_ID != 0) revert AlreadyRegistered();
        if (doctors[_address].Doctor_ID != 0) revert AlreadyRegistered();

        uint32 newPatientId;
        unchecked {
            newPatientId = uint32(++Patient_Id);
            ++NumberOfPatients;
        }

        Patient storage patient = patients[_address];
        patient.Patient_Account = _address;
        patient.Patient_ID = newPatientId;
        patient.Patient_Name = _Patient_Name;
        patient.Patient_Age = _Patient_Age;
        patient.Patient_Address = _Patient_Address;

        emit Patient_Added(_address, newPatientId, _Patient_Name, _Patient_Age, _Patient_Address);
    }

    function Modify_Patient(address _address, string calldata _Patient_Name, uint8 _Patient_Age, string calldata _Patient_Address) onlyHospital external {
        if (patients[_address].Patient_ID == 0) revert NotRegistered();

        Patient storage patient = patients[_address];
        patient.Patient_Name = _Patient_Name;
        patient.Patient_Age = _Patient_Age;
        patient.Patient_Address = _Patient_Address;

        emit Patient_Modified(_address, _Patient_Name, _Patient_Age, _Patient_Address);
    }

    function Remove_Patient(address _address) onlyHospital external {
        if (patients[_address].Patient_ID == 0) revert NotRegistered();

        delete patients[_address];
        unchecked {
            --NumberOfPatients;
        }
        emit Patient_Removed(_address);
    }

    function Get_Patient(address _address) view external returns (address, uint256, string memory, uint8, string memory) {
        if (patients[_address].Patient_ID == 0) revert NotRegistered();
        if (!((msg.sender == Hospital) || (listpatientfordoctors[msg.sender].Patient_Account_IsAuthorized[_address]) || (msg.sender == _address))) {
            revert Unauthorized();
        }

        Patient storage patient = patients[_address];
        return (patient.Patient_Account, uint256(patient.Patient_ID), patient.Patient_Name, patient.Patient_Age, patient.Patient_Address);
    }

    // Doctor Register Smart Contract
    uint128 public NumberOfDoctors;
    uint128 public Doctor_Id;

    event Doctor_Added(address indexed _address, uint256 _Doctor_ID, string _Doctor_Name, uint8 _Doctor_Age, string _Doctor_Address);
    event Doctor_Modified(address indexed _address, string _Doctor_Name, uint8 _Doctor_Age, string _Doctor_Address);
    event Doctor_Removed(address indexed _address);

    struct Doctor {
        address Doctor_Account; // 20 bytes
        uint8 Doctor_Age;       // 1 byte
        uint32 Doctor_ID;       // 4 bytes - fits in 1 slot
        string Doctor_Name;
        string Doctor_Address;
    }

    mapping(address => Doctor) doctors;

    function Add_Doctor(address _address, string calldata _Doctor_Name, uint8 _Doctor_Age, string calldata _Doctor_Address) onlyHospital external {
        if (_address == address(0)) revert InvalidAddress();
        if (doctors[_address].Doctor_ID != 0) revert AlreadyRegistered();
        if (patients[_address].Patient_ID != 0) revert AlreadyRegistered();

        uint32 newDoctorId;
        unchecked {
            newDoctorId = uint32(++Doctor_Id);
            ++NumberOfDoctors;
        }

        Doctor storage doctor = doctors[_address];
        doctor.Doctor_Account = _address;
        doctor.Doctor_ID = newDoctorId;
        doctor.Doctor_Name = _Doctor_Name;
        doctor.Doctor_Age = _Doctor_Age;
        doctor.Doctor_Address = _Doctor_Address;

        emit Doctor_Added(_address, newDoctorId, _Doctor_Name, _Doctor_Age, _Doctor_Address);
    }

    function Modify_Doctor(address _address, string calldata _Doctor_Name, uint8 _Doctor_Age, string calldata _Doctor_Address) onlyHospital external {
        if (doctors[_address].Doctor_ID == 0) revert NotRegistered();

        Doctor storage doctor = doctors[_address];
        doctor.Doctor_Name = _Doctor_Name;
        doctor.Doctor_Age = _Doctor_Age;
        doctor.Doctor_Address = _Doctor_Address;

        emit Doctor_Modified(_address, _Doctor_Name, _Doctor_Age, _Doctor_Address);
    }

    function Remove_Doctor(address _address) onlyHospital external {
        if (doctors[_address].Doctor_ID == 0) revert NotRegistered();

        delete doctors[_address];
        unchecked {
            --NumberOfDoctors;
        }
        emit Doctor_Removed(_address);
    }

    function Get_Doctor(address _address) view external returns (address, uint256, string memory, uint8, string memory) {
        if (doctors[_address].Doctor_ID == 0) revert NotRegistered();
        if (!((msg.sender == Hospital) || (msg.sender == _address))) revert Unauthorized();

        Doctor storage doctor = doctors[_address];
        return (doctor.Doctor_Account, uint256(doctor.Doctor_ID), doctor.Doctor_Name, doctor.Doctor_Age, doctor.Doctor_Address);
    }

    // Authorized Patient for Doctor Smart Contract
    struct ListPatientForDoctor {
        mapping(address => bool) Patient_Account_IsAuthorized;
    }
    mapping(address => ListPatientForDoctor) listpatientfordoctors;

    function Authorize_Patient_For_Doctor(address _Doctor_address, address _Patient_address) onlyHospital external {
        if (patients[_Patient_address].Patient_ID == 0) revert NotRegistered();
        if (doctors[_Doctor_address].Doctor_ID == 0) revert NotRegistered();

        listpatientfordoctors[_Doctor_address].Patient_Account_IsAuthorized[_Patient_address] = true;
    }

    function Cancel_Patient_For_Doctor(address _Doctor_address, address _Patient_address) onlyHospital external {
        if (patients[_Patient_address].Patient_ID == 0) revert NotRegistered();
        if (doctors[_Doctor_address].Doctor_ID == 0) revert NotRegistered();

        listpatientfordoctors[_Doctor_address].Patient_Account_IsAuthorized[_Patient_address] = false;
    }

    function Get_Authorize_Patient_For_Doctor(address _Doctor_address, address _Patient_address) onlyHospital view external returns (bool) {
        if (patients[_Patient_address].Patient_ID == 0) revert NotRegistered();
        if (doctors[_Doctor_address].Doctor_ID == 0) revert NotRegistered();

        return listpatientfordoctors[_Doctor_address].Patient_Account_IsAuthorized[_Patient_address];
    }

    // New: Patient self authorize / revoke doctor (RBAC)
    event Doctor_Access_Updated(address indexed patient, address indexed doctor, bool allowed);

    // Patient Monitoring Smart Contract

    modifier onlyPatient() {
        if (patients[msg.sender].Patient_ID == 0) revert Unauthorized();
        _;
    }

    function Authorize_Doctor(address doctor, bool allowed) external onlyPatient {
        if (doctors[doctor].Doctor_ID == 0) revert NotRegistered();
        listpatientfordoctors[doctor].Patient_Account_IsAuthorized[msg.sender] = allowed;
        emit Doctor_Access_Updated(msg.sender, doctor, allowed);
    }

    // helper view: can check
    function IsDoctorAuthorizedForPatient(address doctor, address patient) external view returns (bool) {
        if (doctors[doctor].Doctor_ID == 0) return false;
        if (patients[patient].Patient_ID == 0) return false;
        return listpatientfordoctors[doctor].Patient_Account_IsAuthorized[patient];
    }

    event Sensor_Data_Collected(address indexed _Patient_Account, string _Parameters);
    event Alert_Patient_HeartBeat(address indexed _address);
    event Alert_Patient_BloodPressure(address indexed _address);
    event Alert_Patient_Temperature(address indexed _address);

    struct Patient_Monitoring {
        string Parameters; // free-form parameters payload (e.g., JSON or CSV)
    }

    mapping(address => Patient_Monitoring) patients_monitoring;

    function Set_Parameters(string calldata _Parameters) external onlyPatient {
        patients_monitoring[msg.sender].Parameters = _Parameters;
        emit Sensor_Data_Collected(msg.sender, _Parameters);
    }

    function Get_Parameters(address _address) external view returns (string memory) {
        if (!((msg.sender == Hospital) || (listpatientfordoctors[msg.sender].Patient_Account_IsAuthorized[_address]) || (msg.sender == _address))) {
            revert Unauthorized();
        }

        return (patients_monitoring[_address].Parameters);
    }

    // IPFS-based Storage (Minimal On-chain)
    struct MinimalRecord {
        address patient; // owner of record
        string cid;      // IPFS CID (bafy...)
        uint256 timestamp; // client timestamp
        bytes signature; // patient signature
    }

    // Key: Pseudonym (R_i - bytes32), Value: minimal record
    mapping(bytes32 => MinimalRecord) public dataRecords;

    // Key: patient's wallet => latest pseudonym ID used
    mapping(address => bytes32) public latestAnonId;

    mapping(address => uint256) public nonces;

    event Record_Stored(address indexed patient, bytes32 indexed anonId, string cid, uint256 timestamp);

    function _toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    function _recoverSigner(bytes32 ethSignedHash, bytes memory sig) internal pure returns (address) {
        if (sig.length != 65) revert InvalidSignatureLength();

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(sig, 0x20))
            s := mload(add(sig, 0x40))
            v := byte(0, mload(add(sig, 0x60)))
        }

        if (v < 27) v += 27;
        if (v != 27 && v != 28) revert InvalidSignature();

        return ecrecover(ethSignedHash, v, r, s);
    }

    // Sendata, called by Patient. Not use onlyOwner/onlyHospital.
    function setParameters(bytes32 _anonId, string calldata _cid, uint256 _timestamp, bytes calldata _signature) external onlyPatient {
        if (bytes(_cid).length == 0) revert EmptyCID();

        // domain separation (chống replay)
        bytes32 cidDigest = keccak256(bytes(_cid));
        bytes32 msgHash = keccak256(abi.encodePacked(_anonId, cidDigest, _timestamp, address(this), block.chainid));

        bytes32 ethSigned = _toEthSignedMessageHash(msgHash);
        address signer = _recoverSigner(ethSigned, _signature);
        if (signer != msg.sender) revert InvalidSignature();

        dataRecords[_anonId] = MinimalRecord({patient: msg.sender, cid: _cid, timestamp: _timestamp, signature: _signature});

        latestAnonId[msg.sender] = _anonId;

        emit Record_Stored(msg.sender, _anonId, _cid, _timestamp);
    }

    function setParametersMeta(
        address patient,
        bytes32 _anonId,
        string calldata _cid,
        uint256 _timestamp,
        uint256 nonce,
        bytes calldata _signature
    ) external {
        if (patients[patient].Patient_ID == 0) revert NotRegistered();
        if (bytes(_cid).length == 0) revert EmptyCID();
        if (nonce != nonces[patient]) revert InvalidSignature(); // hoặc custom error InvalidNonce()

        bytes32 cidDigest = keccak256(bytes(_cid));
        bytes32 msgHash = keccak256(
            abi.encodePacked(patient, _anonId, cidDigest, _timestamp, nonce, address(this), block.chainid)
        );

        bytes32 ethSigned = _toEthSignedMessageHash(msgHash);
        address signer = _recoverSigner(ethSigned, _signature);
        if (signer != patient) revert InvalidSignature();

        // consume nonce
        unchecked { nonces[patient] = nonce + 1; }

        dataRecords[_anonId] = MinimalRecord({
            patient: patient,
            cid: _cid,
            timestamp: _timestamp,
            signature: _signature
        });

        latestAnonId[patient] = _anonId;

        emit Record_Stored(patient, _anonId, _cid, _timestamp);
    }

    // Query the most patient data by patient wallet address
    // Return: (anonId, heartBeat, bloodPressure, temperature)
    function getParameters(address _patientAccount) external view returns (bytes32, string memory, uint256) {
        if (!((msg.sender == Hospital) || (listpatientfordoctors[msg.sender].Patient_Account_IsAuthorized[_patientAccount]) || (msg.sender == _patientAccount))) {
            revert Unauthorized();
        }

        bytes32 anonId = latestAnonId[_patientAccount];
        MinimalRecord storage r = dataRecords[anonId];
        return (anonId, r.cid, r.timestamp);
    }

    // function to query history data using AnonID
    // Query historical data using Pseudonym (R_i). Backend Doctor will call this function.
    // RBAC: RBAC is "truly" historically accurate according to anonId.
    function getDataByAnonId(bytes32 _anonId) external view returns (string memory, uint256, bytes memory) {
        MinimalRecord storage r = dataRecords[_anonId];
        if (r.timestamp == 0) revert RecordNotFound();

        // Hospital can watch all
        if (msg.sender == Hospital) {
            return (r.cid, r.timestamp, r.signature);
        }

        // Patient watch record of self only
        if (msg.sender == r.patient) {
            return (r.cid, r.timestamp, r.signature);
        }

        // Doctor have to register + was authorized by patient at that time
        if (doctors[msg.sender].Doctor_ID == 0) revert Unauthorized();
        if (!listpatientfordoctors[msg.sender].Patient_Account_IsAuthorized[r.patient]) revert Unauthorized();

        return (r.cid, r.timestamp, r.signature);
    }
}
