// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.9.0;
pragma experimental ABIEncoderV2;

import "./wallet.sol";

contract Dex is Wallet {

    using SafeMath for uint256;

    enum Side {
        BUY,
        SELL
    }

    struct Order {
        uint id;
        address trader;
        Side side;
        bytes32 ticker;
        uint amount;
        uint price;
        uint filled;
    }

    uint public nextOrderId = 0;

    mapping(bytes32 => mapping(uint256 => Order[])) public orderBook;

    function getOrderBook(bytes32 ticker, Side side) view public returns(Order[] memory) {
        return orderBook[ticker][uint(side)];
    }

    function createLimitOrder(Side side, bytes32 ticker, uint amount, uint price) public {
        if(side == Side.BUY){
            require(balances[msg.sender]["ETH"] >= amount.mul(price));
        }
        else if(side == Side.SELL){
            require(balances[msg.sender][ticker] >= amount);
        }

        Order[] storage orders = orderBook[ticker][uint(side)];
        uint filled; //My fix off the argument count (6 and 7) in the Order struct
        orders.push(
            Order(nextOrderId, msg.sender, side, ticker, amount, price, filled));

        //a shorter version of an "if" statement
        uint i = orders.length > 0 ? orders.length - 1 : 0;

        if(side == Side.BUY){
            while(i > 0){
                if(orders[i-1].price > orders[i].price){
                    break;
                }
                Order memory orderToMove = orders[i - 1];
                orders[i -1] = orders[i];
                orders[i] = orderToMove;
                i--;
            }
        }
        else if(side == Side.SELL){
             while(i > 0){
                if(orders[i-1].price < orders[i].price){
                    break;
                }
                Order memory orderToMove = orders[i - 1];
                orders[i -1] = orders[i];
                orders[i] = orderToMove;
                i--;
            }
        }

        nextOrderId++;
    }

    function createMarketOrder(Side side, bytes32 ticker, uint amount) public{
        if(side == Side.SELL){
        require(balances[msg.sender][ticker] >= amount, "Insufficent balance");
        }

        uint orderBookSide;
        if(side == Side.BUY){
            orderBookSide = 1;
        }
        else{
            orderBookSide = 0;
        }
        Order[] storage orders = orderBook[ticker][uint(orderBookSide)];

        uint totalFilled;

        for (uint256 i = 0; i < orders.length && totalFilled < amount; i++) {
            uint leftToFill = amount.sub(totalFilled);
            uint availableToFill = orders[i].amount.sub(orders[i].filled); //order.amount - order.filled
            uint filled = 0;
            if(availableToFill > leftToFill){
                filled = leftToFill; //Fill the entire market order
            }
            else{ //availableToFill <= leftTofill
                filled = availableToFill; //Fill as much as is available in order[i]
            }

            totalFilled = totalFilled.add(filled);
            orders[i].filled = orders[i].filled.add(filled);
            uint cost = filled.mul(orders[i].price);

            if(side == Side.BUY){
                //Verify that the buyer has enough ETH to cover the purchase (require)
                require(balances[msg.sender]["ETH"] >= filled.mul(orders[i].price));
                //msg.sender is the buyer
                balances[msg.sender][ticker] = balances[msg.sender][ticker].add(filled);
                balances[msg.sender]["ETH"] = balances[msg.sender]["ETH"].sub(cost);

                balances[orders[i].trader][ticker] = balances[orders[i].trader][ticker].sub(filled);
                balances[orders[i].trader]["ETH"] = balances[orders[i].trader]["ETH"].add(cost);
                //Transefer ETH from Buyer to Seller
                //Transfer Tokens from Seller to Buyer
            }
            else if(side == Side.SELL){
                //msg.sender is the seller
                balances[msg.sender][ticker] = balances[msg.sender][ticker].sub(filled);
                balances[msg.sender]["ETH"] = balances[msg.sender]["ETH"].add(cost);

                balances[orders[i].trader][ticker] = balances[orders[i].trader][ticker].add(filled);
                balances[orders[i].trader]["ETH"] = balances[orders[i].trader]["ETH"].sub(cost);
                
                //Transefer ETH from Buyer to Seller
                //Transfer Tokens from Seller to Buyer
            }
                
        }

            while(orders.length > 0 && orders[0].filled == orders[0].amount){
                for (uint256 i = 0; i < orders.length - 1; i++) {
                    orders[i] = orders[i + 1];
                }
                orders.pop();
            }
        //Loop through the orderbook and remove 100% filled orders
    }

}