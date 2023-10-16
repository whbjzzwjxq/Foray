import os
import subprocess
from os import path
from typing import Dict, List, Tuple

from .config import Config, init_config, AttackCtrtName
from .dsl import *
from .synthesizer import Synthesizer
from .utils import CornerCase


class BenchmarkBuilder:
    """
    Used for building test sol contract to do the test.
    """

    uniswap_pair_ctrt = "UniswapV2Pair"
    uniswap_factory_ctrt = "UniswapV2Factory"
    uniswap_router_ctrt = "UniswapV2Router"
    attack_ctrt = "AttackContract"
    default_erc20_tokens = [
        "USDCE",
        "USDT",
        "WETH",
        "WBNB",
    ]
    default_import_ctrts = [
        *default_erc20_tokens,
        uniswap_pair_ctrt,
        uniswap_factory_ctrt,
        uniswap_router_ctrt,
    ]

    def __init__(self, bmk_dir: str) -> None:
        self.bmk_dir = bmk_dir
        self.config: Config = init_config(bmk_dir)
        self.name = self.config.project_name
        self.roles = self.config.roles

        # Map contract's variable name to its contract label.
        self.ctrt_name2cls = {name: cls for name, cls in self.config.ctrt_name2cls}
        self.ctrt_name2deploy = self.config.ctrt_name2deploy
        # Like pair, router, usdt, etc.
        self.ctrt_names = list(self.ctrt_name2cls.keys())
        # Like UniswapV2Router, USDCE, USDT, etc.
        self.ctrt_cls = set(self.ctrt_name2cls.values())

        self.attack_goal = self.config.attack_goal
        self.extra_actions = self.config.extra_actions
        self.extra_deployments = self.config.extra_deployments
        self.extra_statements = self.config.extra_statements

        # Uniswap pairs.
        self.uniswap_pairs: List[str] = [
            name for name, role in self.roles.items() if role.is_uniswap
        ]

        # Uniswap pairs to token_names
        self.uniswap_pair2tokens: Dict[str, Tuple[str, str]] = {
            u: tuple(self.roles[u].uniswap_order) for u in self.uniswap_pairs
        }

        # ERC20 tokens.
        self.erc20_tokens = [name for name, role in self.roles.items() if role.is_erc20]

        # Map state_variable name to its type and initial value.
        self.init_state: Dict[str, Tuple[str, str]] = {}

        # Will print token_users' initial balances.
        self.token_users = [c for c in self.ctrt_names if c in self.roles]

        actions = [init_action_from_list(a, True) for a in self.config.groundtruth]
        self.gt_sketch = Sketch(actions)

    def get_initial_state(self) -> List[str]:
        # Handle the initial states print by foundry.
        # Look at: QueryBlockchain.sol and query_output_example.txt for more information.
        cache_file = path.join(self.bmk_dir, "result", "_query.cache")
        if path.exists(cache_file):
            with open(cache_file, "r") as f:
                outputs = f.readlines()
                outputs = [l.removesuffix("\n") for l in outputs]
        else:
            cmd = [
                "forge",
                "test",
                "-vv",
                "--match-path",
                f"{self.bmk_dir}/{self.name}_query.t.sol",
            ]
            print(" ".join(cmd))
            try:
                proc = subprocess.run(
                    cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                    cwd=os.getcwd(),
                    check=True,
                )
            except Exception as err:
                err.add_note("Forge test failed!")
                raise err
            outputs = proc.stdout + proc.stderr
            with open(cache_file, "w") as f:
                f.write(outputs)
            outputs = outputs.split("\n")
        states = []
        for output in outputs:
            if output.startswith("  ----"):
                continue
            if output == "":
                continue
            if not output.startswith("  "):
                continue
            result = [s for s in output.split(" ") if s != ""]
            if len(result) != 3:
                continue
            type_str, sv_name, sv_val = result
            type_str = type_str.removeprefix(" ")
            sv_name = sv_name.removesuffix(":")
            self.init_state[sv_name] = (type_str, sv_val)
            output_str = f"{type_str} {sv_name} = {sv_val};"
            states.append(output_str)
        return states

    def gen_imports(self) -> List[str]:
        license = "// SPDX-License-Identifier: MIT"
        pragma = "pragma solidity ^0.8.0;"
        imports = [
            'import "forge-std/Test.sol";',
            'import "@utils/QueryBlockchain.sol";',
        ]
        for c in self.ctrt_cls:
            if c in self.default_import_ctrts:
                imports.append(f'import {{{c}}} from "@utils/{c}.sol";')
            else:
                imports.append(f'import "./{c}.sol";')
        imports = sorted(imports)
        all = [license, pragma, *imports]
        return all

    def gen_contract_header(self) -> List[str]:
        return [f"contract {self.name}Test is Test, BlockLoader " + "{"]

    def gen_state_varibles(self) -> List[str]:
        contract_interfaces = [f"{v} {k};" for k, v in self.ctrt_name2cls.items()]
        users = [
            f"address owner;",
            f"address attacker;",
            *[f"address {c}Addr;" for c in self.ctrt_names],
        ]
        states = self.get_initial_state()
        all = [*contract_interfaces, *users, *states]
        return all

    def gen_setup(self) -> List[str]:
        all = [
            "function setUp() public {",
            "owner = address(this);",
        ]

        # Deploy contracts
        for ctrt_name, stmt in self.ctrt_name2deploy:
            # Default deployment
            if stmt == "":
                ctrt_label = self.ctrt_name2cls[ctrt_name]
                if ctrt_label in self.default_erc20_tokens:
                    d_stmt = f"{ctrt_name} = new {ctrt_label}();"

                elif ctrt_label == self.uniswap_pair_ctrt:
                    token0, token1 = self.uniswap_pair2tokens[ctrt_name]
                    d_stmt = f"{ctrt_name} = new {self.uniswap_pair_ctrt}(\
                        address({token0}), address({token1}), \
                        reserve0{ctrt_name}, reserve1{ctrt_name}, \
                        blockTimestampLast{ctrt_name}, kLast{ctrt_name}, \
                        price0CumulativeLast{ctrt_name}, price1CumulativeLast{ctrt_name});"

                elif ctrt_label == self.uniswap_factory_ctrt:
                    pairs = self.uniswap_pairs
                    if len(pairs) > 3:
                        raise ValueError("More than 3 pairs are not supported.")
                    addrs = [
                        f"address({pairs[i]})" if i < len(pairs) else "address(0x0)"
                        for i in range(3)
                    ]
                    params = ["address(0xdead)", *addrs]
                    d_stmt = f'{ctrt_name} = new {self.uniswap_factory_ctrt}({",".join(params)});'

                elif ctrt_label == self.uniswap_router_ctrt:
                    d_stmt = f"{ctrt_name} = new {self.uniswap_router_ctrt}(address(factory), address(0xdead));"
                elif ctrt_label == self.attack_ctrt:
                    d_stmt = f"{ctrt_name} = new {self.attack_ctrt}();"
                else:
                    raise CornerCase(f"Unsupported default deployment: {ctrt_label}")
            else:
                d_stmt = f"{ctrt_name} = {stmt};"
            all.append(d_stmt)
            all.append(f"{ctrt_name}Addr = address({ctrt_name});")

        all.append(f"attacker = address({AttackCtrtName});")
        all.extend(self.extra_deployments)

        all.append("// Initialize balances and mock flashloan.")

        # Deploy tokens
        for u in self.token_users:
            addr = f"address({u})"
            for t in self.erc20_tokens:
                if u == AttackCtrtName:
                    sv_name = f"balanceOf{t}attacker"
                else:
                    sv_name = f"balanceOf{t}{u}"
                _, val = self.init_state.get(sv_name, ("uint256", "0"))
                if val != "0":
                    stmt = f"{t}.transfer({addr}, {sv_name});"
                    all.append(stmt)

                # Use approve-transfer to mock flashloan
                if u == AttackCtrtName:
                    all.append(f"{t}.approve(attacker, UINT256_MAX);")

        all.append("}")
        return all

    def gen_helper_funcs(self) -> List[str]:
        # Print balance.
        printer = [
            "function printBalance(string memory tips) public {",
            "emit log_string(tips);",
        ]
        for u in self.token_users:
            addr = f"address({u})"
            printer.append(f'emit log_string("{u.capitalize()} Balances: ");')
            for t in self.erc20_tokens:
                printer.append(
                    f"queryERC20BalanceDecimals(address({t}), {addr}, {t}.decimals());"
                )
            printer.append('emit log_string("");')
        printer.append('emit log_string("");')
        printer.append('emit log_string("");')
        printer.append("}")

        # Attack goal
        token, amount = self.attack_goal
        attack_goal_func = [
            "function attackGoal() public view returns (bool) {",
            f"return {token}.balanceOf(attacker) >= {amount} + balanceOf{token}attacker;",
            "}",
        ]

        nop = ["function nop(uint256 amount) internal pure {", "return;", "}"]

        return [*printer, *attack_goal_func, *nop]

    def gen_actions(self) -> List[str]:
        # Actions
        actions = []
        extra_actions = self.config.extra_actions
        func_name_regex = re.compile(r"function (.*?)\(")
        extra_action_names = set(
            [func_name_regex.match(a).group(1) for a in extra_actions]
        )

        def add_func_to_actions(func_body: str):
            func_name = func_name_regex.match(func_body[0]).group(1)
            if func_name not in extra_action_names:
                actions.extend(func_body)

        # flashloan borrow-payback
        for t in self.erc20_tokens:
            borrow = [
                f"function borrow_{t}(uint256 amount) internal " + "{",
                f"{t}.transferFrom(owner, attacker, amount);",
                "}",
            ]
            payback = [
                f"function payback_{t}(uint256 amount) internal " + "{",
                f"{t}.transfer(owner, amount);",
                "}",
            ]
            add_func_to_actions(borrow)
            add_func_to_actions(payback)

        # swap by uniswap
        router_name = "router"
        for u, t in self.uniswap_pair2tokens.items():
            token0, token1 = t
            swap0 = [
                f"function swap_{u}_{token0}_{token1}(uint256 amount) internal" + "{",
                f"{token0}.approve(address({router_name}), type(uint).max);",
                f"address[] memory path = new address[](2);",
                f"path[0] = address({token0});",
                f"path[1] = address({token1});",
                f"router.swapExactTokensForTokensSupportingFeeOnTransferTokens( \
                    amount, 1, path, attacker, block.timestamp);",
                "}",
            ]
            add_func_to_actions(swap0)
            token1, token0 = t
            swap1 = [
                f"function swap_{u}_{token0}_{token1}(uint256 amount) internal" + "{",
                f"{token0}.approve(address({router_name}), type(uint).max);",
                f"address[] memory path = new address[](2);",
                f"path[0] = address({token0});",
                f"path[1] = address({token1});",
                f"router.swapExactTokensForTokensSupportingFeeOnTransferTokens( \
                    amount, 1, path, attacker, block.timestamp);",
                "}",
            ]
            add_func_to_actions(swap1)

        # sync uniswap
        for uniswap in self.uniswap_pairs:
            sync = [
                f"function sync_{uniswap}() internal" + "{",
                f"{uniswap}.sync();",
                "}",
            ]
            add_func_to_actions(sync)

        return [*actions, *self.extra_actions]

    def gen_gt_for_forge_and_halmos(self) -> List[str]:
        # Build groundtruth test for forge
        test_gt = self.gt_sketch.output_verify(
            "test_gt", self.extra_statements, print_balance=True
        )
        check_gt = self.gt_sketch.symbolic_copy().output(
            "check_gt", self.extra_statements
        )
        all = [*test_gt, *check_gt]
        return all

    def gen_candidates(self) -> List[str]:
        synthesizer = Synthesizer(self.config)
        func_bodys: List[str] = []
        for idx, c in enumerate(synthesizer.candidates):
            func_bodys.extend(
                c.output(
                    f"check_cand{str(idx).zfill(ZFILL_SIZE)}", self.extra_statements
                )
            )
        return func_bodys

    def output(self, output_path: str):
        results = [
            *self.gen_imports(),
            *self.gen_contract_header(),
            *self.gen_state_varibles(),
            *self.gen_setup(),
            *self.gen_helper_funcs(),
            *self.gen_actions(),
            *self.gen_gt_for_forge_and_halmos(),
            *self.gen_candidates(),
            "}",
        ]
        with open(output_path, "w") as f:
            for l in results:
                f.write(l)
                f.write("\n")

    def output_verify(
        self, verifiers: List[Tuple[str, Sketch, List[List[str]]]], output_path: str
    ):
        results = [
            "// SPDX-License-Identifier: MIT",
            "pragma solidity ^0.8.10;",
            f'import "./{self.name}.t.sol";',
            f"contract {self.name}Verify is {self.name}Test" + "{",
        ]
        for func_name, candidate, arg_candidates in verifiers:
            if len(arg_candidates) == 0:
                continue
            for j, args in enumerate(arg_candidates):
                jdx = str(j).zfill(3)
                actual_name = f"test_verify_{func_name}_{jdx}"
                concre_sketch = candidate.concretize(args)
                results.extend(
                    concre_sketch.output_verify(actual_name, self.extra_statements)
                )
        results.extend(["}"])
        with open(output_path, "w") as f:
            for l in results:
                f.write(l)
                f.write("\n")


def get_sketch_by_func_name(b: BenchmarkBuilder, s: Synthesizer, func_name: str):
    if func_name == "check_gt":
        sketch = b.gt_sketch.symbolic_copy()
    else:
        sketch = s.candidates[int(func_name.removeprefix("check_cand"))]
    return sketch