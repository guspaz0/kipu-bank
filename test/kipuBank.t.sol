// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import { Test, console } from "forge-std/Test.sol";
import { KipuBank } from "../contracts/kipuBank.sol";

contract KipuBankTest is Test {

    KipuBank kipuBank;

    //Variables ~ Users
    address guspaz = makeAddr("Guspaz");
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    //Variables ~ Utils
    uint256 constant BANK_CAP = 10 * 10 ** 18;
    uint256 constant INITIAL_BALANCE = 100 * 10 ** 18;

    function setUp() public {
        kipuBank = new KipuBank(BANK_CAP);

        vm.deal(guspaz, INITIAL_BALANCE);
        vm.deal(user1, INITIAL_BALANCE);
        vm.deal(user2, INITIAL_BALANCE);
    }

    modifier processDeposit() {
        uint256 amount = 1 * 10 ** 18;
        vm.prank(guspaz);
        kipuBank.deposit{value: amount}(amount);
        _;
    }

    /// @notice Error personalizado para manejo de excedentes del límite del banco
    error BankCapLimitExceeded(address caller, uint256 attemptedDeposit, uint256 bankCap);


    function test_depositFailsWhenBankCapIsReached() public {
        vm.prank(guspaz);
        vm.expectRevert(abi.encodeWithSelector(BankCapLimitExceeded.selector, guspaz, INITIAL_BALANCE, BANK_CAP));
        kipuBank.deposit{value: INITIAL_BALANCE}(INITIAL_BALANCE);
    }

    event Deposit(address indexed, uint256, uint256);

    function test_depositSucceed() public {
        uint256 amount = 1 * 10 ** 18;
        uint256 userBalance = user1.balance;

        vm.prank(user1);
        vm.expectEmit();
        emit Deposit(user1, amount, amount);
        kipuBank.deposit{value: amount}(amount);

        uint256 contractBalance = kipuBank.treasuryBalance();
        assertEq(user1.balance, userBalance - amount);
        assertEq(kipuBank.depositosCount(), 1);

        vm.prank(user1);
        assertEq(kipuBank.getBalance(), amount);
        assertEq(contractBalance, amount);
    }

    error InsufficientUserBalance(uint256, uint256);
    error WithdrawalLimitExceeded(address, uint256);

    function test_withdrawFailedBecauseOfUserBalance() public processDeposit {
        uint256 complaintAmount = 1 * 10 ** 14;
        uint256 exceedingAmount = 1 * 10 ** 18;

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(InsufficientUserBalance.selector, complaintAmount, 0));
        kipuBank.withdraw(complaintAmount);

        vm.prank(guspaz);
        vm.expectRevert(abi.encodeWithSelector(WithdrawalLimitExceeded.selector, guspaz, exceedingAmount));
        kipuBank.withdraw(exceedingAmount);

        assertEq(kipuBank.withdrawalCount(), 0);
        vm.prank(guspaz);
        assertEq(kipuBank.getBalance(), exceedingAmount);
        assertEq(kipuBank.treasuryBalance(), exceedingAmount);
    }

    event Withdrawal(address indexed, uint256, uint256);

    function test_WithdrawSucceed() public processDeposit {
        uint256 complaintAmount = 1 * 10 ** 14;
        uint256 amountAfterWithdrawal = 1 * 10 ** 18 - complaintAmount;

        vm.prank(guspaz);
        vm.expectEmit();
        emit Withdrawal(guspaz, complaintAmount, amountAfterWithdrawal);
        kipuBank.withdraw(complaintAmount);

        assertEq(kipuBank.withdrawalCount(), 1);

        vm.prank(guspaz);
        assertEq(kipuBank.getBalance(), amountAfterWithdrawal);
        assertEq(kipuBank.treasuryBalance(), amountAfterWithdrawal);
    }

}