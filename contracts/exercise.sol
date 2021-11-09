pragma solidity >=0.4.22 <0.9.0;

contract Overflow{
    mapping(address => uint) balances;

    function contribute() payable public{
        balances[msg.sender] = msg.value;
    }

    function getBalance() view public returns (uint) {
        return balances[msg.sender];
    }

}