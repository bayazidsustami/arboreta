local SlimeDatabase = {}
SlimeDatabase.__index = SlimeDatabase

function SlimeDatabase.new()
    local self = setmetatable({}, SlimeDatabase)
    self.tables = {}
    return self
end

function SlimeDatabase:createTable(name, schema)
    self.tables[name] = {
        name = name,
        schema = schema,
        rows = {},
        nodes = {}
    }
end

function SlimeDatabase:insert(tableName, row)
    local tbl = self.tables[tableName]
    if not tbl then error("Table non-existent: " .. tostring(tableName)) end
    
    local rowId = #tbl.rows + 1
    tbl.rows[rowId] = row
    
    -- Create a data node in the network representing this row
    local node = {
        id = tableName .. "_" .. rowId,
        tableName = tableName,
        rowId = rowId,
        data = row,
        edges = {}
    }
    
    -- Connect to existing nodes based on matching attribute values (attractant pathways)
    for tName, otherTbl in pairs(self.tables) do
        for _, otherNode in ipairs(otherTbl.nodes) do
            for k, v in pairs(row) do
                if otherNode.data[k] == v then
                    -- Biological attraction link established
                    local edge = { target = otherNode, flux = 0.5, conductivity = 1.0, length = 1.0 }
                    local backEdge = { target = node, flux = 0.5, conductivity = 1.0, length = 1.0 }
                    table.insert(node.edges, edge)
                    table.insert(otherNode.edges, backEdge)
                end
            end
        end
    end
    
    table.insert(tbl.nodes, node)
end

-- Simulates Physarum polycephalum tube adaptation to optimize query join pathways
function SlimeDatabase:queryJoin(tableA, tableB, joinKey, filterClause, iterations)
    iterations = iterations or 20
    local tblA = self.tables[tableA]
    local tblB = self.tables[tableB]
    
    -- Identify source nodes matching initial filter (food sources)
    local sources = {}
    for _, node in ipairs(tblA.nodes) do
        if not filterClause or filterClause(node.data) then
            table.insert(sources, node)
        end
    end

    -- Physarum growth cycle: reinforcment of high-flow pathways, decay of unused ones
    for iter = 1, iterations do
        -- Simulate nutrient flow from sources across matching edges
        for _, source in ipairs(sources) do
            for _, edge in ipairs(source.edges) do
                if edge.target.tableName == tableB and source.data[joinKey] == edge.target.data[joinKey] then
                    -- Calculate flux proportional to conductivity over length (Poiseuille-like flow)
                    local flux = edge.conductivity / edge.length
                    edge.flux = edge.flux + flux
                    
                    -- Tube adaptation: Conductivity grows with flux (biological reinforcement)
                    edge.conductivity = edge.conductivity + (edge.flux - edge.conductivity) * 0.2
                else
                    -- Decay unused pathways (pruning)
                    edge.conductivity = edge.conductivity * 0.95
                end
            end
        end
    end

    -- Harvest results from reinforced high-conductivity pathways
    local results = {}
    for _, source in ipairs(sources) do
        for _, edge in ipairs(source.edges) do
            if edge.target.tableName == tableB and edge.conductivity > 0.8 then
                table.insert(results, {
                    [tableA] = source.data,
                    [tableB] = edge.target.data,
                    pathwayStrength = edge.conductivity
                })
            end
        end
    end

    return results
end

-- Example Usage
local db = SlimeDatabase.new()

db:createTable("users", {"id", "name", "dept_id"})
db:createTable("departments", {"dept_id", "dept_name"})

db:insert("departments", {dept_id = 101, dept_name = "Engineering"})
db:insert("departments", {dept_id = 102, dept_name = "Research"})

db:insert("users", {id = 1, name = "Alice", dept_id = 101})
db:insert("users", {id = 2, name = "Bob", dept_id = 102})
db:insert("users", {id = 3, name = "Charlie", dept_id = 101})

-- Execute slime-mold join query finding engineering users
local joinResults = db:queryJoin("users", "departments", "dept_id", function(row)
    return row.dept_id == 101
end)

print("--- Slime Mold Foraged Join Results ---")
for _, res in ipairs(joinResults) do
    print(string.format("User: %s | Dept: %s | Tube Strength: %.2f",
        res.users.name, res.departments.dept_name, res.pathwayStrength))
end