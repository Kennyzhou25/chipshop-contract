// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

import "./owner/Operator.sol";

contract Dollar is ERC20Burnable, Operator {
    uint256 public constant INITIAL_DISTRIBUTION = 100000 ether;
    uint256 public constant AIRDROP_FUND = 9000 ether;

    bool public rewardPoolDistributed = false;

    /**
     * @notice Constructs the Midas Dollar ERC-20 contract.
     */
    constructor() public ERC20("Midas Dollar", "MDO") {
        // Mints 1 Midas Dollar to contract creator for initial pool setup
        _mint(msg.sender, 1 ether);
    }

    /**
     * @notice Operator mints basis dollar to a recipient
     * @param recipient_ The address of recipient
     * @param amount_ The amount of basis dollar to mint to
     * @return whether the process has been done
     */
    function mint(address recipient_, uint256 amount_) public onlyOperator returns (bool) {
        uint256 balanceBefore = balanceOf(recipient_);
        _mint(recipient_, amount_);
        uint256 balanceAfter = balanceOf(recipient_);

        return balanceAfter > balanceBefore;
    }

    function burn(uint256 amount) public override {
        super.burn(amount);
    }

    function burnFrom(address account, uint256 amount) public override onlyOperator {
        super.burnFrom(account, amount);
    }

    /**
     * @notice distribute to reward pool (only once)
     */
    function distributeReward(address _distributionPool) external onlyOperator {
        require(!rewardPoolDistributed, "only can distribute once");
        require(_distributionPool != address(0), "!_distributionPool");
        rewardPoolDistributed = true;
        _mint(_distributionPool, INITIAL_DISTRIBUTION.sub(AIRDROP_FUND));
        _mint(msg.sender, AIRDROP_FUND);
    }

    function governanceRecoverUnsupported(IERC20 _token, uint256 _amount, address _to) external onlyOperator {
        _token.transfer(_to, _amount);
    }
}
