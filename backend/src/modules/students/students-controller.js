const asyncHandler = require("express-async-handler");
const { getAllStudents, addNewStudent, getStudentDetail, setStudentStatus, updateStudent, removeStudent } = require("./students-service");

const toFlatStudentPayload = (body) => {
    if (!body) return body;
    if (body.basicDetails || body.contactDetails || body.guardianInfo || body.academicInfo) {
        const { basicDetails = {}, contactDetails = {}, guardianInfo = {}, academicInfo = {} } = body;
        return {
            userId: body.userId,
            name: basicDetails.name,
            email: basicDetails.email,
            gender: contactDetails.gender,
            phone: contactDetails.phone,
            dob: contactDetails.dob,
            currentAddress: contactDetails.currentAddress,
            permanentAddress: contactDetails.permanentAddress,
            fatherName: guardianInfo.fatherName,
            fatherPhone: guardianInfo.fatherPhone,
            motherName: guardianInfo.motherName,
            motherPhone: guardianInfo.motherPhone,
            guardianName: guardianInfo.guardianName,
            guardianPhone: guardianInfo.guardianPhone,
            relationOfGuardian: guardianInfo.relationOfGuardian,
            systemAccess: basicDetails.systemAccess,
            class: academicInfo.class,
            section: academicInfo.section,
            admissionDate: academicInfo.admissionDate,
            roll: academicInfo.roll,
        };
    }
    return body;
};

const handleGetAllStudents = asyncHandler(async (req, res) => {
    const { name, className, section, roll } = req.query;
    const students = await getAllStudents({ name, className, section, roll });
    res.json({ students });
});

const handleAddStudent = asyncHandler(async (req, res) => {
    const payload = toFlatStudentPayload(req.body);
    const message = await addNewStudent(payload);
    res.json(message);
});

const handleUpdateStudent = asyncHandler(async (req, res) => {
    const { id: userId } = req.params;
    const flat = toFlatStudentPayload(req.body);
    const message = await updateStudent({ ...flat, userId: Number(userId) });
    res.json(message);
});

const handleGetStudentDetail = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const student = await getStudentDetail(id);
    res.json(student);
});

const handleStudentStatus = asyncHandler(async (req, res) => {
    const { id: userId } = req.params;
    const { id: reviewerId } = req.user;
    const payload = req.body;
    const message = await setStudentStatus({ ...payload, userId, reviewerId });
    res.json(message);
});

const handleDeleteStudent = asyncHandler(async (req, res) => {
    const { id } = req.params;
    const message = await removeStudent(id);
    res.json(message);
});

module.exports = {
    handleGetAllStudents,
    handleGetStudentDetail,
    handleAddStudent,
    handleStudentStatus,
    handleUpdateStudent,
    handleDeleteStudent,
};
