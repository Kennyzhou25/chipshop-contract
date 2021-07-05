pragma solidity ^0.4.0;

import "./interfaces/IBasisAsset.sol";

contract TokenMigration {

    IBasisAsset public oldChip = IBasisAsset(0x7a4Feb21b86281F7D345dEDE500c9C51881b948B);
    IBasisAsset public oldFish = IBasisAsset(0xD47c524ae4Cf0f941D0Dd03b44CD9C80dd4238d6);
    IBasisAsset public oldMpea = IBasisAsset(0x23A47619f784F109582f07C01D8a72512ba9D0E1);

    IBasisAsset public newChip;
    IBasisAsset public newFish;
    IBasisAsset public newMpea;

    constructor(IBasisAsset _newChip, IBasisAsset _newFish, IBasisAsset _newMpea) {
        newFish = _newFish;
        newFish = _newFish;
        newMpea = _newMpea;
    }

    function migrateChip() external {
        uint256 oldBalance = oldChip.balanceOf(msg.sender);
        oldChip.burnFrom(msg.sender, oldBalance);
        newChip.mint(msg.sender, oldBalance);
    }

    function migrateFish() external {
        uint256 oldBalance = oldFish.balanceOf(msg.sender);
        oldFish.burnFrom(msg.sender, oldBalance);
        newFish.mint(msg.sender, oldBalance);
    }

    function migrateMpea() external {
        uint256 oldBalance = oldMpea.balanceOf(msg.sender);
        oldMpea.burnFrom(msg.sender, oldBalance);
        newMpea.mint(msg.sender, oldBalance);
    }
}
