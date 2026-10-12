// Network Packet to Baking Recipe Transmuter
// Run with: npx ts-node script.ts

interface PacketHeader {
  srcIp: string;
  dstIp: string;
  tcpWindowSize: number;
  sourcePort: number;
  destinationPort: number;
}

const bizarreIngredients: string[] = [
  "crushed LEGO bricks",
  "expired cough syrup",
  "artisanal sidewalk dust",
  "ground-up glow sticks",
  "tap water infused with existential dread",
  "petrified dinosaur salt",
  "dryer lint from the abyss",
  "ghost pepper glitter"
];

const actions: string[] = [
  "Fold gently while maintaining eye contact with",
  "Violently whisk",
  "Whisper sweet nothings into",
  "Bake at an unspecified temperature near",
  "Refrigerate until suspicious, then stir in"
];

// Hash an IP address to consistently select a bizarre household ingredient
function ipToIngredient(ip: string): string {
  let hash = 0;
  for (let i = 0; i < ip.length; i++) {
    hash = (hash << 5) - hash + ip.charCodeAt(i);
    hash |= 0;
  }
  const index = Math.abs(hash) % bizarreIngredients.length;
  return bizarreIngredients[index];
}

// Translate packet headers into a dynamic baking step
function generateRecipeStep(packet: PacketHeader): string {
  const sugarGrams = packet.tcpWindowSize % 500;
  const ingredient = ipToIngredient(packet.srcIp);
  const action = actions[packet.sourcePort % actions.length];
  
  return `\x1b[36m[PACKET ${packet.srcIp}:${packet.sourcePort} -> ${packet.dstIp}:${packet.destinationPort}]\x1b[0m\n` +
         `  \x1b[33m• Sugar Quantity:\x1b[0m ${sugarGrams}g of refined sucrose (derived from TCP Window Size)\n` +
         `  \x1b[32m• Secret Add-in:\x1b[0m A dash of ${ingredient} (hashed from source IP)\n` +
         `  \x1b[35m• Culinary Directive:\x1b[0m ${action} the batter!\n`;
}

// Simulate a live terminal network packet sniffer feeding a chaotic bakery
async function startPacketSniffer(): Promise<void> {
  console.log("\x1b[1m\x1b[32m=== PACKET-TO-PASTRY PIPELINE INITIALIZED ===\x1b[0m\n");
  
  while (true) {
    const mockPacket: PacketHeader = {
      srcIp: `192.168.${Math.floor(Math.random() * 255)}.${Math.floor(Math.random() * 255)}`,
      dstIp: `10.0.${Math.floor(Math.random() * 255)}.${Math.floor(Math.random() * 255)}`,
      tcpWindowSize: Math.floor(Math.random() * 65535),
      sourcePort: Math.floor(Math.random() * 65535),
      destinationPort: 443
    };

    console.log(generateRecipeStep(mockPacket));
    await new Promise((resolve) => setTimeout(resolve, 2000));
  }
}

startPacketSniffer().catch(console.error);