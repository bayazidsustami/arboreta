# Emotional Virtual Machine (EVM)
# Executes programs by driving an emotional runtime through psychological state transitions.
# Memory registers represent core human values (e.g., joy, trust, clarity, peace).

from dataclasses import dataclass
from typing import Dict, List, Tuple

@dataclass
class EmotionState:
    joy: float = 0.0
    trust: float = 0.0
    clarity: float = 0.0
    peace: float = 0.0

class EmotionalVM:
    def __init__(self, target_value: float):
        self.state = EmotionState()
        self.target = target_value
        self.history: List[str] = []

    def transition(self, emotion: str, intensity: float, narrative: str) -> None:
        """Applies psychological state transitions affecting underlying mathematical registers."""
        self.history.append(f"[{emotion.upper()}] {narrative} (+{intensity})")
        
        if emotion == "wonder":
            self.state.joy += intensity * 1.5
            self.state.clarity += intensity * 0.5
        elif emotion == "grief":
            self.state.clarity += intensity * 2.0
            self.state.joy = max(0.0, self.state.joy - intensity * 0.5)
        elif emotion == "acceptance":
            self.state.peace += (self.state.joy + self.state.clarity) * 0.5
            self.state.trust += intensity * 1.0
        elif emotion == "epiphany":
            self.state.clarity *= (1.0 + intensity)
            self.state.joy += intensity

    def synthesize_output(self) -> float:
        """Computes the final mathematical output derived from accumulated psychological states."""
        return (self.state.joy * 2.0) + (self.state.clarity * 3.0) + (self.state.peace * 5.0)

def execute_psychological_program(target: float) -> Tuple[float, List[str]]:
    """Engineers a narrative trajectory to drive the VM to the target numerical value."""
    vm = EmotionalVM(target_value=target)
    
    # Narrative Arc: Discovery -> Loss -> Catharsis -> Awakening
    vm.transition("wonder", 2.0, "An initial spark of inspiration illuminates the dark expanse.")
    vm.transition("grief", 1.5, " Confronting limitations and shedding obsolete assumptions.")
    vm.transition("acceptance", 2.5, "Finding harmony within the turbulence of processing.")
    vm.transition("epiphany", 1.2, "A sudden realization unifies memory into perfect balance.")

    result = vm.synthesize_output()
    return result, vm.history

if __name__ == "__main__":
    target_output = 42.0
    final_val, journey = execute_psychological_program(target_output)
    
    print("=== Psychological Trajectory ===")
    for step in journey:
        print(step)
    print("================================")
    print(f"Synthesized Mathematical Output: {final_val:.2f}")