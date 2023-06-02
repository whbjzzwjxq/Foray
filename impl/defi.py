from typing import List, Set, Tuple, Optional, Dict

from .utils import init_config, CornerCase
from .utils_slither import *
from .rw_analysis import RWGraph

RW_SET = Tuple[Set[SliVariable], Set[SliVariable]]


class Defi:

    def __init__(self, bmk_dir: str) -> None:
        self.config = init_config(bmk_dir)
        self.ctrt_names = self.config.contract_names
        self.sli = gen_slither(bmk_dir)
        self.ctrts = self._init_ctrts()
        self.pub_actions = self._init_pub_actions()
        self.roles = self._init_roles()
        self.rw_set: Dict[str, RW_SET] = {}

        self._rw_graph = None

    def _init_ctrts(self) -> List[SliContract]:
        actual_ctrts = []
        for ctrt in self.sli.contracts:
            if ctrt.name in self.ctrt_names:
                actual_ctrts.append(ctrt)
        return actual_ctrts

    def _init_pub_actions(self) -> List[SliFunction]:
        pub_actions = []
        for ctrt in self.ctrts:
            for f in ctrt.functions:
                if f.is_constructor or f.is_constructor_variables or not f.is_implemented:
                    continue
                if f.pure or f.view or f.visibility in ("internal", "private"):
                    continue
                pub_actions.append(f)
        return pub_actions

    def _init_roles(self) -> List[str]:
        # TODO
        # We have to decide the range of roles.
        roles = [
            "attacker",
            "owner",
        ]
        return roles

    @property
    def rw_graph(self) -> RWGraph:
        if self._rw_graph is None:
            self._rw_graph = self._init_rw_graph()
        return self._rw_graph

    def _init_rw_graph(self) -> RWGraph:
        static_graph = RWGraph()
        for f in self.pub_actions:
            sv_read, sv_written = self.get_func_rw_set(f)
            source_nodes = static_graph.add_or_get_nodes(sv_read)
            dest_nodes = static_graph.add_or_get_nodes(sv_written)
            if len(source_nodes) == 0 and len(dest_nodes) == 0:
                continue
            static_graph.add_edge(source_nodes, dest_nodes, f)
        return static_graph

    def get_contract_by_name(self, name: str) -> Optional[SliContract]:
        for ctrt in self.ctrts:
            if ctrt.name == name:
                return ctrt
        return None

    def get_func_rw_set(self, func: SliFunction) -> RW_SET:
        if func.canonical_name not in self.rw_set:
            s = self.track_var_without_addr(func)
            self.rw_set[func.canonical_name] = s
        return self.rw_set[func.canonical_name]

    def get_external_call_func(self, e_call_expr: SliExpression) -> Optional[SliFunction]:
        called: SliMemberAccess = e_call_expr.called
        called_expression: SliIdentifier = called.expression
        called_value: SliVariable = called_expression.value
        # Call Library: Math.min(a, b);
        if isinstance(called_value, SliContract):
            if called_value.is_library:
                return None
            else:
                raise CornerCase("TODO")
        # Call Initialized Contract: token.transferFrom(a, b, amt);
        elif isinstance(called_value, SliStateVariable):
            tgt_ctrt_name = self.config.contract_names_mapping.get(
                called_value.canonical_name, None)
            tgt_ctrt = self.get_contract_by_name(tgt_ctrt_name)
            return get_function_from_name(tgt_ctrt, called.member_name)
        else:
            raise CornerCase("TODO")

    def track_var_without_addr(self, func: SliFunction) -> RW_SET:
        """
        This track algorithm is imprecise, because it doesn't inline the address information.
        """
        # Analyze normal storage variables usage.
        sv_read = set(func.state_variables_read)
        sv_written = set(func.state_variables_written)

        # Analyze external calls.
        for e_call_expr in func.external_calls_as_expressions:
            e_call = self.get_external_call_func(e_call_expr)
            if e_call is None:
                continue
            e_sv_read, e_sv_written = self.get_func_rw_set(e_call)
            sv_read = sv_read.union(e_sv_read)
            sv_written = sv_written.union(e_sv_written)

        # Analyze internal calls
        for i_call in func.internal_calls:
            if isinstance(i_call, SliFunction):
                i_sv_read, i_sv_written = self.get_func_rw_set(i_call)
                sv_read = sv_read.union(i_sv_read)
                sv_written = sv_written.union(i_sv_written)

        sv_read_n = set()
        for sv in sv_read:
            # Remove constant, immutable variables
            if sv.is_constant or sv.is_immutable:
                continue
            # Remove contract variable
            if sv.name in self.config.contract_names_mapping:
                continue
            sv_read_n.add(sv)
        return sv_read_n, sv_written

    def print_rw_graph(self, output_path: str):
        self.rw_graph.draw_graphviz(output_path)

    def iter_synthesis_candidates(self, max_step: int = 10):
        pass
