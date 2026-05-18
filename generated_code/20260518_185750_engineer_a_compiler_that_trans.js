(function() {
  // Define logic gates as functions with stateful modification
  const gates = [
    (s) => s && true, // AND: requires previous state
    (s) => s || false, // OR: always true if any input
    (s) => !s, // NOT: inverts state
    (s) => s ^ true // XOR: flips state
  ];
  
  // Rhythm input: beat durations controlling fractal depth/gate selection
  const rhythm = [4, 2, 1, 3]; // Example pattern
  
  // Self-modifying fractal generator
  function fractal(rhythm, depth = 0, state = true) {
    if (depth > 8) return [];
    const beat = rhythm[depth % rhythm.length];
    const gate = gates[beat % gates.length];
    const newState = gate(state);
    
    // Self-modification: gate output alters next levels
    return [{ gateName: gate.name, state: newState }, ...fractal(rhythm, depth+1, newState)];
  }
  
  // Generate and expose fractal structure
  const landscape = fractal(rhythm);
  landmark = landscape.map((node, i) => ({ 
    x: Math.sin(i/10)*10, 
    y: Math.cos(i/10)*10, 
    gate: node.gateName, 
    active: node.state 
  }));
})();