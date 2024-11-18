// SPDX-License-Identifier: Public Domain
pragma solidity ^0.8.0;

contract RecyclingIncentiveSystem {

    address public adminPool; // Common pool for admin vouchers
    mapping(address => uint256) public vouchers;
    mapping(address => bool) public isAdmin;
    mapping(address => bool) public isVendor;
    mapping(address => bool) public isRecyclingPersonnel;

    enum MaterialType { Plastic, Glass, Metal, Paper }
    mapping(MaterialType => uint256) public rewardRates;

    event TrashDeposited(address indexed user, MaterialType material, uint256 trashAmount, uint256 voucherReward);
    event TrashProcessed(address indexed recycler, uint256 trashValue);
    event VendorDeposit(address indexed vendor, uint256 voucherAmount);
    event PayoutWithdrawn(address indexed admin, address indexed investor, uint256 amount);
    event AdminAdded(address indexed admin);
    event VendorAdded(address indexed vendor);
    event RecyclingPersonnelAdded(address indexed personnel);
    event VouchersAdded(address indexed account, uint256 amount);
    event VendorCheck(address indexed account, bool isVendor);

    constructor(address _adminPool) {
        require(_adminPool != address(0), "Invalid admin pool address");
        adminPool = _adminPool;
        isAdmin[msg.sender] = true; // Contract deployer is the first admin
        rewardRates[MaterialType.Plastic] = 1 ether;
        rewardRates[MaterialType.Glass] = 2 ether;
        rewardRates[MaterialType.Metal] = 3 ether;
        rewardRates[MaterialType.Paper] = 1.5 ether;
    }

    modifier onlyAdmin() {
        require(isAdmin[msg.sender], "Not an admin");
        _;
    }

    modifier onlyVendor() {
        require(isVendor[msg.sender], "Not a vendor");
        _;
    }

    modifier onlyRecyclingPersonnel() {
        require(isRecyclingPersonnel[msg.sender], "Not recycling personnel");
        _;
    }

    function addAdmin(address _admin) external onlyAdmin {
        require(_admin != address(0), "Invalid address");
        require(!isAdmin[_admin], "Already an admin");
        isAdmin[_admin] = true;
        emit AdminAdded(_admin);
    }

    function addVendor(address _vendor) external onlyAdmin {
        require(_vendor != address(0), "Invalid address");
        require(!isVendor[_vendor], "Already a vendor");
        isVendor[_vendor] = true;
        emit VendorAdded(_vendor);
    }

    function addRecyclingPersonnel(address _personnel) external onlyAdmin {
        require(_personnel != address(0), "Invalid address");
        require(!isRecyclingPersonnel[_personnel], "Already recycling personnel");
        isRecyclingPersonnel[_personnel] = true;
        emit RecyclingPersonnelAdded(_personnel);
    }

    function vendorDeposit(uint256 voucherAmount) external {
        require(voucherAmount > 0, "Voucher amount must be positive");
        require(vouchers[adminPool] + voucherAmount > vouchers[adminPool], "Overflow error");

        vouchers[adminPool] += voucherAmount;

        emit VendorDeposit(msg.sender, voucherAmount);
    }

    function depositTrash(MaterialType material, uint256 trashWeight) external {
        uint256 voucherReward = calculateReward(material, trashWeight);

        require(vouchers[adminPool] >= voucherReward, "Insufficient vouchers in admin pool");

        vouchers[adminPool] -= voucherReward;
        vouchers[msg.sender] += voucherReward;

        emit TrashDeposited(msg.sender, material, trashWeight, voucherReward);
    }

    function setRewardRate(MaterialType material, uint256 rate) external onlyAdmin {
        require(rate > 0, "Reward rate must be positive");
        rewardRates[material] = rate;
    }

    function calculateReward(MaterialType material, uint256 trashWeight) internal view returns (uint256) {
        return trashWeight * rewardRates[material];
    }

    function processTrash(uint256 trashValue) external {
        require(trashValue > 0, "Trash value must be positive");
        require(vouchers[adminPool] >= trashValue, "Insufficient vouchers for payout");

        vouchers[adminPool] -= trashValue;
        emit TrashProcessed(msg.sender, trashValue);
    }

    function withdrawPayout(
        address payable investor,
        uint256 ethAmount,
        uint256 voucherAmount
        ) external onlyAdmin {
            require(investor != address(0), "Invalid investor address");
            require(ethAmount > 0 || voucherAmount > 0, "Invalid withdrawal amounts");

            // Handle Ether payout
            if (ethAmount > 0) {
                require(address(this).balance >= ethAmount, "Insufficient contract balance");
                
                // Transfer Ether to the investor
                (bool sent, ) = investor.call{value: ethAmount}("");
                require(sent, "Failed to send Ether to investor");
            }

            // Handle Voucher payout
            if (voucherAmount > 0) {
                require(vouchers[adminPool] >= voucherAmount, "Insufficient vouchers in admin pool");

                // Transfer vouchers to the investor
                vouchers[adminPool] -= voucherAmount;
                vouchers[investor] += voucherAmount;
            }

            // Emit a withdrawal event
            emit PayoutWithdrawn(msg.sender, investor, ethAmount + voucherAmount);
    }

    function balanceOf(address account) external view returns (uint256) {
        return vouchers[account];
    }

    receive() external payable {}
}
