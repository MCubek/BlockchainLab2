// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BoxOracle.sol";

contract Betting {

    struct Player {
        uint8 id;
        string name;
        uint totalBetAmount;
        uint currCoef;
    }

    struct Bet {
        address bettor;
        uint amount;
        uint player_id;
        uint betCoef;
    }

    address private betMaker;
    BoxOracle public oracle;
    uint public minBetAmount;
    uint public maxBetAmount;
    uint public totalBetAmount;
    uint public thresholdAmount;

    Bet[] private bets;
    Player public player_1;
    Player public player_2;

    bool private suspended = false;
    mapping(address => uint) public balances;

    constructor(
        address _betMaker,
        string memory _player_1,
        string memory _player_2,
        uint _minBetAmount,
        uint _maxBetAmount,
        uint _thresholdAmount,
        BoxOracle _oracle
    ) {
        betMaker = (_betMaker == address(0) ? msg.sender : _betMaker);
        player_1 = Player(1, _player_1, 0, 200);
        player_2 = Player(2, _player_2, 0, 200);
        minBetAmount = _minBetAmount;
        maxBetAmount = _maxBetAmount;
        thresholdAmount = _thresholdAmount;
        oracle = _oracle;

        totalBetAmount = 0;
    }

    receive() external payable {}

    fallback() external payable {}

    modifier betInRange(uint amount){
        require(amount <= maxBetAmount && amount >= minBetAmount, "Bet can't be made as it it out of range.");
        _;
    }

    modifier notSuspended(){
        require(!suspended, "Betting is suspended");
        _;
    }

    modifier isSuspended(){
        require(suspended, "Betting is not suspended");
        _;
    }

    modifier notFinished(){
        require(oracle.getWinner() == 0, "Bet can't be made as it is finished.");
        _;
    }

    modifier isFinished(){
        require(oracle.getWinner() != 0, "The bet isn't finished yet.");
        _;
    }

    modifier notBetMaker(){
        require(msg.sender != betMaker, "Bet maker cant make bets.");
        _;
    }

    modifier isBetMaker(){
        require(msg.sender == betMaker, "Not bet maker.");
        _;
    }

    function suspendSuspiciousBets() internal {
        if (totalBetAmount > thresholdAmount) {
            if (player_1.totalBetAmount == 0 || player_2.totalBetAmount == 0) {
                suspended = true;
            }
        }
    }

    function getAndUpdatePlayerCoefs(uint playerId) internal returns (uint){
        if (totalBetAmount > thresholdAmount) {
            uint sum = player_1.totalBetAmount + player_2.totalBetAmount;

            player_1.currCoef = sum * 100 / player_1.totalBetAmount;
            player_2.currCoef = sum * 100 / player_2.totalBetAmount;
        }
        return (playerId == player_1.id ? player_1 : player_2).currCoef;
    }

    function makeBet(uint8 _playerId) notSuspended notFinished notBetMaker betInRange(msg.value) public payable {
        require(_playerId == player_1.id || _playerId == player_2.id, "Invalid player id.");

        uint playerCoef = getAndUpdatePlayerCoefs(_playerId);

        bets.push(Bet({
        bettor : msg.sender,
        amount : msg.value,
        player_id : _playerId,
        betCoef : playerCoef
        }));

        (_playerId == player_1.id ? player_1 : player_2).totalBetAmount += msg.value;
        totalBetAmount += msg.value;
        balances[msg.sender] += msg.value;

        suspendSuspiciousBets();
    }

    function claimSuspendedBets() isSuspended public {
        uint256 amount = balances[msg.sender];

        bool success = payable(msg.sender).send(amount);

        require(success, "Refund of suspended bet not successful.");

        balances[msg.sender] = 0;
    }

    function claimWinningBets() notSuspended isFinished notBetMaker public {
        uint winningPlayerId = oracle.getWinner();

        Player storage player = (winningPlayerId == player_1.id ? player_1 : player_2);

        uint winnings = 0;
        uint betSum = 0;
        for (uint i = 0; i < bets.length; i++) {
            Bet memory bet = bets[i];
            if (bet.player_id == winningPlayerId && bet.bettor == msg.sender) {
                winnings += bet.amount * bet.betCoef / 100;
                betSum += bet.amount;
                bets[i].amount = 0;
            }
        }
        player.totalBetAmount -= betSum;
        balances[msg.sender] -= betSum;

        payable(msg.sender).transfer(winnings);
    }

    function claimLosingBets() notSuspended isFinished isBetMaker public {
        uint winningPlayerId = oracle.getWinner();
        Player memory winningPlayer = (winningPlayerId == player_1.id ? player_1 : player_2);

        require(winningPlayer.totalBetAmount == 0, "Not all winnings are paid.");

        payable(betMaker).transfer(address(this).balance);
    }
}