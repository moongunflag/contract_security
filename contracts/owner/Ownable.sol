pragma solidity ^0.4.23;

contract Ownable{
    address public owner;

    constructor(address _owner) public {
        require(_owner != address(0));
        owner = _owner;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Only token operator could call this.");
        _;
    }

}