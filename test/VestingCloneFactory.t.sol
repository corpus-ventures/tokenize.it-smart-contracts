// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import "../lib/forge-std/src/Test.sol";
import "../contracts/VestingCloneFactory.sol";

contract VestingCloneFactoryTest is Test {
    VestingWalletUpgradeable implementation;
    VestingCloneFactory factory;

    address trustedForwarder = address(1);

    function setUp() public {
        implementation = new VestingWalletUpgradeable(trustedForwarder);

        factory = new VestingCloneFactory(address(implementation));
    }

    function testAddressPrediction(bytes32 _salt, address _trustedForwarder, address _owner) public {
        vm.assume(_trustedForwarder != address(0));
        vm.assume(_owner != address(0));
        VestingWalletUpgradeable _implementation = new VestingWalletUpgradeable(_trustedForwarder);
        VestingCloneFactory _factory = new VestingCloneFactory(address(_implementation));

        bytes32 salt = keccak256(abi.encodePacked(_salt, _trustedForwarder, _owner));
        address expected1 = _factory.predictCloneAddress(salt);
        address expected2 = _factory.predictCloneAddress(_salt, _trustedForwarder, _owner);
        assertEq(expected1, expected2, "address prediction with salt and params not equal");

        address actual = _factory.createVestingClone(_salt, _trustedForwarder, _owner);
        assertEq(expected1, actual, "address prediction failed");
    }

    function testSecondDeploymentFails(bytes32 _salt, address _owner) public {
        vm.assume(_onwer != address(0));

        factory.createVestingClone(_salt, trustedForwarder, _owner);

        vm.expectRevert("ERC1167: create2 failed");
        factory.createVestingClone(_salt, trustedForwarder, _owner);
    }

    function testInitialization(bytes32 _salt, address _owner) public {
        vm.assume(_owner != address(0));

        VestingWalletUpgradeable clone = VestingWalletUpgradeable(
            factory.createVestingClone(_salt, trustedForwarder, _owner)
        );

        // test constructor arguments are used
        assertEq(clone.owner(), _owner, "name not set");

        // check trustedForwarder is set
        assertTrue(clone.isTrustedForwarder(trustedForwarder), "trustedForwarder not set");

        // test contract can not be initialized again
        vm.expectRevert("Initializable: contract is already initialized");
        clone.initialize(feeSettings, admin, allowList, requirements, "testToken", "TEST");
    }
}
