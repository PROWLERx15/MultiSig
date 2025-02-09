// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.22;

/* imports */
import {OwnerManager} from "src/OwnerManager.sol";

contract MultiSig is OwnerManager {
    /* errors */
    error MultiSig__SenderIsNotOwner();
    error MultiSig__TransactionIdDoesNotExist();
    error MultiSig__TransactionAlreadyApprovedByOwner();
    error MultiSig__TransactionAlreadyExecutedByOwner();
    error MultiSig__NotEnoughApprovals();
    error MultiSig__TransactionExecutionFailed();
    error MultiSig__TransactionNotApprovedByTheUser();

    /* Type declarations */
    struct Transaction {
        address to;
        uint256 amount;
        bytes data;
        TransactionStatus status;
    }

    enum TransactionStatus {
        Pending,
        Executed
    }

    /* State variables */
    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) approved;

    /* Events */
    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event SubmitTransaction(uint256 indexed transactionId);
    event ApproveTransaction(address indexed owner, uint256 indexed transactionId);
    event RevokeTransaction(address indexed owner, uint256 indexed transactionId);
    event ExecuteTransaction(uint256 indexed transactionId);

    /* Modifiers */
    modifier onlyOwner() {
        if (!(isOwner[msg.sender])) {
            revert MultiSig__SenderIsNotOwner();
        }
        _;
    }

    modifier transactionIdExists(uint256 _transactionId) {
        if (_transactionId >= transactions.length) {
            revert MultiSig__TransactionIdDoesNotExist();
        }
        _;
    }

    modifier notApproved(uint256 _transactionId) {
        if (approved[_transactionId][msg.sender]) {
            revert MultiSig__TransactionAlreadyApprovedByOwner();
        }
        _;
    }

    modifier notExecuted(uint256 _transactionId) {
        if (transactions[_transactionId].status != TransactionStatus.Executed) {
            revert MultiSig__TransactionAlreadyExecutedByOwner();
        }
        _;
    }

    /* constructor */
    constructor(address[] memory _owners, uint256 _requiredApprovals) OwnerManager(_owners, _requiredApprovals) {}

    /* receive function (if exists) */
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }
    /* fallback function (if exists) */
    /* external */

    function submitTransaction(address _to, uint256 _amount, bytes calldata _data) external onlyOwner {
        transactions.push(Transaction({to: _to, amount: _amount, data: _data, status: TransactionStatus.Pending}));
        emit SubmitTransaction(transactions.length - 1);
    }

    function approveTransaction(uint256 _transactionId)
        external
        onlyOwner
        transactionIdExists(_transactionId)
        notApproved(_transactionId)
        notExecuted(_transactionId)
    {
        approved[_transactionId][msg.sender] = true;
        emit ApproveTransaction(msg.sender, _transactionId);
    }

    function executeTransaction(uint256 _transactionId)
        external
        transactionIdExists(_transactionId)
        notExecuted(_transactionId)
    {
        if (_getApprovalCount(_transactionId) < requiredApprovals) {
            revert MultiSig__NotEnoughApprovals();
        }

        Transaction storage transaction = transactions[_transactionId];

        transaction.status = TransactionStatus.Executed;

        (bool success,) = transaction.to.call{value: transaction.amount}(transaction.data);
        if (!success) {
            revert MultiSig__TransactionExecutionFailed();
        }
        emit ExecuteTransaction(_transactionId);
    }

    function revokeTransaction(uint256 _transactionId)
        external
        transactionIdExists(_transactionId)
        notExecuted(_transactionId)
    {
        if (!(approved[_transactionId][msg.sender])) {
            revert MultiSig__TransactionNotApprovedByTheUser();
        }
        approved[_transactionId][msg.sender] = false;
        transactions[_transactionId].status = TransactionStatus.Pending;
        emit RevokeTransaction(msg.sender, _transactionId);
    }

    /* public */
    /* internal */

    /* private */
    /* internal & private view & pure functions */
    function _getApprovalCount(uint256 _transactionId) internal view returns (uint256 approvalCount) {
        for (uint256 i = 0; i < owners.length; i++) {
            if (approved[_transactionId][owners[i]]) {
                approvalCount += 1;
            }
        }
    }
    /* external & public view & pure functions */
}
