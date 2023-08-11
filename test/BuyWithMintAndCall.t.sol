// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import "../contracts/Token.sol";
import "../contracts/FeeSettings.sol";
import "../contracts/ContinuousFundraising.sol";
import "./resources/MintAndCallToken.sol";
import "./resources/MaliciousPaymentToken.sol";
import "../contracts/Wallet.sol";

contract BuyWithMintAndCall is Test {
    ContinuousFundraising raise;
    AllowList list;
    IFeeSettingsV1 feeSettings;

    Token token;
    MintAndCallToken paymentToken;
    Wallet wallet;

    address public constant admin = 0x0109709eCFa91a80626FF3989D68f67f5b1dD120;
    address public constant buyer = 0x1109709ecFA91a80626ff3989D68f67F5B1Dd121;
    address public constant mintAllower = 0x2109709EcFa91a80626Ff3989d68F67F5B1Dd122;
    address public constant minter = 0x3109709ECfA91A80626fF3989D68f67F5B1Dd123;
    address public constant owner = 0x6109709EcFA91A80626FF3989d68f67F5b1dd126;
    address public constant receiver = 0x7109709eCfa91A80626Ff3989D68f67f5b1dD127;
    address public constant paymentTokenProvider = 0x8109709ecfa91a80626fF3989d68f67F5B1dD128;
    address public constant trustedForwarder = 0x9109709EcFA91A80626FF3989D68f67F5B1dD129;

    uint8 public constant paymentTokenDecimals = 6;
    uint256 public constant paymentTokenAmount = 1000 * 10 ** paymentTokenDecimals;

    uint256 public constant price = 7 * 10 ** paymentTokenDecimals; // 7 payment tokens per token

    uint256 public constant maxAmountOfTokenToBeSold = 20 * 10 ** 18; // 20 token
    uint256 public constant maxAmountPerBuyer = maxAmountOfTokenToBeSold / 2; // 10 token
    uint256 public constant minAmountPerBuyer = 1;

    function setUp() public {
        list = new AllowList();
        Fees memory fees = Fees(100, 100, 100, 100);
        feeSettings = new FeeSettings(fees, admin);

        token = new Token(trustedForwarder, feeSettings, admin, list, 0x0, "TESTTOKEN", "TEST");

        // set up currency
        vm.startPrank(paymentTokenProvider);
        paymentToken = new MintAndCallToken(paymentTokenDecimals);
        vm.stopPrank();

        vm.prank(owner);
        raise = new ContinuousFundraising(
            trustedForwarder,
            payable(receiver),
            0,
            type(uint256).max,
            price,
            type(uint256).max,
            paymentToken,
            token
        );

        // allow raise contract to mint
        bytes32 roleMintAllower = token.MINTALLOWER_ROLE();

        vm.prank(admin);
        token.grantRole(roleMintAllower, mintAllower);
        vm.prank(mintAllower);
        token.increaseMintingAllowance(address(raise), type(uint256).max);

        // give raise contract allowance
        vm.prank(buyer);
        paymentToken.approve(address(raise), paymentTokenAmount);

        // create wallet
        vm.prank(owner);
        wallet = new Wallet(raise);
    }

    function testBuyHappyCase(uint256 currencyMintAmount) public {
        vm.assume(UINT256_MAX / 10 ** token.decimals() > currencyMintAmount); // this will cause an overflow on multiplication
        vm.assume(raise.calculateBuyAmount(currencyMintAmount) > 0);

        bytes32 buyersIbanHash = keccak256(abi.encodePacked("DE1234567890"));
        // add buyers address to wallet
        vm.prank(owner);
        wallet.set(buyersIbanHash, buyer);

        // make sure buyer has no tokens before
        assertTrue(token.balanceOf(buyer) == 0);

        // mint currency
        bytes memory data = abi.encode(buyersIbanHash, 0xDEADBEEF);
        vm.prank(paymentTokenProvider);
        paymentToken.mintAndCall(address(wallet), currencyMintAmount, data);

        // make sure buyer has tokens after
        assertTrue(token.balanceOf(buyer) > 0, "buyer has no tokens after buy");
    }

    function testBuyReverts() public {
        bytes32 buyersIbanHash = keccak256(abi.encodePacked("DE1234567890"));
        // add buyers address to wallet
        vm.prank(owner);
        wallet.set(buyersIbanHash, buyer);

        uint currencyMintAmount = 1;

        // make sure buyer has no tokens before
        assertTrue(token.balanceOf(buyer) == 0);

        // mint currency (not enough for the buy)
        bytes memory data = abi.encode(buyersIbanHash, 0xDEADBEEF);

        vm.prank(paymentTokenProvider);
        paymentToken.mintAndCall(address(wallet), currencyMintAmount, data);

        // make sure buyer has no tokens after
        assertTrue(token.balanceOf(buyer) == 0);
    }
}
