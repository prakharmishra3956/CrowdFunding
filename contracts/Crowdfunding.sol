// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Commission {
    address public admin;
    uint256 public totalCommission;

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    function withdraw() external onlyAdmin {
        payable(admin).transfer(address(this).balance);
    }

    receive() external payable {
        totalCommission += msg.value;
    }
}
contract Crowdfunding {
    struct Project {
        address creator;
        uint256 goalAmount;
        uint256 currentAmount;
        uint256 deadline;
        bool isFunded;
        address highestFunder;
        uint256 highestFundAmount;
    }

    mapping(uint256 => Project) public projects;
    mapping(address => uint256) public projectsCreated;
    uint256 public totalProjects;
    uint256 public successfulProjects;
    uint256 public failedProjects;

    address public admin;
    Commission public commissionContract;

    event ProjectCreated(uint256 projectId, address creator, uint256 goalAmount, uint256 deadline);
    event ProjectFunded(uint256 projectId, address funder, uint256 amount, uint256 commission);
    event DeadlineExtended(uint256 projectId, uint256 newDeadline);

    constructor(address _commissionContract) {
        admin = msg.sender;
        commissionContract = Commission(payable(_commissionContract));
    }

    modifier onlyProjectCreator(uint256 _projectId) {
        require(projects[_projectId].creator == msg.sender, "Only project creator can perform this action");
        _;
    }

    function createProject(uint256 _goalAmount, uint256 _deadline) external {
        require(_deadline > block.timestamp, "Deadline should be in the future");

        uint256 projectId = totalProjects++;
        Project storage newProject = projects[projectId];
        newProject.creator = msg.sender;
        newProject.goalAmount = _goalAmount;
        newProject.deadline = _deadline;

        projectsCreated[msg.sender]++;

        emit ProjectCreated(projectId, msg.sender, _goalAmount, _deadline);
    }

    function fundProject(uint256 _projectId) external payable {
        Project storage project = projects[_projectId];
        require(block.timestamp < project.deadline, "Project funding period has ended");
        require(!project.isFunded, "Project already funded");

        uint256 commission = msg.value / 20; // 5%
        uint256 netAmount = msg.value - commission;

        project.currentAmount += netAmount;

        if (msg.value > project.highestFundAmount) {
            project.highestFunder = msg.sender;
            project.highestFundAmount = msg.value;
        }

        payable(address(commissionContract)).transfer(commission);

        emit ProjectFunded(_projectId, msg.sender, msg.value, commission);

        if (project.currentAmount >= project.goalAmount) {
            project.isFunded = true;
            successfulProjects++;
        }
    }

    function extendDeadline(uint256 _projectId, uint256 _newDeadline) external onlyProjectCreator(_projectId) {
        Project storage project = projects[_projectId];
        require(_newDeadline > project.deadline, "New deadline must be greater than current deadline");
        project.deadline = _newDeadline;

        emit DeadlineExtended(_projectId, _newDeadline);
    }

    function getSuccessfulProjectsCount() external view returns (uint256) {
        return successfulProjects;
    }

    function getFailedProjectsCount() external view returns (uint256) {
        return failedProjects;
    }

    function checkProjectFundingStatus(uint256 _projectId) external {
        Project storage project = projects[_projectId];
        if (block.timestamp >= project.deadline && !project.isFunded) {
            failedProjects++;
        }
    }
}
