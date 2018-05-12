pragma solidity ^0.4.21;

import "../token/Token.sol";
import "../owner/Ownable.sol";

contract Sale is Ownable, Token {

    enum STATE { PREPARE, ACTIVE, NEEDTOREFUND, SUCCESS }

    uint public constant startTime = 1525791600; // KST 180509 000000 == UTC 180508 150000
    uint public constant endTime = 1526004000; // KST 180511 110000 == UTC 180511 020000
    uint public constant MAX_CAP = 1000 ether;
    uint public constant SOFT_CAP = 500 ether;
    uint public constant exchangeRate = 10000;

    Token public MGGToken = new Token();
    address public ETHWallet;
    
    uint public issuedTotal;
    STATE public curState = STATE.PREPARE;

    mapping (address => uint) public heldTokens;
    mapping (address => uint) public whiteListCap;

    event Contribution(address from, uint amountToken);
    event UpdateStatus(address from, STATE state);
    event Refund(address to, uint amount);

    using SafeMath for uint256;

    constructor(address _wallet) public Ownable(msg.sender) {
        ETHWallet = _wallet;
    }

    function initSale() external onlyOwner {
        require(now >= startTime, "You can initialize this sale only after May 9 00:00 AM(UTC).");
        require(now <= endTime, "You can initialize this sale only before May 11 02:00 AM(UTC).");
        require(curState == STATE.PREPARE, "The sale was already initialized.");
        curState = STATE.ACTIVE;
        emit UpdateStatus(msg.sender, curState);
    }

    function closeSale() public {
        require(curState == STATE.ACTIVE, "The sale isn't currently in progress.");
        if(msg.sender != address(this)) {
            require(now > endTime, "You can close this sale only after May 11 02:00 AM(UTC)");
        }
        if(address(this).balance < SOFT_CAP) {
            curState = STATE.NEEDTOREFUND;
        } else {
            curState = STATE.SUCCESS;
        }
        emit UpdateStatus(msg.sender, curState);
    }

    function () public payable {
        buy(msg.sender);
    }

    function buy(address _receiver) public payable {
        require(_receiver != address(0), "The address can't be zero.");
        require(msg.value > 0, "The amount of ETH must be greater than zero.");
        require(curState == STATE.ACTIVE, "The sale isn't currently in progress.");
        
        uint amountWei = msg.value;
        if(address(this).balance > MAX_CAP) {
            uint surplus = address(this).balance.sub(MAX_CAP);
            amountWei = msg.value.sub(surplus);
            _receiver.transfer(surplus);
            _addContributor(msg.sender, amountWei.mul(exchangeRate));
        }

        uint amountToken = amountWei.mul(exchangeRate);
        _addContributor(msg.sender, amountToken);
    }

    function _addContributor(address _contributor, uint _amount) private {
        heldTokens[_contributor] = heldTokens[_contributor].add(_amount);
        emit Contribution(_contributor, _amount);
    }

    function refund() public {
        require(curState == STATE.NEEDTOREFUND, "The state of sale isn't currently in NEEDTOREFUND.");
        require(heldTokens[msg.sender] > 0, "You don't have any token.");
        uint amountToken = heldTokens[msg.sender];
        uint amountWei = amountToken.div(exchangeRate);
        heldTokens[msg.sender] = 0;
        if(msg.sender.send(amountWei)) {
            emit Refund(msg.sender, amountWei);   
        } else {
            heldTokens[msg.sender] = amountToken;
        }
    }

}