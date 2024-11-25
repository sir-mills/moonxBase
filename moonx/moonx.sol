// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

interface IReputationContract {
    function reputation(address user) external view returns (uint256);
}

contract DecentralLearning is Ownable, Pausable {
    IReputationContract public reputationContract;

    uint256 public enrollThreshold;
    uint256 public postThreshold;
    uint256 public studentRewardAmount;
    uint256 public creatorRewardAmount;
    uint256 public platformTx; 
    uint256 public constant WITHDRAWAL_INTERVAL = 31 days;

    uint256 public lastWithdrawalTime;
    uint256 public accumulatedFees;

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
    event CreatorWithdrawal(uint256 indexed courseId, address indexed creator, uint256 amount);
    event GasFeesWithdrawn(uint256 amount);

    constructor(address _reputationContract) Ownable(msg.sender) {
        reputationContract = IReputationContract(_reputationContract);
        lastWithdrawalTime = block.timestamp;
        enrollThreshold = 1 ether;
        postThreshold = 5 ether;
        studentRewardAmount = 10 ether;
        creatorRewardAmount = 1 ether;
        platformTx = 0.75 ether;
    }

    modifier COLLECTPLATFORMTX() {
        require(msg.value >= platformTx, "Insufficient gas fee");
        accumulatedFees += platformTx;
        uint256 excess = msg.value - platformTx;
        if (excess > 0) {
            payable(msg.sender).transfer(excess);
        }
        _;
    }

   function createCourse(
        string memory _metadataURI,
        string[] memory _questions,
        string[] memory _optionAs,
        string[] memory _optionBs,
        string[] memory _optionCs,
        string[] memory _optionDs,
        string[] memory _correctAnswers
    ) external payable whenNotPaused COLLECTPLATFORMTX {
        require(reputationContract.reputation(msg.sender) >= postThreshold, "Insufficient reputation to create course");
        require(_questions.length == 5 && _questions.length == _optionAs.length &&
                _questions.length == _optionBs.length && _questions.length == _optionCs.length &&
                _questions.length == _optionDs.length && _questions.length == _correctAnswers.length, 
                "Invalid quiz data");

        uint256 courseId = courseCount++;
        courses[courseId] = Course(msg.sender, _metadataURI, false, 0, 0, 0);
        
        // Store quizzes
        for (uint256 i = 0; i < _questions.length; i++) {
            require(
                keccak256(abi.encodePacked(_correctAnswers[i])) == keccak256(abi.encodePacked("A")) ||
                keccak256(abi.encodePacked(_correctAnswers[i])) == keccak256(abi.encodePacked("B")) ||
                keccak256(abi.encodePacked(_correctAnswers[i])) == keccak256(abi.encodePacked("C")) ||
                keccak256(abi.encodePacked(_correctAnswers[i])) == keccak256(abi.encodePacked("D")),
                "Invalid correct answer"
            );

            Quiz memory newQuiz = Quiz({
                courseId: courseId,
                question: _questions[i],
                optionA: _optionAs[i],
                optionB: _optionBs[i],
                optionC: _optionCs[i],
                optionD: _optionDs[i],
                correctAnswerHash: keccak256(abi.encodePacked(_correctAnswers[i]))
            });

            courseQuizzes[courseId].push(newQuiz);
        }

        emit CourseCreated(courseId, msg.sender);
    }

    function approveCourse(uint256 _courseId) external onlyOwner {
        require(!courses[_courseId].approved, "Course already approved");
        courses[_courseId].approved = true;
        emit CourseApproved(_courseId);
    }

    function enrollInCourse(uint256 _courseId) external payable whenNotPaused COLLECTPLATFORMTX {
        require(reputationContract.reputation(msg.sender) >= enrollThreshold, "Insufficient reputation to enroll");
        require(courses[_courseId].approved, "Course not approved");
        require(!enrollments[msg.sender][_courseId].isEnrolled, "Already enrolled");

        enrollments[msg.sender][_courseId].isEnrolled = true;
        courses[_courseId].totalEnrolled++;
        emit UserEnrolled(_courseId, msg.sender);
    }


    function attemptQuiz(uint256 _courseId, string[] memory _answers) external payable COLLECTPLATFORMTX {
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
            courses[_courseId].totalRewarded += studentRewardAmount;

            // Automatically send reward to student
            (bool success, ) = payable(msg.sender).call{value: studentRewardAmount}("");
            require(success, "Failed to send MAND");

            emit RewardClaimed(_courseId, msg.sender, studentRewardAmount);
        }

        emit QuizAttempted(_courseId, msg.sender, passed);
    }


    function w_PlatformFees() external onlyOwner {
        require(block.timestamp >= lastWithdrawalTime + WITHDRAWAL_INTERVAL, "Withdrawal interval not reached");
        uint256 amount = accumulatedFees;
        accumulatedFees = 0;
        lastWithdrawalTime = block.timestamp;

        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "Failed to withdraw gas fees");

        emit GasFeesWithdrawn(amount);
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
    function updateEnrollThreshold(uint256 _newThreshold) external onlyOwner {
        require(_newThreshold > 0, "Threshold must be greater than 0");
        enrollThreshold = _newThreshold;
    }

    function updatePostThreshold(uint256 _newThreshold) external onlyOwner {
        require(_newThreshold > 0, "Threshold must be greater than 0");
        postThreshold = _newThreshold;
    }

    function updateStudentReward(uint256 _newReward) external onlyOwner {
        require(_newReward > 0, "Reward must be greater than 0");
        studentRewardAmount = _newReward;
    }

    function updateCreatorReward(uint256 _newReward) external onlyOwner {
        require(_newReward > 0, "Reward must be greater than 0");
         creatorRewardAmount = _newReward;
    }

    function updatePlatformFee(uint256 _newFee) external onlyOwner {
        require(_newFee > 0, "Fee must be greater than 0");
        platformTx = _newFee;
    }
    receive() external payable {}
}