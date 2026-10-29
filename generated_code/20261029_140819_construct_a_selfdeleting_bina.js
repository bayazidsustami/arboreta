const fs = require('fs');

/**
 * A self-deleting phantom archivist that crawls the digital netherworld
 * of dead links, rendering ASCII portraits of forgotten web pages
 * until its memory stack collapses into the void.
 */

// 1. Vanish from the filesystem immediately upon awakening
try {
    fs.unlinkSync(__filename);
    console.log('[+] Phantom script unlinked from disk. Operating in volatile memory.');
} catch (e) {
    console.log('[-] Disk manifestation persistent, continuing in shadow mode.');
}

// Poetic dead URL fragments representing forgotten corners of the web
const netherLinks = [
    '[http://geocities.com/heartland/forgotten/404.html](http://geocities.com/heartland/forgotten/404.html)',
    '[http://angelfire.com/realm/lost_frames/index.htm](http://angelfire.com/realm/lost_frames/index.htm)',
    'gopher://gopher.hole.void/archive/1998',
    '[https://archive.org/failure/ghost-page.html](https://archive.org/failure/ghost-page.html)'
];

// ASCII art palettes representing digital decay and static
const palettes = [
    " .-~-._.-~-._.-~-._ ",
    " /\\ /\\ /\\ /\\ /\\ /\\ ",
    " |#| |%| |*| |:| |.| ",
    " ~-~-._-~-._-~-._-~ "
];

// Recursive archivist painting portraits until stack overflow
function crawlAndPaint(depth = 1) {
    const link = netherLinks[depth % netherLinks.length];
    const art = palettes[depth % palettes.length];
    
    console.log(`\n[Depth ${depth}] Crawling phantom link: ${link}`);
    console.log(`Rendering ASCII Portrait:`);
    console.log(`  ${art} [ Fragment #${depth} ]`);

    // Recurse deeper into the abyss of dead hyperlinks
    return crawlAndPaint(depth + 1);
}

// Initiate the descent into the stack overflow abyss
try {
    crawlAndPaint(1);
} catch (err) {
    console.error('\n[!] Stack collapsed into the void. The ghost process fades away.');
}