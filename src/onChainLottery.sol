// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract onChainLottery {
    // Define the structure for our lottery roundwinner
    struct roundInfo {
        PrizeType prizeType; //nft, eth, and both
        address winner; // the winner of the round
        uint256 prize;         // the amount of eth they recieved or NFT
        uint256 nftTokenId;    //boolif the prize is an NFT, this will hold the token ID
        uint256 playerCount; //number of players in the round
        uint256 timestamp; //The time when the round ended
     }

        //State variables

        // access control
        address public manager; // The manager of the lottery

        //players
        address payable[] public players; // List of players in the current round
        address public winner; // List of winners for each round
        mapping(address => bool) public enteredRound; // Track if an address has entered the current round

        //the round state
        uint256 public roundId; // Current round number
        bool public roundOpen; // Is the current round active?
        PrizeType public currentPrizeType; // The type of prize for the current round
        uint256 public currentNftTokenId; // The token ID for the current round if the prize is an NFT

        //Fee and entry
        uint public constant  MANAGER_FEE_PERCENT = 5 ether; // Entry fee for the lottery
        uint public entryFee; // why we are not setting an entry default value? because we want the manager to be able to set it for each round

        //Events
        event RoundStarted(uint256 roundId, PrizeType prizeType, uint256 nftTokenId);
        event PlayerEntered(address player);
        event RoundEnded(uint256 roundId, address winner, uint256 prize, uint256 nftTokenId);
        event RoundCancelled(uint indexed roundId);
        event WinnerPicked(address indexed winner, uint prize, uint nftTokenId, uint indexed roundId);

          // --- History & Stats ---
        mapping(uint => roundInfo) public rounds;
        uint public totalPrizePaid;


        // Enum for prize types
        enum PrizeType { ETHOnly, NFTOnly, ETHAndNFT }

        // Modifiers
        modifier onlyManager() {
            require(msg.sender == manager, "Only the manager can call this function");
            _;
        }

        // Constructor to set the manager and initial entry fee
        constructor(uint _entyFee) {
            manager = msg.sender;
            entryFee = _entyFee;
        }

        // Our custom errors for function startROund
        error roundAlreadyOpen();
        error entryFeeTooLow(uint provided, uint minimum);
        error MissingNftTokenId(PrizeType prizeType);  // covers NFT_ONLY and ETH_AND_NFT
        //Our custom errors for function participate
        error roundNotOpen();
        error hasAlreadyEntered();
        //Our custom errors for function pickWinner
        error notEnoughPlayers();
        error TransferFailed();
        //our custom errors for function cancelRound
        error RefundFailed(address player);
        // our custom errors for function getround
        error InvalidRoundId(uint requested);
        // Our functions 

        // first function is to start a new round only the manager can call this function
        function startRound(PrizeType _prizeType, uint256 _nftTokenId, uint256 _entryFee) public onlyManager {
            //We check for the is the round is open or not if it is open we cannot start a new round until the current round is ended or cancelled
            // Revert in this case checks the state of the round at the moment
            if (roundOpen) revert roundAlreadyOpen();

            // if the entry fee provided is less than the minimum entry fee we revert the transaction and provide feedback to the user about the provided and minimum entry fee
            if (_entryFee < entryFee) revert entryFeeTooLow(_entryFee, entryFee);

            // if the prize type is NFT and the token ID is not provided we revert the transaction and provide feedback to the user about the need for a token ID for NFT rounds
            if (_prizeType == PrizeType.NFTOnly || _prizeType == PrizeType.ETHAndNFT) {
                if (_nftTokenId == 0) {
                    revert MissingNftTokenId(_prizeType);
                }
            }

            // Set the current round state
            currentPrizeType = _prizeType;
            currentNftTokenId = _nftTokenId;
            entryFee = _entryFee;
            roundOpen = true;

            // we emit that the round has started the necessary information about the that rount
             emit RoundStarted{uint indexed roundId, PrizeType prizeType, uint256 entryFee, uint256 nftTokenId};
        }  

        // function for players to enter the lottery round
        function participate() public payable {
            // we check if the rounf is opened or not if it is players can't enter the round
            if (!roundOpen) revert roundNotOpen();
            // we check if the player has entered the round before 
            if (enteredRound[msg.sender]== roundId) revert hasAlreadyEntered();

            // We check if he paid the required entry fee if not we revert the transaction and provide feedback to the user about the provided and required entry fee
            if (msg.value != entryFee) revert insufficientEntryFee(msg.value, entryFee);

            // now we update the player state and add them to the list of players

            hasEntered[msg.sender] = true;
            players.push(payable(msg.sender)); //we push the player to the list

            emit PlayerEntered(msg.sender);

        }

        // Function for our random number generator using block properties
         // PSEUDO-RANDOM — NOT PRODUCTION SAFE
        // block.prevrandao can be influenced by validators
        // block.timestamp can be slightly manipulated
        // Use Chainlink VRF for production lotteries
        function random() private view returns (uint256) {
            return uint256(keccak256(abi.encodePacked(block.prevrandao, block.timestamp, players.length)));
        }

        //Function to end the round and pick a winner
        function pickWinner() public onlyManager {
            // is a round open? if not we cannot pick a winner, are there enough players?
            if (!roundOpen) revert roundNotOpen();
            // players must be at least 3 to pick a winner
            if(player.length < 3) revert notEnoughPlayers();

            // we generate a random no that will be used to pick a winner from the list of players
            // we generate a random index based on the number of players
            uint256 winnerIndex = _random() % players.length;
            // we get the winner address from the list of players using the random index
            address payable roundWinner = players[winnerIndex];

            // we calc the prize depending on the prize type for the round
            //  cal an eth price only if the round is eth only 
            uint256 prizeAmount = 0;
            uint256 nftTokenId = 0;
            uint256 managerFee = 0;

            // now to see check what to generate our price if this round has an ETH prize
            if (currentPrizeType == PrizeType.ETHOnly || currentPrizeType == PrizeType.ETHAndNFT) {
                uint balance = address(this).balance;
                uint256   managerCut = (balance[msg.sender] * MANAGER_FEE_PERCENT) / 100;
                prizeAmount = balance - managerCut;
                managerFee = managerCut;
            }
            // ETH payout we use call to transfer prize to winner and manager fee to the manager
            if (currentPrizeType == PrizeType.ETHOnly || currentPrizeType == PrizeType.ETHAndNFT) {
                (bool sentToWinner, ) = roundWinner.call{value: prizeAmount}("");
                if (!sentToWinner) revert TransferFailed();

                (bool sentToManager, ) = manager.call{value: managerFee}("");
                if (!sentToManager) revert TransferFailed();
            }
            // if the prize includes an NFT we set the token ID for the winner
            if (currentPrizeType == PrizeType.NFTOnly || currentPrizeType == PrizeType.ETHAndNFT) {
                nftTokenId = currentNftTokenId;
                // Here we would include the logic to transfer the NFT to the winner
                // This is a placeholder as the actual implementation would depend on the NFT contract  
                //  // tokenId is already stored in currentNftTokenId
                  //we call a transfer function from our openzeppelin ERC721 contract to transfer the NFT to the winner 

                // we capture and save our current currenttokenId
                uint nftId = currentNftTokenId;
                uint currentRoundId = roundId;

            // we update and save the round history and stats, winner is recorded in the struct below
            rounds[roundId] = roundInfo({
                prizeType: currentPrizeType,
                winner: roundWinner,
                prize: prizeAmount,
                nftTokenId: currentNftTokenId,
                playerCount: players.length,
                timestamp: block.timestamp
            });
            // update our total prize paid for stats
            uint256 totalPrizePaid += prizeAmount; // we only count the ETH prize for total prize paid
            winner = roundWinner;

            //now reset the round state for the next round
            players = new player[](0);// reset the players array for the next round
            roundOpen = false; // close the round
            roundId++; // increment the round ID for the next round

            }

            //Now we emit the winner
            emit winnerPicked = (roundWinner, prize, nftId, currentRoundId)
        }
        //This is for an emergency function only called by thr manager if something sranges happen
        function cancelRound() public onlyManager {
            // is the round actually opened for it to be cancelled?
            if (!roundOpen) revert roundNotOpen();

            uint currentRoundId = roundId;
            // Now we refund every participant their entry fee and we make sure a player is not refunded twice
            for (uint i = 0; i < players.length; i++) {
                (bool sent, ) = players[i]..call{value: entryFee}("");
                if (!sent) revert RefundFailed(players[i]);
                }

                // we reset our round information immediately the tround cancelled
                players = new address payable[](0);
                roundOpen = false;
                currentNftTokenId = 0;
                roundId++;
                // Now emit or rather annoince that this round was canceled due to unforseen reasons (only manager knows the reasons)
                emit roundCancelled = (currentRoundId);
        }

        // Function to get players information
        function getPlayers() public view returns (address payable[] memory currentPlayers, uint playerAmount, uint pot){
            currentPlayers = players;
            playerAmount = player.length;
            pot = address(this).balance;
        }
        //Function to get round information
        function getRoundInfo(uint _roundId) public view returns (RoundInfo memory){
            //we need to make sure that when a user asks for a round that doesnt exist
            if(_roundId > roundId) revert InvalidRoundId(_roundId);
            returns rounds[_roundId];
        }
        // Bonus function for getting round status 
        function getCurrentRoundStatus() public view returns (
            bool   isOpen,
            uint   currentRoundId,
            uint   numPlayers,
            uint   pot,
            uint   fee,
            PrizeType prizeType,
            uint   nftTokenId
            ) {
                isOpen = roundOpen;
                currentRoundId = roundId;
                numPlayers = players.length;
                pot = address(this).balance;
                fee = entryFee;
                prizeType      = currentPrizeType;
                nftTokenId     = currentNftTokenId
            }
        }