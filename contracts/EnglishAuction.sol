// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Auction.sol";

contract EnglishAuction is Auction {

    uint internal highestBid;
    uint internal initialPrice;
    uint internal biddingPeriod;
    uint internal lastBidTimestamp;
    uint internal minimumPriceIncrement;

    address internal highestBidder;

    constructor(
        address _sellerAddress,
        address _judgeAddress,
        Timer _timer,
        uint _initialPrice,
        uint _biddingPeriod,
        uint _minimumPriceIncrement
    ) Auction(_sellerAddress, _judgeAddress, _timer) {
        initialPrice = _initialPrice;
        biddingPeriod = _biddingPeriod;
        minimumPriceIncrement = _minimumPriceIncrement;

        // Start the auction at contract creation.
        lastBidTimestamp = time();
    }

    modifier hasNotTimedOut(){
        require(!isTimedOut(), "Auction has timed out.");
        _;
    }

    function isTimedOut() private view returns (bool){
        return time() >= lastBidTimestamp + biddingPeriod;
    }

    function bid() auctionOngoing hasNotTimedOut public payable {
        uint minimumBidAmount = highestBid + minimumPriceIncrement;
        minimumBidAmount = highestBidder == address(0) ? initialPrice : minimumBidAmount;

        require(msg.value >= minimumBidAmount, "Bid not large enough.");

        if (highestBidder != address(0)) {
            payable(highestBidder).transfer(highestBid);
        }

        highestBidder = msg.sender;
        highestBid = msg.value;
        lastBidTimestamp = time();
    }

    function getHighestBidder() override public returns (address) {
        if (isTimedOut()) {
            finishAuction(highestBidder != address(0) ? Outcome.SUCCESSFUL : Outcome.NOT_SUCCESSFUL, highestBidder);
            return super.getHighestBidder();
        }
        else {
            return address(0);
        }
    }

    function enableRefunds() public {
        if (isTimedOut() && highestBidder == address(0)) {
            finishAuction(Outcome.NOT_SUCCESSFUL, address(0));
        }
    }

}