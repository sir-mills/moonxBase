// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IReputationContract {
    function reputation(address user) external view returns (uint256);
}

contract MOONx is ERC20, Ownable {
    uint256 public maxSupply = 100000000;
    constructor() ERC20("MOONX", "MOONX") Ownable(msg.sender) {
        
    }

    function mint(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= maxSupply, "Exceeds max supply");
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}

contract DecentralLearning is Ownable, Pausable {
    IReputationContract public reputationContract;

    uint256 public enrollThreshold;
    uint256 public postThreshold;
    uint256 public studentRewardAmount;
    uint256 public creatorRewardAmount;
    uint256 public platformTx; 
    uint256 public immutable WITHDRAWAL_INTERVAL = 29 days;

    uint256 public lastWithdrawalTime;
    uint256 public accumulatedFees;

    uint256[] public allCourseIds;
    uint256[] public approvedCourseIds;

    struct Course {
        address creator;
        string metadataURI;
        bool approved;
        uint32 passedStudents;
        uint256 totalRewarded;
        uint32 totalEnrolled;
    }

struct Quiz {
    uint256 courseId;
    // Question 1
    string question1;
    string q1_optionA;
    string q1_optionB;
    string q1_optionC;
    string q1_optionD;
    bytes32 q1_correctAnswerHash;
    // Question 2
    string question2;
    string q2_optionA;
    string q2_optionB;
    string q2_optionC;
    string q2_optionD;
    bytes32 q2_correctAnswerHash;
    // Question 3
    string question3;
    string q3_optionA;
    string q3_optionB;
    string q3_optionC;
    string q3_optionD;
    bytes32 q3_correctAnswerHash;
    // Question 4
    string question4;
    string q4_optionA;
    string q4_optionB;
    string q4_optionC;
    string q4_optionD;
    bytes32 q4_correctAnswerHash;
    // Question 5
    string question5;
    string q5_optionA;
    string q5_optionB;
    string q5_optionC;
    string q5_optionD;
    bytes32 q5_correctAnswerHash;
}

    struct Enrollment {
        bool isEnrolled;
        uint8 attemptCount;
        bool hasPassed;
        bool hasClaimedReward;
    }

    struct UserBalance {
        uint256 moonxBalance;
        uint256 mandBalance;

    }

    mapping(uint256 => Course) public courses;
    mapping(address => mapping(uint256 => Enrollment)) public enrollments;
    mapping(uint256 => Quiz[]) public courseQuizzes; // Mapping from course ID to array of quizzes
    mapping(address => UserBalance) public userBalances;

    uint256 public courseCount;

    event CourseCreated(uint256 indexed courseId, address indexed creator);
    event CourseApproved(uint256 indexed courseId);
    event QuizCreated(uint256 indexed courseId, uint256 quizId);
    event UserEnrolled(uint256 indexed courseId, address indexed user);
    event QuizAttempted(uint256 indexed courseId, address indexed user, bool passed);
    event RewardClaimed(uint256 indexed courseId, address indexed user, uint256 amount);
    event TokenWithdrawn(address indexed user, string tokenType, uint256 amount);
    event GasFeesWithdrawn(uint256 amount);

    constructor(address _reputationContract) Ownable(msg.sender) {
        reputationContract = IReputationContract(_reputationContract);
        lastWithdrawalTime = block.timestamp;
        enrollThreshold = 0 ether;
        postThreshold = 5 ether;
        studentRewardAmount = 0.50 ether;
        creatorRewardAmount = 10 ether;
        platformTx = 0.1 ether;
    }

   modifier COLLECTPLATFORMTX() {
    require(msg.value >= platformTx, "Insufficient gas fee");
    accumulatedFees += platformTx;
    _;
}

    function createCourse(
    string memory _metadataURI,
    // Question 1
    string memory _question1,
    string memory _q1_optionA,
    string memory _q1_optionB,
    string memory _q1_optionC,
    string memory _q1_optionD,
    string memory _q1_correctAnswer,
    // Question 2
    string memory _question2,
    string memory _q2_optionA,
    string memory _q2_optionB,
    string memory _q2_optionC,
    string memory _q2_optionD,
    string memory _q2_correctAnswer,
    // Question 3
    string memory _question3,
    string memory _q3_optionA,
    string memory _q3_optionB,
    string memory _q3_optionC,
    string memory _q3_optionD,
    string memory _q3_correctAnswer,
    // Question 4
    string memory _question4,
    string memory _q4_optionA,
    string memory _q4_optionB,
    string memory _q4_optionC,
    string memory _q4_optionD,
    string memory _q4_correctAnswer,
    // Question 5
    string memory _question5,
    string memory _q5_optionA,
    string memory _q5_optionB,
    string memory _q5_optionC,
    string memory _q5_optionD,
    string memory _q5_correctAnswer
) external payable whenNotPaused COLLECTPLATFORMTX {
    require(reputationContract.reputation(msg.sender) >= postThreshold, "Insufficient reputation to create course");
    
    // Validate all correct answers
    require(
        _validateAnswer(_q1_correctAnswer) &&
        _validateAnswer(_q2_correctAnswer) &&
        _validateAnswer(_q3_correctAnswer) &&
        _validateAnswer(_q4_correctAnswer) &&
        _validateAnswer(_q5_correctAnswer),
        "Invalid correct answer format"
    );

    uint256 courseId = courseCount++;
    courses[courseId] = Course(msg.sender, _metadataURI, false, 0, 0, 0);
    allCourseIds.push(courseId);

    // Create quiz with all 5 questions
    Quiz memory newQuiz = Quiz({
        courseId: courseId,
        // Question 1
        question1: _question1,
        q1_optionA: _q1_optionA,
        q1_optionB: _q1_optionB,
        q1_optionC: _q1_optionC,
        q1_optionD: _q1_optionD,
        q1_correctAnswerHash: keccak256(abi.encodePacked(_q1_correctAnswer)),
        // Question 2
        question2: _question2,
        q2_optionA: _q2_optionA,
        q2_optionB: _q2_optionB,
        q2_optionC: _q2_optionC,
        q2_optionD: _q2_optionD,
        q2_correctAnswerHash: keccak256(abi.encodePacked(_q2_correctAnswer)),
        // Question 3
        question3: _question3,
        q3_optionA: _q3_optionA,
        q3_optionB: _q3_optionB,
        q3_optionC: _q3_optionC,
        q3_optionD: _q3_optionD,
        q3_correctAnswerHash: keccak256(abi.encodePacked(_q3_correctAnswer)),
        // Question 4
        question4: _question4,
        q4_optionA: _q4_optionA,
        q4_optionB: _q4_optionB,
        q4_optionC: _q4_optionC,
        q4_optionD: _q4_optionD,
        q4_correctAnswerHash: keccak256(abi.encodePacked(_q4_correctAnswer)),
        // Question 5
        question5: _question5,
        q5_optionA: _q5_optionA,
        q5_optionB: _q5_optionB,
        q5_optionC: _q5_optionC,
        q5_optionD: _q5_optionD,
        q5_correctAnswerHash: keccak256(abi.encodePacked(_q5_correctAnswer))
    });

    courseQuizzes[courseId].push(newQuiz);
    emit CourseCreated(courseId, msg.sender);
}

    function approveCourse(uint256 _courseId) external onlyOwner {
        require(!courses[_courseId].approved, "Course already approved");
        courses[_courseId].approved = true;
        approvedCourseIds.push(_courseId);
        userBalances[courses[_courseId].creator].moonxBalance += 100;
        emit CourseApproved(_courseId);
    }

    function enrollInCourse(uint256 _courseId) external payable whenNotPaused COLLECTPLATFORMTX {
        require(reputationContract.reputation(msg.sender) >= enrollThreshold, "Insufficient reputation to enroll");
        require(courses[_courseId].approved, "Course not approved");
        require(!enrollments[msg.sender][_courseId].isEnrolled, "Already enrolled");

        enrollments[msg.sender][_courseId].isEnrolled = true;
        courses[_courseId].totalEnrolled++;

        userBalances[msg.sender].moonxBalance += 100;
        userBalances[courses[_courseId].creator].moonxBalance += 100;

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

            userBalances[msg.sender].moonxBalance += 100;

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

    function getAllCourses() external view returns (Course[] memory) {
        Course[] memory result = new Course[](allCourseIds.length);
        for (uint256 i = 0; i < allCourseIds.length; i++) {
            result[i] = courses[allCourseIds[i]];
        }
        return result;
    }

    function getApprovedCourses() external view returns (Course[] memory) {
        Course[] memory result = new Course[](approvedCourseIds.length);
        for (uint256 i = 0; i < approvedCourseIds.length; i++) {
            result[i] = courses[approvedCourseIds[i]];
        }
    return result;
    }   
    function withdrawMoonx(uint256 amount) external whenNotPaused {
    require(userBalances[msg.sender].moonxBalance >= amount, "Insufficient MOONX balance");
    userBalances[msg.sender].moonxBalance -= amount;
    

    emit TokenWithdrawn(msg.sender, "MOONX", amount);
}
    receive() external payable {}
}