// Procedural Poetry Image Compressor & Esoteric Tree Reconstructor
// This script takes a binary image silhouette, compresses it into a "procedural poem",
// and generates an executable JavaScript poem that dynamically grows the silhouette as an ASCII tree.

const ImagePoetryCompressor = {
    // Compresses a 2D binary matrix (1 for silhouette, 0 for empty space) into poetic stanzas
    compress: function(matrix) {
        const height = matrix.length;
        const width = matrix[0].length;
        let rle = [];
        let currentBit = 0;
        let count = 0;

        // Flatten matrix and perform Run-Length Encoding (RLE)
        for (let r = 0; r < height; r++) {
            for (let c = 0; c < width; c++) {
                if (matrix[r][c] === currentBit) {
                    count++;
                } else {
                    rle.push(count);
                    currentBit = matrix[r][c];
                    count = 1;
                }
            }
        }
        rle.push(count);

        // Vocabulary maps to translate run lengths into poetic imagery
        // Syllable/word lengths correspond to counts using a base-metaphor lexicon
        const nouns = ["shadow", "branch", "leaf", "root", "silence", "whisper", "forest", "canopy", "timber", "sprout"];
        const verbs = ["grows", "reaches", "fades", "clings", "awakens", "dances", "sleeps", "breathes", "extends", "twists"];
        const adjs  = ["dark", "ancient", "silent", "hidden", "living", "wooden", "green", "hollow", "wild", "still"];

        let poemLines = [];
        for (let i = 0; i < rle.length; i++) {
            let val = rle[i];
            // Encode value into a poetic phrase: Adjective (tens), Noun (ones), Verb (remainder)
            let a = adjs[Math.floor(val / 100) % adjs.length];
            let n = nouns[Math.floor(val / 10) % nouns.length];
            let v = verbs[val % verbs.length];
            
            poemLines.push(`The ${a} ${n} ${v}. /* ${val} */`);
        }

        // Construct the esoteric self-executing script
        const esotericScript = `
/*--- PROCEDURAL SILHOUETTE POEM ---*/
const verses = [
    ${poemLines.map(line => `"${line}"`).join(",\n    ")}
];

// The Esoteric Decoder and Tree Animator
(function awaken(canvasWidth, canvasHeight) {
    // Extract the encoded structural matrix numbers via regex from the poem's comments
    const memory = verses.map(v => parseInt(v.match(/\\/\\* (\\d+) \\*\\//)[1]));
    let stream = "";
    let bit = 0;

    // Reconstruct the raw binary stream
    memory.forEach(count => {
        stream += String(bit).repeat(count);
        bit = 1 - bit;
    });

    let cursor = 0;
    let frame = 0;
    
    // Dynamically grow the silhouette upward like a tree
    const growthInterval = setInterval(() => {
        if (frame > canvasHeight) {
            clearInterval(growthInterval);
            return;
        }
        
        console.clear();
        console.log("%c=== THE LIVING SILHOUETTE SILENTLY GROWS ===", "color: #2e7d32; font-weight: bold;");
        
        // Render up to the current growth frame
        for (let r = 0; r < canvasHeight; r++) {
            if (r > frame) break;
            let line = "";
            for (let c = 0; c < canvasWidth; c++) {
                let idx = r * canvasWidth + c;
                if (idx < stream.length) {
                    // 1 renders as organic foliage/bark texture, 0 as space
                    line += stream[idx] === "1" ? "♣" : " ";
                }
            }
            // Only print if the line contains parts of the tree
            if (line.trim().length > 0) {
                console.log(line);
            }
        }
        frame++;
    }, 150);
})(${width}, ${height});
`;
        return esotericScript;
    }
};

// --- Demonstration Setup ---
// Generating a simple 15x15 sample matrix representing a tree silhouette (1s)
const sampleSilhouette = [
    [0,0,0,0,0,0,0,1,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,1,1,1,0,0,0,0,0,0],
    [0,0,0,0,0,1,1,1,1,1,0,0,0,0,0],
    [0,0,0,0,1,1,1,1,1,1,1,0,0,0,0],
    [0,0,0,1,1,1,1,1,1,1,1,1,0,0,0],
    [0,0,1,1,1,1,1,1,1,1,1,1,1,0,0],
    [0,0,0,0,0,1,1,1,1,1,0,0,0,0,0],
    [0,0,0,0,0,0,1,1,1,0,0,0,0,0,0],
    [0,0,0,0,0,0,1,1,1,0,0,0,0,0,0],
    [0,0,0,0,0,0,1,1,1,0,0,0,0,0,0],
    [0,0,0,0,0,0,1,1,1,0,0,0,0,0,0],
    [0,0,0,0,0,0,1,1,1,0,0,0,0,0,0],
    [0,0,0,0,0,1,1,1,1,1,0,0,0,0,0],
    [0,0,0,1,1,1,1,1,1,1,1,1,0,0,0],
    [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1]
];

// Compile the image data into the poetry runtime script
const generatedEsotericScript = ImagePoetryCompressor.compress(sampleSilhouette);

// Execute the generated procedural script to animate the tree silhouette
eval(generatedEsotericScript);