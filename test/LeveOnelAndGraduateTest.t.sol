// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {DeployLevelOne} from "../script/DeployLevelOne.s.sol";
import {GraduateToLevelTwo} from "../script/GraduateToLevelTwo.s.sol";
import {LevelOne} from "../src/LevelOne.sol";
import {LevelTwo} from "../src/LevelTwo.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

contract LevelOneAndGraduateTest is Test {
    DeployLevelOne deployBot;
    GraduateToLevelTwo graduateBot;

    LevelOne levelOneProxy;
    LevelTwo levelTwoImplementation;

    address proxyAddress;
    address levelOneImplementationAddress;
    address levelTwoImplementationAddress;

    MockUSDC usdc;

    address principal;
    uint256 schoolFees;

    // teachers
    address alice;
    address bob;
    // students
    address clara;
    address dan;
    address eli;
    address fin;
    address grey;
    address harriet;

    function setUp() public {
        deployBot = new DeployLevelOne();
        proxyAddress = deployBot.deployLevelOne();
        levelOneProxy = LevelOne(proxyAddress);

        // graduateBot = new GraduateToLevelTwo();

        usdc = deployBot.getUSDC();
        principal = deployBot.principal();
        schoolFees = deployBot.getSchoolFees();
        levelOneImplementationAddress = deployBot.getImplementationAddress();

        alice = makeAddr("first_teacher");
        bob = makeAddr("second_teacher");

        clara = makeAddr("first_student");
        dan = makeAddr("second_student");
        eli = makeAddr("third_student");
        fin = makeAddr("fourth_student");
        grey = makeAddr("fifth_student");
        harriet = makeAddr("six_student");

        usdc.mint(clara, schoolFees);
        usdc.mint(dan, schoolFees);
        usdc.mint(eli, schoolFees);
        usdc.mint(fin, schoolFees);
        usdc.mint(grey, schoolFees);
        usdc.mint(harriet, schoolFees);
    }

    function test_confirm_first_deployment_is_level_one() public view {
        uint256 expectedTeacherWage = 35;
        uint256 expectedPrincipalWage = 5;
        uint256 expectedPrecision = 100;

        assertEq(levelOneProxy.TEACHER_WAGE(), expectedTeacherWage);
        assertEq(levelOneProxy.PRINCIPAL_WAGE(), expectedPrincipalWage);
        assertEq(levelOneProxy.PRECISION(), expectedPrecision);
        assertEq(levelOneProxy.getPrincipal(), principal);
        assertEq(levelOneProxy.getSchoolFeesCost(), deployBot.schoolFees());
        assertEq(levelOneProxy.getSchoolFeesToken(), address(usdc));
    }

    function test_confirm_add_teacher() public {
        vm.startPrank(principal);
        levelOneProxy.addTeacher(alice);
        levelOneProxy.addTeacher(bob);
        vm.stopPrank();

        assert(levelOneProxy.isTeacher(alice) == true);
        assert(levelOneProxy.isTeacher(bob) == true);
        assert(levelOneProxy.getTotalTeachers() == 2);
    }

    function test_confirm_cannot_add_teacher_if_not_principal() public {
        vm.expectRevert(LevelOne.HH__NotPrincipal.selector);
        levelOneProxy.addTeacher(alice);
    }

    function test_confirm_cannot_add_teacher_twice() public {
        vm.prank(principal);
        levelOneProxy.addTeacher(alice);

        vm.prank(principal);
        vm.expectRevert(LevelOne.HH__TeacherExists.selector);
        levelOneProxy.addTeacher(alice);
    }

    function test_confirm_remove_teacher() public {
        vm.startPrank(principal);
        levelOneProxy.addTeacher(alice);
        levelOneProxy.addTeacher(bob);
        vm.stopPrank();

        vm.prank(principal);
        levelOneProxy.removeTeacher(alice);

        assert(levelOneProxy.isTeacher(alice) == false);
        assert(levelOneProxy.getTotalTeachers() == 1);
    }

    function test_confirm_enroll() public {
        vm.startPrank(clara);
        usdc.approve(address(levelOneProxy), schoolFees);
        levelOneProxy.enroll();
        vm.stopPrank();

        assert(usdc.balanceOf(address(levelOneProxy)) == schoolFees);
    }

    function test_confirm_cannot_enroll_without_school_fees() public {
        address newStudent = makeAddr("no_school_fees");

        vm.prank(newStudent);
        vm.expectRevert();
        levelOneProxy.enroll();
    }

    function test_confirm_cannot_enroll_twice() public {
        vm.startPrank(eli);
        usdc.approve(address(levelOneProxy), schoolFees);
        levelOneProxy.enroll();
        vm.stopPrank();

        vm.prank(eli);
        vm.expectRevert(LevelOne.HH__StudentExists.selector);
        levelOneProxy.enroll();
    }

    modifier schoolInSession() {
        _teachersAdded();
        _studentsEnrolled();

        vm.prank(principal);
        levelOneProxy.startSession(70);

        _;
    }

    function test_NotReviewCountIncreased() public {
        vm.startPrank(clara);
        usdc.approve(address(levelOneProxy), schoolFees);
        levelOneProxy.enroll();
        vm.stopPrank();

        // check for student add
        assert(levelOneProxy.getTotalStudents() == 1);

        // add teacher
        vm.startPrank(principal);
        levelOneProxy.addTeacher(alice);
        vm.stopPrank();

        // check for teacher add
        assert(levelOneProxy.getTotalTeachers() == 1);

        vm.warp(block.timestamp + 1 weeks);
        vm.prank(alice);
        levelOneProxy.giveReview(clara, false);
        assert(levelOneProxy.studentScore(clara) == 90);

        vm.warp(block.timestamp + 1 weeks);
        vm.prank(alice);
        levelOneProxy.giveReview(clara, false);
        assert(levelOneProxy.studentScore(clara) == 80);

        // Failing assertion: expected 2 reviews, got 0
        assertEq(levelOneProxy.reviewCount(clara), 0);
    }
    function test_confirm_can_give_review() public schoolInSession {
        vm.warp(block.timestamp + 1 weeks);

        vm.prank(alice);
        levelOneProxy.giveReview(harriet, false);

        assert(levelOneProxy.studentScore(harriet) == 90);
    }

    function test_confirm_can_graduate() public schoolInSession {
        levelTwoImplementation = new LevelTwo();
        levelTwoImplementationAddress = address(levelTwoImplementation);

        bytes memory data = abi.encodeCall(LevelTwo.graduate, ());

        vm.prank(principal);
        levelOneProxy.graduateAndUpgrade(levelTwoImplementationAddress, data);

        LevelTwo levelTwoProxy = LevelTwo(proxyAddress);

        console2.log(levelTwoProxy.bursary());
        console2.log(levelTwoProxy.getTotalStudents());
    }

    // ////////////////////////////////
    // /////                      /////
    // /////   HELPER FUNCTIONS   /////
    // /////                      /////
    // ////////////////////////////////

    function _teachersAdded() internal {
        vm.startPrank(principal);
        levelOneProxy.addTeacher(alice);
        levelOneProxy.addTeacher(bob);
        vm.stopPrank();
    }

    function _studentsEnrolled() internal {
        vm.startPrank(clara);
        usdc.approve(address(levelOneProxy), schoolFees);
        levelOneProxy.enroll();
        vm.stopPrank();

        vm.startPrank(dan);
        usdc.approve(address(levelOneProxy), schoolFees);
        levelOneProxy.enroll();
        vm.stopPrank();

        vm.startPrank(eli);
        usdc.approve(address(levelOneProxy), schoolFees);
        levelOneProxy.enroll();
        vm.stopPrank();

        vm.startPrank(fin);
        usdc.approve(address(levelOneProxy), schoolFees);
        levelOneProxy.enroll();
        vm.stopPrank();

        vm.startPrank(grey);
        usdc.approve(address(levelOneProxy), schoolFees);
        levelOneProxy.enroll();
        vm.stopPrank();

        vm.startPrank(harriet);
        usdc.approve(address(levelOneProxy), schoolFees);
        levelOneProxy.enroll();
        vm.stopPrank();
    }
}
