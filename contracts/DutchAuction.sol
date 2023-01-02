// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Auction.sol";

contract DutchAuction is Auction {

    uint public initialPrice;
    uint public biddingPeriod;
    uint public priceDecrement;

    uint internal auctionEnd;
    uint internal auctionStart;

    /// Creates the DutchAuction contract.
    ///
    /// @param _sellerAddress Address of the seller.
    /// @param _judgeAddress Address of the judge.
    /// @param _timer Timer reference
    /// @param _initialPrice Start price of dutch auction.
    /// @param _biddingPeriod Number of time units this auction lasts.
    /// @param _priceDecrement Rate at which price is lowered for each time unit
    ///                        following linear decay rule.
    constructor(
        address _sellerAddress,
        address _judgeAddress,
        Timer _timer,
        uint _initialPrice,
        uint _biddingPeriod,
        uint _priceDecrement
    )  Auction(_sellerAddress, _judgeAddress, _timer) {
        initialPrice = _initialPrice;
        biddingPeriod = _biddingPeriod;
        priceDecrement = _priceDecrement;
        auctionStart = time();
        // Here we take light assumption that time is monotone
        auctionEnd = auctionStart + _biddingPeriod;
    }

    modifier hasNoBidder(){
        require(highestBidderAddress == address(0), "Auction has a bidder.");
        _;
    }

    modifier hasNotTimedOut(){
        require(time() <= auctionEnd, "Auction has timed out.");
        _;
    }

    function getCurrentPrice() private view returns (uint){
        return initialPrice - (time() - auctionStart) * priceDecrement;
    }

    /// In Dutch auction, winner is the first pearson who bids with
    /// bid that is higher than the current prices.
    /// This method should be only called while the auction is active.
    function bid() auctionOngoing hasNoBidder hasNotTimedOut public payable {
        uint amount = getCurrentPrice();

        require(msg.value >= amount, "Not enough to bid.");

        payable(msg.sender).transfer(msg.value - amount);

        finishAuction(Outcome.SUCCESSFUL, msg.sender);
    }

    function enableRefunds() public {
        if (time() > auctionEnd && highestBidderAddress == address(0)) {
            finishAuction(Outcome.NOT_SUCCESSFUL, address(0));
        }
    }
}