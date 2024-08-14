// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IReputationContract {
    function reputation(address user) external view returns (uint256);
}

contract DecentralLearning is Ownable {
    IReputationContract public reputationContract;
    IERC20 public mandToken;

    uint256 public constant ENROLL_THRESHOLD = 10;
    uint256 public constant POST_THRESHOLD = 50;
    uint256 public constant STUDENT_REWARD_AMOUNT = 10 * 1e18; // 10 MAND tokens
    uint256 public constant CREATOR_REWARD_AMOUNT = 1 * 1e18; // 1 MAND token per passed student

    struct Course {
        address creator;
        string metadataURI;
        bool approved;
        uint256 passedStudents;
        uint256 totalRewarded;
    }

    struct Quiz {
        uint256 courseId;
        string quizMetadataURI; // URI for quiz data (e.g., questions, answers)
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
    event QuizAttempted(
        uint256 indexed courseId,
        address indexed user,
        bool passed
    );
    event RewardClaimed(
        uint256 indexed courseId,
        address indexed user,
        uint256 amount
    );
    event CreatorRewardClaimed(
        uint256 indexed courseId,
        address indexed creator,
        uint256 amount
    );
    event CreatorWithdrawal(
        uint256 indexed courseId,
        address indexed creator,
        uint256 amount
    );

    constructor(address _mandToken, address _reputationContract)
        Ownable(msg.sender)
    {
        reputationContract = IReputationContract(_reputationContract);
        mandToken = IERC20(_mandToken);
    }

    function createCourse(string memory _metadataURI) external {
        require(
            reputationContract.reputation(msg.sender) >= POST_THRESHOLD,
            "Insufficient reputation to create course"
        );
        uint256 courseId = courseCount++;
        courses[courseId] = Course(msg.sender, _metadataURI, false, 0, 0);
        emit CourseCreated(courseId, msg.sender);
    }

    function approveCourse(uint256 _courseId) external onlyOwner {
        require(!courses[_courseId].approved, "Course already approved");
        courses[_courseId].approved = true;
        emit CourseApproved(_courseId);
    }

    function enrollInCourse(uint256 _courseId) external {
        require(
            reputationContract.reputation(msg.sender) >= ENROLL_THRESHOLD,
            "Insufficient reputation to enroll"
        );
        require(courses[_courseId].approved, "Course not approved");
        require(
            !enrollments[msg.sender][_courseId].isEnrolled,
            "Already enrolled"
        );

        enrollments[msg.sender][_courseId].isEnrolled = true;
        emit UserEnrolled(_courseId, msg.sender);
    }

    function createQuiz(uint256 _courseId, string memory _quizMetadataURI) external {
        require(msg.sender == courses[_courseId].creator, "Only course creator can create a quiz");
        require(courses[_courseId].approved, "Course must be approved to create a quiz");

        Quiz memory newQuiz = Quiz({
            courseId: _courseId,
            quizMetadataURI: _quizMetadataURI
        });

        courseQuizzes[_courseId].push(newQuiz);
        uint256 quizId = courseQuizzes[_courseId].length - 1;
        emit QuizCreated(_courseId, quizId);
    }

    function attemptQuiz(
        uint256 _courseId,
        address _user,
        bool _passed
    ) external {
        require(
            msg.sender == courses[_courseId].creator || msg.sender == owner(),
            "Not authorized"
        );
        Enrollment storage enrollment = enrollments[_user][_courseId];
        require(enrollment.isEnrolled, "User not enrolled in this course");
        require(enrollment.attemptCount < 2, "Maximum attempts reached");
        require(!enrollment.hasPassed, "User has already passed this course");

        enrollment.attemptCount++;
        if (_passed) {
            enrollment.hasPassed = true;
            courses[_courseId].passedStudents++;
        }

        emit QuizAttempted(_courseId, _user, _passed);
    }

    function claimStudentReward(uint256 _courseId) external {
        Enrollment storage enrollment = enrollments[msg.sender][_courseId];
        require(enrollment.hasPassed, "Course not passed");
        require(!enrollment.hasClaimedReward, "Reward already claimed");

        enrollment.hasClaimedReward = true;
        require(
            mandToken.transfer(msg.sender, STUDENT_REWARD_AMOUNT),
            "Failed to transfer MAND tokens"
        );
        courses[_courseId].totalRewarded += STUDENT_REWARD_AMOUNT;

        emit RewardClaimed(_courseId, msg.sender, STUDENT_REWARD_AMOUNT);
    }

    function claimCreatorReward(uint256 _courseId) external {
        Course storage course = courses[_courseId];
        require(
            msg.sender == course.creator,
            "Only course creator can claim reward"
        );
        require(course.approved, "Course not approved");

        uint256 rewardAmount = course.passedStudents * CREATOR_REWARD_AMOUNT;
        course.passedStudents = 0; // Reset passed students count
        course.totalRewarded += rewardAmount;

        require(
            mandToken.transfer(msg.sender, rewardAmount),
            "Failed to transfer MAND tokens"
        );
        emit CreatorRewardClaimed(_courseId, msg.sender, rewardAmount);
    }

    function withdrawCreatorTokens(uint256 _courseId, uint256 _amount)
        external
    {
        Course storage course = courses[_courseId];
        require(
            msg.sender == course.creator,
            "Only course creator can withdraw tokens"
        );
        require(
            course.totalRewarded >= _amount,
            "Insufficient rewarded tokens to withdraw"
        );

        course.totalRewarded -= _amount;
        require(
            mandToken.transfer(msg.sender, _amount),
            "Failed to transfer MAND tokens"
        );

        emit CreatorWithdrawal(_courseId, msg.sender, _amount);
    }

    function updateReputationContract(address _newReputationContract)
        external
        onlyOwner
    {
        reputationContract = IReputationContract(_newReputationContract);
    }

    function updateMandToken(address _newMandToken) external onlyOwner {
        mandToken = IERC20(_newMandToken);
    }

    function withdrawExcessTokens(uint256 _amount) external onlyOwner {
        require(
            mandToken.transfer(owner(), _amount),
            "Failed to withdraw tokens"
        );
    }
}
