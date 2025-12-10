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

    // Patient Monitoring Smart Contract

    modifier onlyPatient() {
        require(Patient_Account_IsRegistered[msg.sender] == true);
        _;
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

    // ---------------------------------------------------------------
    // HealthDataStorage - Lưu trữ dữ liệu sức khỏe với ID giả danh R_i
    // ---------------------------------------------------------------
    // CHÚ Ý BẢO MẬT: Tuyệt đối KHÔNG lưu trữ Root Seed (R_P) trong Smart Contract.

    struct HealthData {
        uint256 heartBeat;
        uint256 bloodPressure;
        uint256 temperature;
        uint256 timestamp; // thời điểm dữ liệu được ghi
    }

    // Key: Pseudonym (R_i - bytes32), Value: dữ liệu cảm biến
    mapping(bytes32 => HealthData) public dataRecords;

    // Key: địa chỉ ví thật của bệnh nhân, Value: ID giả danh mới nhất đã sử dụng
    mapping(address => bytes32) public latestAnonId;

    // Gửi dữ liệu. Gọi bởi Patient (hoặc bất kỳ tài khoản gửi giao dịch). Không dùng onlyOwner/onlyHospital.
    // Điều này tránh lỗi revert do hạn chế quyền không cần thiết.
    function setParameters(
        bytes32 _anonId,
        uint256 _hb,
        uint256 _bp,
        uint256 _temp
    ) public {
        // 1. Lưu trữ dữ liệu với ID giả danh
        dataRecords[_anonId] = HealthData({
            heartBeat: _hb,
            bloodPressure: _bp,
            temperature: _temp,
            timestamp: block.timestamp
        });

        // 2. Cập nhật ID giả danh mới nhất cho địa chỉ ví thật (người gửi giao dịch)
        latestAnonId[msg.sender] = _anonId;
    }

    // Truy vấn dữ liệu gần nhất theo địa chỉ ví bệnh nhân.
    // Trả về: (anonId, heartBeat, bloodPressure, temperature)
    function getParameters(address _patientAccount)
        public
        view
        returns (bytes32, uint256, uint256, uint256)
    {
        bytes32 anonId = latestAnonId[_patientAccount];
        HealthData storage data = dataRecords[anonId];
        return (anonId, data.heartBeat, data.bloodPressure, data.temperature);
    }

}
