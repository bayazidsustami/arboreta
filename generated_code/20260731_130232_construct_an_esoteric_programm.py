import hashlib
from collections import defaultdict

class CommitNode:
    """Represents a commit in the Git DAG carrying cellular state and author metadata."""
    def __init__(self, commit_id, parents, author, payload):
        self.id = commit_id
        self.parents = parents  # Direct ancestor commits (DAG edges)
        self.children = []
        self.author = author  # Agent identifier in the multiplayer system
        self.payload = payload  # Memory state/opcode seed
        self.state = 0  # Cellular automaton state (0..3)

class GitDAGAutomatonEngine:
    """Cellular Automaton engine running over a Git commit DAG with emergent multiplayer dynamics."""
    def __init__(self):
        self.nodes = {}
        self.roots = []
        self.authors = ["Alice", "Bob", "Charlie", "Dave"]

    def create_commit(self, parents, author, payload):
        content = f"{[p.id for p in parents]}:{author}:{payload}".encode()
        commit_id = hashlib.sha1(content).hexdigest()[:8]
        node = CommitNode(commit_id, parents, author, payload)
        for p in parents:
            p.children.append(node)
        self.nodes[commit_id] = node
        if not parents:
            self.roots.append(node)
        return node

    def build_sample_history(self, seed_instructions):
        """Builds a branching/merging DAG simulating concurrent developer history."""
        genesis = self.create_commit([], "System", 0)
        genesis.state = 1
        
        last_commits = [genesis]
        for idx, instr in enumerate(seed_instructions):
            author = self.authors[idx % len(self.authors)]
            if len(last_commits) > 1 and idx % 3 == 0:
                # Merge commit (combines multiple DAG branches)
                parents = last_commits[:2]
                new_commit = self.create_commit(parents, author, instr)
                last_commits = [new_commit] + last_commits[2:]
            else:
                # Branch / sequential commit
                parent = last_commits[idx % len(last_commits)]
                new_commit = self.create_commit([parent], author, instr)
                last_commits.append(new_commit)

    def evolve_automaton(self, steps=5):
        """Applies DAG-neighbourhood consensus rules driven by author multi-agent interactions."""
        for _ in range(steps):
            next_states = {}
            for cid, node in self.nodes.items():
                # Neighborhood consists of parents (ancestors) and children (descendants)
                neighbors = node.parents + node.children
                if not neighbors:
                    continue
                
                # Multi-agent voting/consensus dynamics weighted by author presence
                same_author_count = sum(1 for n in neighbors if n.author == node.author)
                active_neighbors = sum(1 for n in neighbors if n.state > 0)
                
                # Emergent transition rule:
                # Active if balanced neighbor density or strong same-author consensus
                if node.state == 0 and (active_neighbors == 2 or same_author_count >= 1):
                    next_states[cid] = (sum(n.payload for n in neighbors) % 7) + 1
                elif node.state > 0 and (active_neighbors < 1 or active_neighbors > 3):
                    next_states[cid] = 0
                else:
                    next_states[cid] = (node.state + node.payload) % 8

            for cid, state in next_states.items():
                self.nodes[cid].state = state

class GitCAEsolangVM:
    """Esoteric VM whose execution tape and opcodes emerge directly from the Git DAG Automaton."""
    OPCODES = {
        0: "NOP",
        1: "PUSH",  # Push payload to stack
        2: "ADD",   # Pop 2, add, push
        3: "SUB",   # Pop 2, sub, push
        4: "OUT",   # Output top of stack as ASCII character
        5: "DUP",   # Duplicate top of stack
        6: "SWAP",  # Swap top two elements
        7: "HALT"   # Stop execution
    }

    def __init__(self, dag_engine):
        self.engine = dag_engine
        self.stack = []
        self.output_buffer = []

    def execute(self, max_cycles=30):
        """Executes the machine by walking the commit graph in topological order driven by CA states."""
        # Topological sort of the Git DAG
        in_degree = {cid: len(node.parents) for cid, node in self.engine.nodes.items()}
        queue = [node for node in self.engine.nodes.values() if in_degree[node.id] == 0]
        
        cycle = 0
        while queue and cycle < max_cycles:
            # Evolve automaton state each VM instruction cycle
            self.engine.evolve_automaton(steps=1)
            
            curr = queue.pop(0)
            op = self.OPCODES.get(curr.state, "NOP")
            val = curr.payload

            # Execute instruction derived from emergent state
            if op == "PUSH":
                self.stack.append(val)
            elif op == "ADD" and len(self.stack) >= 2:
                self.stack.append((self.stack.pop() + self.stack.pop()) % 256)
            elif op == "SUB" and len(self.stack) >= 2:
                b, a = self.stack.pop(), self.stack.pop()
                self.stack.append((a - b) % 256)
            elif op == "OUT" and self.stack:
                char = chr(self.stack.pop() % 128)
                self.output_buffer.append(char)
            elif op == "DUP" and self.stack:
                self.stack.append(self.stack[-1])
            elif op == "SWAP" and len(self.stack) >= 2:
                self.stack[-1], self.stack[-2] = self.stack[-2], self.stack[-1]
            elif op == "HALT":
                break

            for child in curr.children:
                in_degree[child.id] -= 1
                if in_degree[child.id] == 0:
                    queue.append(child)
            
            cycle += 1

        return "".join(self.output_buffer)

if __name__ == "__main__":
    # Payload sequence encoding target values for "HELLO" output
    source_payloads = [72, 69, 76, 76, 79, 10, 32, 42, 100, 15]
    
    # Initialize Git Commit DAG Engine
    engine = GitDAGAutomatonEngine()
    engine.build_sample_history(source_payloads)
    
    # Initialize and run Esoteric VM driven by the emergent Git CA
    vm = GitCAEsolangVM(engine)
    result = vm.execute(max_cycles=50)

    print("=== Git DAG Cellular Automaton Execution Output ===")
    print(f"Executed across {len(engine.nodes)} commit nodes.")
    print(f"Final VM Stack State : {vm.stack}")
    print(f"Emergent Output Text : {repr(result)}")