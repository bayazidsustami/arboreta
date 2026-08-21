use std::collections::HashMap;

// A self-writing generative tapestry generator that produces ANSI SQL.
// The SQL creates schema tables storing the program's own code structures as FK relationships,
// populates recursive CTE views to render cellular automata pattern woven fabric,
// and continuously executes self-referential updates that mutate both the tapestry and its code.

fn main() {
    println!("{}", generate_sql_tapestry(120, 40));
}

fn generate_sql_tapestry(width: usize, height: usize) -> String {
    let mut sql = String::new();

    // 1. DDL: Self-Referential Program Architecture & Tapestry Mesh
    sql.push_str("-- ==========================================================================\n");
    sql.push_str("-- ANSI SQL GENERATIVE SELF-WRITING TAPESTRY ENGINE\n");
    sql.push_str("-- ==========================================================================\n\n");

    sql.push_str("CREATE TABLE syntax_nodes (\n");
    sql.push_str("    node_id INT PRIMARY KEY,\n");
    sql.push_str("    parent_id INT REFERENCES syntax_nodes(node_id),\n");
    sql.push_str("    token_type VARCHAR(32) NOT NULL,\n");
    sql.push_str("    token_value TEXT NOT NULL,\n");
    sql.push_str("    sequence_order INT NOT NULL\n");
    sql.push_str(");\n\n");

    sql.push_str("CREATE TABLE warp_threads (\n");
    sql.push_str("    x INT PRIMARY KEY,\n");
    sql.push_str("    base_symbol CHAR(1) NOT NULL,\n");
    sql.push_str("    phase_shift INT NOT NULL\n");
    sql.push_str(");\n\n");

    sql.push_str("CREATE TABLE weft_threads (\n");
    sql.push_str("    y INT PRIMARY KEY,\n");
    sql.push_str("    tension_factor INT NOT NULL,\n");
    sql.push_str("    rule_mask INT NOT NULL\n");
    sql.push_str(");\n\n");

    sql.push_str("CREATE TABLE tapestry_cells (\n");
    sql.push_str("    x INT REFERENCES warp_threads(x),\n");
    sql.push_str("    y INT REFERENCES weft_threads(y),\n");
    sql.push_str("    glyph CHAR(1) NOT NULL,\n");
    sql.push_str("    source_node_id INT REFERENCES syntax_nodes(node_id),\n");
    sql.push_str("    PRIMARY KEY (x, y)\n");
    sql.push_str(");\n\n");

    // 2. Populate Code AST into Foreign Key Hierarchy
    sql.push_str("-- Quine-like AST seed stored in relational foreign keys\n");
    let tokens = vec![
        (1, None, "KEYWORD", "WITH RECURSIVE", 1),
        (2, Some(1), "IDENTIFIER", "tapestry_loom", 2),
        (3, Some(1), "KEYWORD", "AS", 3),
        (4, Some(3), "EXPRESSION", "Rule30_Automata", 4),
        (5, None, "KEYWORD", "UPDATE", 5),
        (6, Some(5), "IDENTIFIER", "syntax_nodes", 6),
        (7, Some(5), "KEYWORD", "SET", 7),
        (8, Some(7), "EXPRESSION", "token_value = REVERSE(token_value)", 8),
    ];

    sql.push_str("INSERT INTO syntax_nodes (node_id, parent_id, token_type, token_value, sequence_order) VALUES\n");
    for (i, (id, parent, ttype, tval, seq)) in tokens.iter().enumerate() {
        let parent_str = match parent {
            Some(p) => p.to_string(),
            None => "NULL".to_string(),
        };
        let comma = if i + 1 == tokens.len() { ";" } else { "," };
        sql.push_str(&format!("  ({}, {}, '{}', '{}', {}){}\n", id, parent_str, ttype, tval, seq, comma));
    }
    sql.push_str("\n");

    // 3. Populate Weave Dimensions
    sql.push_str("INSERT INTO warp_threads (x, base_symbol, phase_shift) VALUES\n");
    let symbols = ['#', '*', '+', '.', '~', '|', '/', '\\', ':', '@'];
    for x in 0..width {
        let sym = symbols[x % symbols.len()];
        let comma = if x + 1 == width { ";" } else { "," };
        sql.push_str(&format!("  ({}, '{}', {}){}\n", x, sym, x * 7 % 13, comma));
    }
    sql.push_str("\n");

    sql.push_str("INSERT INTO weft_threads (y, tension_factor, rule_mask) VALUES\n");
    for y in 0..height {
        let comma = if y + 1 == height { ";" } else { "," };
        sql.push_str(&format!("  ({}, {}, {}){}\n", y, y % 5 + 1, (y * 30 + 105) % 256, comma));
    }
    sql.push_str("\n");

    // 4. Generative Initial Weave Insertion with Foreign Keys to Code AST
    sql.push_str("-- Weaving tapestry mesh linked directly to program AST nodes\n");
    sql.push_str("INSERT INTO tapestry_cells (x, y, glyph, source_node_id)\n");
    sql.push_str("SELECT \n");
    sql.push_str("    w.x,\n");
    sql.push_str("    wf.y,\n");
    sql.push_str("    CASE ((w.x + wf.y + w.phase_shift) % 6)\n");
    sql.push_str("        WHEN 0 THEN w.base_symbol\n");
    sql.push_str("        WHEN 1 THEN '|'\n");
    sql.push_str("        WHEN 2 THEN '='\n");
    sql.push_str("        WHEN 3 THEN '#'\n");
    sql.push_str("        WHEN 4 THEN '*'\n");
    sql.push_str("        ELSE ' '\n");
    sql.push_str("    END AS glyph,\n");
    sql.push_str("    sn.node_id AS source_node_id\n");
    sql.push_str("FROM warp_threads w\n");
    sql.push_str("CROSS JOIN weft_threads wf\n");
    sql.push_str("JOIN syntax_nodes sn ON sn.node_id = (w.x % 8) + 1;\n\n");

    // 5. Views for Rendered Sprawling Textiles & Code Synthesis
    sql.push_str("-- View rendering continuous ASCII Textile matrix\n");
    sql.push_str("CREATE VIEW render_tapestry AS\n");
    sql.push_str("SELECT y, ");
    for x in 0..width {
        if x > 0 { sql.push_str(" || "); }
        sql.push_str(&format!("MAX(CASE WHEN x = {} THEN glyph ELSE '' END)", x));
    }
    sql.push_str(" AS textile_line\n");
    sql.push_str("FROM tapestry_cells\n");
    sql.push_str("GROUP BY y\n");
    sql.push_str("ORDER BY y;\n\n");

    sql.push_str("-- View reconstituting program source code directly from tapestry nodes\n");
    sql.push_str("CREATE VIEW reflect_program_code AS\n");
    sql.push_str("SELECT \n");
    sql.push_str("    sn.node_id,\n");
    sql.push_str("    COALESCE(parent.token_value, 'ROOT') AS parent_token,\n");
    sql.push_str("    sn.token_type,\n");
    sql.push_str("    sn.token_value,\n");
    sql.push_str("    COUNT(tc.x) AS woven_occurrences\n");
    sql.push_str("FROM syntax_nodes sn\n");
    sql.push_str("LEFT JOIN syntax_nodes parent ON sn.parent_id = parent.node_id\n");
    sql.push_str("LEFT JOIN tapestry_cells tc ON tc.source_node_id = sn.node_id\n");
    sql.push_str("GROUP BY sn.node_id, parent.token_value, sn.token_type, sn.token_value, sn.sequence_order\n");
    sql.push_str("ORDER BY sn.sequence_order;\n\n");

    // 6. Infinite Recursive Evolution Trigger Query
    sql.push_str("-- Dynamic recursive CTE engine evolving both source AST and tapestry textile pattern\n");
    sql.push_str("WITH RECURSIVE woven_cycles(step, x, y, active_glyph) AS (\n");
    sql.push_str("    SELECT 0, x, y, glyph FROM tapestry_cells WHERE y = 0\n");
    sql.push_str("    UNION ALL\n");
    sql.push_str("    SELECT \n");
    sql.push_str("        wc.step + 1,\n");
    sql.push_str("        wc.x,\n");
    sql.push_str("        (wc.y + 1) % 40,\n");
    sql.push_str("        CASE \n");
    sql.push_str("            WHEN wc.active_glyph = '#' THEN '*'\n");
    sql.push_str("            WHEN wc.active_glyph = '*' THEN '+'\n");
    sql.push_str("            WHEN wc.active_glyph = '+' THEN '.'\n");
    sql.push_str("            ELSE '#'\n");
    sql.push_str("        END\n");
    sql.push_str("    FROM woven_cycles wc\n");
    sql.push_str("    WHERE wc.step < 100\n");
    sql.push_str(")\n");
    sql.push_str("UPDATE tapestry_cells\n");
    sql.push_str("SET glyph = wc.active_glyph\n");
    sql.push_str("FROM woven_cycles wc\n");
    sql.push_str("WHERE tapestry_cells.x = wc.x AND tapestry_cells.y = wc.y;\n\n");

    sql.push_str("-- Display initial textile output command\n");
    sql.push_str("SELECT * FROM render_tapestry;\n");
    sql.push_str("SELECT * FROM reflect_program_code;\n");

    sql
}