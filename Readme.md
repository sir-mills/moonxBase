# MoonxBase DecentralLearning Smart Contract

## Overview
The DecentralLearning smart contract provides a decentralized platform for course creation, enrollment, and assessment through quizzes. It allows users with sufficient reputation to create and manage courses, while students can enroll, attempt quizzes, and earn rewards in the form of MAND tokens.

## Features
- Course Creation: Users with sufficient reputation can create courses with associated metadata.
- Course Approval: The owner of the contract has the authority to approve courses before they become available for enrollment.
- Enrollment: Students can enroll in approved courses if they meet the reputation threshold.
- Quizzes: Course creators can create quizzes for their courses, and students can attempt these quizzes.
- Rewards: Students who pass the quizzes receive rewards in MAND tokens. Course creators also receive rewards based on the number of students who pass their quizzes.

## Contract Structure
### Course
- creator: The address of the course creator.
- metadataURI: The URI of the course metadata.
- approved: Indicates if the course has been approved.
- passedStudents: The number of students who have passed the course.
- totalRewarded: The total amount of rewards distributed for the course.

### Quiz
- courseId: The ID of the course associated with the quiz.
- question: The quiz question.
- optionA, optionB, optionC, optionD: The answer options.
- correctAnswerHash: The hashed correct answer ("A", "B", "C", or "D").

### Enrollment
- isEnrolled: Indicates if the user is enrolled in a course.
- attemptCount: The number of attempts made by the user to pass the course.
- hasPassed: Indicates if the user has passed the course.
- hasClaimedReward: Indicates if the user has claimed the reward for passing the course.


## Contract Functions
### Course Management
- createCourse(string memory _metadataURI): Allows users with sufficient reputation to create a course.
- approveCourse(uint256 _courseId): Allows the owner to approve a course.

### Enrollment
- enrollInCourse(uint256 _courseId): Allows users to enroll in an approved course if they meet the reputation threshold.

### Quiz Management
- createQuiz(uint256 _courseId, string memory _question, string memory _optionA, string memory _optionB, string memory _optionC, string memory _optionD, string memory _correctAnswer): Allows course creators to create quizzes for their courses.
- attemptQuiz(uint256 _courseId, string memory _answer): Allows students to attempt the quiz. The contract checks the answer and updates the user's enrollment status.

### Reward Management
- claimStudentReward(uint256 _courseId): Allows students who passed the course to claim their reward.
- claimCreatorReward(uint256 _courseId): Allows course creators to claim rewards based on the number of students who passed their quizzes.
- withdrawCreatorTokens(uint256 _courseId, uint256 _amount): Allows course creators to withdraw MAND tokens that have been rewarded.

### Administrative Functions
- updateReputationContract(address _newReputationContract): Allows the owner to update the address of the reputation contract
- updateMandToken(address _newMandToken): Allows the owner to update the address of the MAND token contract.
- withdrawExcessTokens(uint256 _amount): Allows the owner to withdraw excess MAND tokens.

### Events
- CourseCreated(uint256 indexed courseId, address indexed creator): Emitted when a course is created.
- CourseApproved(uint256 indexed courseId): Emitted when a course is approved.
- QuizCreated(uint256 indexed courseId, uint256 quizId): Emitted when a quiz is created for a course.
- UserEnrolled(uint256 indexed courseId, address indexed user): Emitted when a user enrolls in a course.
- QuizAttempted(uint256 indexed courseId, address indexed user, bool passed): Emitted when a user attempts a quiz.
- RewardClaimed(uint256 indexed courseId, address indexed user, uint256 amount): Emitted when a student claims their reward.
- CreatorRewardClaimed(uint256 indexed courseId, address indexed creator, uint256 amount): Emitted when a creator claims their reward.
- CreatorWithdrawal(uint256 indexed courseId, address indexed creator, uint256 amount): Emitted when a creator withdraws rewarded tokens.

