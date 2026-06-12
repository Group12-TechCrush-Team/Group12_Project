// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

contract onChainLottery {
    // --- Data structures ---

    // Information stored for each completed round.
    struct roundInfo {
        PrizeType prizeType;   // Which kind of prize was offered this round
        address winner;        // Round winner address
        uint256 prize;         // ETH amount winner received
        uint256 nftTokenId;    // NFT token ID when applicable
        uint256 playerCount;   // Number of players in the round
        uint256 timestamp;     // When the round was finalized
    }
    
    // --- State variables ---

    address public manager;              // Contract admin / lottery manager
    address payable[] public players;    // Current round participants
    address public winner;               // Last winner address
    mapping(address => uint256) public enteredRound; // Maps player to the round they joined

    uint256 public roundId;              // Current round index
    bool public roundOpen;               // Is a round currently active?
    PrizeType public currentPrizeType;   // Current prize type for the open round
    uint256 public currentNftTokenId;    // NFT token ID for NFT rounds

    uint256 public constant MANAGER_FEE_PERCENT = 5; // Manager fee percentage on ETH prize
    uint256 public entryFee;             // Current round entry fee

    mapping(uint256 => roundInfo) public rounds;  // Completed round history
    uint256 public totalPrizePaid;       // Total ETH paid to winners

    // --- Events ---

    event RoundStarted(uint256 roundId, PrizeType prizeType, uint256 nftTokenId);
    event PlayerEntered(address player);
    event RoundEnded(uint256 roundId, address winner, uint256 prize, uint256 nftTokenId);
    event RoundCancelled(uint256 roundId);
    event WinnerPicked(address indexed winner, uint256 prize, uint256 nftTokenId, uint256 roundId);

    // --- Prize type options ---
    enum PrizeType { ETHOnly, NFTOnly, ETHAndNFT }

    // --- Modifiers ---

    modifier onlyManager() {
        require(msg.sender == manager, "Only the manager can call this function");
        _;
    }

    // --- Constructor ---

    constructor(uint256 _entryFee) {
        manager = msg.sender;
        entryFee = _entryFee;
    }

    // --- Custom errors ---

    error roundAlreadyOpen();
    error entryFeeTooLow(uint256 provided, uint256 minimum);
    error MissingNftTokenId(PrizeType prizeType);
    error roundNotOpen();
    error hasAlreadyEntered();
    error insufficientEntryFee(uint256 provided, uint256 minimum);
    error notEnoughPlayers();
    error TransferFailed();
    error RefundFailed(address player);
    error InvalidRoundId(uint256 requested);

    // --- Manager functions ---

    /**
     * @notice Starts a new lottery round.
     * @param _prizeType the prize type for the round
     * @param _nftTokenId the NFT token ID when the prize includes NFT
     * @param _entryFee the entry fee for this round
     */
    function startRound(PrizeType _prizeType, uint256 _nftTokenId, uint256 _entryFee) public onlyManager {
        if (roundOpen) revert roundAlreadyOpen();
        if (_entryFee < entryFee) revert entryFeeTooLow(_entryFee, entryFee);
        if ((_prizeType == PrizeType.NFTOnly || _prizeType == PrizeType.ETHAndNFT) && _nftTokenId == 0) {
            revert MissingNftTokenId(_prizeType);
        }

        currentPrizeType = _prizeType;
        currentNftTokenId = _nftTokenId;
        entryFee = _entryFee;
        roundOpen = true;

        emit RoundStarted(roundId, _prizeType, _nftTokenId);
    }

    /**
     * @notice Join the current lottery round by paying the exact entry fee.
     * @dev A player can only enter once per round.
     */
    function participate() public payable {
        if (!roundOpen) revert roundNotOpen();
        if (enteredRound[msg.sender] == roundId + 1) revert hasAlreadyEntered();
        if (msg.value != entryFee) revert insufficientEntryFee(msg.value, entryFee);

        enteredRound[msg.sender] = roundId + 1; // Mark player as entered for this round
        players.push(payable(msg.sender));

        emit PlayerEntered(msg.sender);
    }

    /**
     * @notice Generates a pseudo-random number from block data.
     * @dev Not secure for production use.
     */
    function random() private view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.prevrandao, block.timestamp, players.length)));
    }

    /**
     * @notice Picks a winner, pays the prize, and closes the round.
     */
    function pickWinner() public onlyManager {
        if (!roundOpen) revert roundNotOpen();
        if (players.length < 3) revert notEnoughPlayers();

        uint256 winnerIndex = random() % players.length;
        address payable roundWinner = players[winnerIndex];
        uint256 prizeAmount;
        uint256 nftTokenId;

        if (currentPrizeType == PrizeType.ETHOnly || currentPrizeType == PrizeType.ETHAndNFT) {
            uint256 balance = address(this).balance;
            uint256 managerFee = (balance * MANAGER_FEE_PERCENT) / 100;
            prizeAmount = balance - managerFee;

            (bool sentToWinner, ) = roundWinner.call{value: prizeAmount}("");
            if (!sentToWinner) revert TransferFailed();

            (bool sentToManager, ) = payable(manager).call{value: managerFee}("");
            if (!sentToManager) revert TransferFailed();
        }

        if (currentPrizeType == PrizeType.NFTOnly || currentPrizeType == PrizeType.ETHAndNFT) {
            nftTokenId = currentNftTokenId;
        }

        rounds[roundId] = roundInfo({
            prizeType: currentPrizeType,
            winner: roundWinner,
            prize: prizeAmount,
            nftTokenId: nftTokenId,
            playerCount: players.length,
            timestamp: block.timestamp
        });

        totalPrizePaid += prizeAmount;
        winner = roundWinner;

        // Reset state for the next round
        players = new address payable[](0);
        roundOpen = false;
        currentNftTokenId = 0;
        roundId++;

        emit WinnerPicked(roundWinner, prizeAmount, nftTokenId, roundId - 1);
    }

    /**
     * @notice Cancels the current round and refunds all players.
     */
    function cancelRound() public onlyManager {
        if (!roundOpen) revert roundNotOpen();

        uint256 currentRoundId = roundId;

        for (uint256 i = 0; i < players.length; i++) {
            (bool sent, ) = players[i].call{value: entryFee}("");
            if (!sent) revert RefundFailed(players[i]);
        }

        players = new address payable[](0);
        roundOpen = false;
        currentNftTokenId = 0;
        roundId++;

        emit RoundCancelled(currentRoundId);
    }

    // --- View helpers ---

    function getPlayers() public view returns (address payable[] memory currentPlayers, uint256 playerAmount, uint256 pot) {
        currentPlayers = players;
        playerAmount = players.length;
        pot = address(this).balance;
    }

    function getRoundInfo(uint256 _roundId) public view returns (roundInfo memory) {
        if (_roundId >= roundId) revert InvalidRoundId(_roundId);
        return rounds[_roundId];
    }

    function getCurrentRoundStatus()
        public
        view
        returns (
            bool isOpen,
            uint256 currentRoundId,
            uint256 numPlayers,
            uint256 pot,
            uint256 fee,
            PrizeType prizeType,
            uint256 nftTokenId
        )
    {
        isOpen = roundOpen;
        currentRoundId = roundId;
        numPlayers = players.length;
        pot = address(this).balance;
        fee = entryFee;
        prizeType = currentPrizeType;
        nftTokenId = currentNftTokenId;
    }
}
