// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MoneyMarketFund
 * @notice Proof-of-concept tokenised MMF on Sepolia testnet.
 *
 * The fund admin controls everything manually:
 *   - When to pay interest and how much
 *   - Can withdraw mGBP from the fund at any time
 *
 * Investors:
 *   - subscribe(amount)   deposit mGBP, receive aMMF tokens 1:1
 *   - redeem(amount)      return aMMF tokens, receive mGBP back 1:1
 *   - claimInterest()     collect earned mGBP interest
 *
 * Deploy MockGBP first, then deploy this with the MockGBP address.
 */
contract MoneyMarketFund {

    // ── Token metadata ────────────────────────────────────────────
    string  public name     = "abrdn Sterling MMF Token";
    string  public symbol   = "aMMF";
    uint8   public decimals = 2;

    // ── State ─────────────────────────────────────────────────────
    address public admin;   // fund manager — controls interest payments
    address public mGBP;    // MockGBP contract address

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    // Interest tracking — grows each time admin pays interest
    uint256 public interestPerToken;                    // scaled by 1e6
    mapping(address => uint256) public interestDebt;    // snapshot per holder
    mapping(address => uint256) public pendingInterest; // ready to claim

    // ── Events ────────────────────────────────────────────────────
    event Subscribed(address indexed investor, uint256 amount);
    event Redeemed(address indexed investor, uint256 amount);
    event InterestDeposited(uint256 amount);
    event InterestClaimed(address indexed investor, uint256 amount);

    // ── Setup ─────────────────────────────────────────────────────
    constructor(address _mGBP) {
        admin = msg.sender;
        mGBP  = _mGBP;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    // ── Internal ──────────────────────────────────────────────────

    // Snapshot interest owed before any balance change
    function _settle(address holder) internal {
        if (balanceOf[holder] > 0) {
            pendingInterest[holder] +=
                (balanceOf[holder] * (interestPerToken - interestDebt[holder])) / 1e6;
        }
        interestDebt[holder] = interestPerToken;
    }

    function _pull(address from, uint256 amount) internal {
        (bool ok, ) = mGBP.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", from, address(this), amount)
        );
        require(ok, "transferFrom failed — did you approve?");
    }

    function _send(address to, uint256 amount) internal {
        (bool ok, ) = mGBP.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        );
        require(ok, "transfer failed");
    }

    // ── Investor functions ────────────────────────────────────────

    /**
     * @notice Deposit mGBP and receive aMMF tokens at 1:1.
     *         First call mGBP.approve(fundAddress, amount).
     */
    function subscribe(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        _settle(msg.sender);
        _pull(msg.sender, amount);
        balanceOf[msg.sender] += amount;
        totalSupply           += amount;
        interestDebt[msg.sender] = interestPerToken;
        emit Subscribed(msg.sender, amount);
    }

    /**
     * @notice Burn aMMF tokens and receive mGBP back 1:1.
     *         Any unclaimed interest is paid out automatically.
     */
    function redeem(uint256 amount) external {
        require(amount > 0,                      "Amount must be > 0");
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        _settle(msg.sender);
        balanceOf[msg.sender] -= amount;
        totalSupply           -= amount;
        uint256 interest = pendingInterest[msg.sender];
        pendingInterest[msg.sender] = 0;
        _send(msg.sender, amount + interest);
        emit Redeemed(msg.sender, amount + interest);
    }

    /**
     * @notice Collect your earned mGBP interest without redeeming tokens.
     */
    function claimInterest() external {
        _settle(msg.sender);
        uint256 amount = pendingInterest[msg.sender];
        require(amount > 0, "Nothing to claim");
        pendingInterest[msg.sender] = 0;
        _send(msg.sender, amount);
        emit InterestClaimed(msg.sender, amount);
    }

    /**
     * @notice See how much interest an address can claim right now.
     */
    function claimableInterest(address holder) external view returns (uint256) {
        uint256 accrued = balanceOf[holder] > 0
            ? (balanceOf[holder] * (interestPerToken - interestDebt[holder])) / 1e6
            : 0;
        return pendingInterest[holder] + accrued;
    }

    // ── Admin functions ───────────────────────────────────────────

    /**
     * @notice Pay interest to all holders. The admin decides when and
     *         how much. Call mGBP.approve(fundAddress, amount) first.
     *
     *         The amount is split proportionally by aMMF balance.
     *         Holders collect it by calling claimInterest() or redeem().
     */
    function payInterest(uint256 amount) external onlyAdmin {
        require(amount > 0,      "Amount must be > 0");
        require(totalSupply > 0, "No investors yet");
        _pull(msg.sender, amount);
        interestPerToken += (amount * 1e6) / totalSupply;
        emit InterestDeposited(amount);
    }

    /**
     * @notice Withdraw mGBP from the fund — simulates deploying capital
     *         into underlying instruments.
     */
    function withdrawMGBP(uint256 amount) external onlyAdmin {
        _send(admin, amount);
    }

    /**
     * @notice Deposit mGBP back into the fund (e.g. returning capital
     *         from underlying instruments). Call approve first.
     */
    function depositMGBP(uint256 amount) external onlyAdmin {
        _pull(msg.sender, amount);
    }
}
