from typing import List, Set, Tuple

from .utils import init_config
from .utils_slither import *
from .rw_analysis import RWGraph


class Defi:

    def __init__(self, bmk_dir: str) -> None:
        self.config = init_config(bmk_dir)
        self.ctrt_names = self.config.contract_names
        self.sli = gen_slither(bmk_dir)
        self.ctrts = self._init_ctrts()
        self.pub_actions = self._init_pub_actions()
        self.roles = self._init_roles()

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
                if f.is_constructor or f.is_constructor_variables:
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
            self._rw_graph = self._analyze_rw()
        return self._rw_graph

    def _analyze_rw(self) -> RWGraph:
        static_graph = RWGraph()
        for f in self.pub_actions:
            sv_read, sv_written = self.track_var_without_addr(f)
            for r in sv_read:
                if r in static_graph:
                    source_node = static_graph[r]
                else:
                    source_node = static_graph.add_node(r)
                for w in sv_written:
                    if w in static_graph:
                        dest_node = static_graph[w]
                    else:
                        dest_node = static_graph.add_node(w)
                    static_graph.add_edge(source_node, dest_node, f)
        return static_graph
    
    def get_external_call_func(self, e_call_expr: SliExpression) -> SliFunction:
        called: SliMemberAccess = e_call_expr.called
        called_expression: SliIdentifier = called.expression
        if called_expression.value is None:
            pass
        print(1)

    def track_var_without_addr(self, func: SliFunction) -> Tuple[Set[SliVariable], Set[SliVariable]]:
        """
        This track algorithm is imprecise, because it doesn't inline the address information.
        """
        # Analyze normal storage variables usage.
        sv_read = set(func.state_variables_read)
        sv_written = set(func.state_variables_written)

        # Analyze external calls.
        for e_call_expr in func.external_calls_as_expressions:
            e_call = self.get_external_call_func(e_call_expr)
            e_sv_read, e_sv_written = self.track_var_without_addr(e_call)
            sv_read = sv_read.union(e_sv_read)
            sv_written = sv_written.union(e_sv_written)

        # Analyze internal calls
        for i_call in func.internal_calls:
            if isinstance(i_call, SliFunction):
                i_sv_read, i_sv_written = self.track_var_without_addr(i_call)
                sv_read = sv_read.union(i_sv_read)
                sv_written = sv_written.union(i_sv_written)
        return sv_read, sv_written

    def print_rw_graph(self, output_path: str):
        self.rw_graph.draw_graphviz(output_path)