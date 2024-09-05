// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface IReputationContract {
    function reputation(address user) external view returns (uint256);
}

contract DecentralLearning is Ownable, Pausable {
    IReputationContract public reputationContract;

    uint256 public constant ENROLL_THRESHOLD = 5;
    uint256 public constant POST_THRESHOLD = 50;
    uint256 public constant STUDENT_REWARD_AMOUNT = 10 ether; // 10 MAND tokens
    uint256 public constant CREATOR_REWARD_AMOUNT = 1 ether; // 1 MAND token per passed student

    struct Course {
        address creator;
        string metadataURI;
        bool approved;
        uint256 passedStudents;
        uint256 totalRewarded;
        uint256 totalEnrolled;
    }

    struct Quiz {
        uint256 courseId;
        string question;
        string optionA;
        string optionB;
        string optionC;
        string optionD;
        bytes32 correctAnswerHash; // Hashed correct answer ("A", "B", "C", or "D")
    }

    struct Enrollment {
        bool isEnrolled;
        uint8 attemptCount;
        bool hasPassed;
        bool hasClaimedReward;
    }

    mapping(uint256 => Course) public courses;
    mapping(address => mapping(uint256 => Enrollment)) public enrollments;
    mapping(uint256 => Quiz[]) public courseQuizzes; // Mapping from course ID to array of quizzes
    uint256 public courseCount;

    event CourseCreated(uint256 indexed courseId, address indexed creator);
    event CourseApproved(uint256 indexed courseId);
    event QuizCreated(uint256 indexed courseId, uint256 quizId);
    event UserEnrolled(uint256 indexed courseId, address indexed user);
    event QuizAttempted(uint256 indexed courseId, address indexed user, bool passed);
    event RewardClaimed(uint256 indexed courseId, address indexed user, uint256 amount);
    event CreatorRewardClaimed(uint256 indexed courseId, address indexed creator, uint256 amount);
    event CreatorWithdrawal(uint256 indexed courseId, address indexed creator, uint256 amount);

    constructor(address _reputationContract) Ownable(msg.sender) {
        reputationContract = IReputationContract(_reputationContract);
    }

    function createCourse(string memory _metadataURI) external whenNotPaused {
        require(reputationContract.reputation(msg.sender) >= POST_THRESHOLD, "Insufficient reputation to create course");
        uint256 courseId = courseCount++;
        courses[courseId] = Course(msg.sender, _metadataURI, false, 0, 0, 0);
        emit CourseCreated(courseId, msg.sender);
    }

    function approveCourse(uint256 _courseId) external onlyOwner {
        require(!courses[_courseId].approved, "Course already approved");
        courses[_courseId].approved = true;
        emit CourseApproved(_courseId);
    }

    function enrollInCourse(uint256 _courseId) external whenNotPaused {
        require(reputationContract.reputation(msg.sender) >= ENROLL_THRESHOLD, "Insufficient reputation to enroll");
        require(courses[_courseId].approved, "Course not approved");
        require(!enrollments[msg.sender][_courseId].isEnrolled, "Already enrolled");

        enrollments[msg.sender][_courseId].isEnrolled = true;
        courses[_courseId].totalEnrolled++;
        emit UserEnrolled(_courseId, msg.sender);
    }

    function createQuiz(
        uint256 _courseId,
        string memory _question,
        string memory _optionA,
        string memory _optionB,
        string memory _optionC,
        string memory _optionD,
        string memory _correctAnswer
    ) external {
        require(msg.sender == courses[_courseId].creator, "Only course creator can create a quiz");
        require(courses[_courseId].approved, "Course must be approved to create a quiz");
        require(
            keccak256(abi.encodePacked(_correctAnswer)) == keccak256(abi.encodePacked("A")) ||
            keccak256(abi.encodePacked(_correctAnswer)) == keccak256(abi.encodePacked("B")) ||
            keccak256(abi.encodePacked(_correctAnswer)) == keccak256(abi.encodePacked("C")) ||
            keccak256(abi.encodePacked(_correctAnswer)) == keccak256(abi.encodePacked("D")),
            "Invalid correct answer"
        );

        Quiz memory newQuiz = Quiz({
            courseId: _courseId,
            question: _question,
            optionA: _optionA,
            optionB: _optionB,
            optionC: _optionC,
            optionD: _optionD,
            correctAnswerHash: keccak256(abi.encodePacked(_correctAnswer))
        });

        courseQuizzes[_courseId].push(newQuiz);
        uint256 quizId = courseQuizzes[_courseId].length - 1;
        emit QuizCreated(_courseId, quizId);
    }

    function attemptQuiz(uint256 _courseId, string[] memory _answers) external {
        Enrollment storage enrollment = enrollments[msg.sender][_courseId];
        require(enrollment.isEnrolled, "User not enrolled in this course");
        require(enrollment.attemptCount < 2, "Maximum attempts reached");
        require(!enrollment.hasPassed, "User has already passed this course");

        enrollment.attemptCount++;
        Quiz[] memory quizzes = courseQuizzes[_courseId];
        require(_answers.length == quizzes.length, "Answer count mismatch");

        bool passed = true;

        for (uint256 i = 0; i < quizzes.length; i++) {
            if (keccak256(abi.encodePacked(_answers[i])) != quizzes[i].correctAnswerHash) {
                passed = false;
                break;
            }
        }

        if (passed) {
            enrollment.hasPassed = true;
            courses[_courseId].passedStudents++;
        }

        emit QuizAttempted(_courseId, msg.sender, passed);
    }

    function claimStudentReward(uint256 _courseId) external whenNotPaused {
        Enrollment storage enrollment = enrollments[msg.sender][_courseId];
        require(enrollment.hasPassed, "Course not passed");
        require(!enrollment.hasClaimedReward, "Reward already claimed");

        enrollment.hasClaimedReward = true;
        courses[_courseId].totalRewarded += STUDENT_REWARD_AMOUNT;

        (bool success, ) = payable(msg.sender).call{value: STUDENT_REWARD_AMOUNT}("");
        require(success, "Failed to send MAND");

        emit RewardClaimed(_courseId, msg.sender, STUDENT_REWARD_AMOUNT);
    }

    function claimCreatorReward(uint256 _courseId) external whenNotPaused {
        Course storage course = courses[_courseId];
        require(msg.sender == course.creator, "Only course creator can claim reward");
        require(course.approved, "Course not approved");

        uint256 rewardAmount = course.passedStudents * CREATOR_REWARD_AMOUNT;
        course.passedStudents = 0; // Reset passed students count
        course.totalRewarded += rewardAmount;

        (bool success, ) = payable(msg.sender).call{value: rewardAmount}("");
        require(success, "Failed to send MAND");

        emit CreatorRewardClaimed(_courseId, msg.sender, rewardAmount);
    }

    function withdrawCreatorTokens(uint256 _courseId, uint256 _amount) external whenNotPaused {
        Course storage course = courses[_courseId];
        require(msg.sender == course.creator, "Only course creator can withdraw tokens");
        require(course.totalRewarded >= _amount, "Insufficient rewarded tokens to withdraw");

        course.totalRewarded -= _amount;
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        require(success, "Failed to send MAND");

        emit CreatorWithdrawal(_courseId, msg.sender, _amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function updateReputationContract(address _newReputationContract) external onlyOwner {
        reputationContract = IReputationContract(_newReputationContract);
    }

    function withdrawExcessTokens(uint256 _amount) external onlyOwner {
        (bool success, ) = payable(owner()).call{value: _amount}("");
        require(success, "Failed to withdraw tokens");
    }

    // Function to receive MAND (required for the contract to receive MAND)
    receive() external payable {}
}