--!strict
--!optimize 2
-- Optional legacy ModuleScript named MathX, placed beside AxiomX in ReplicatedStorage.
-- Requiring MathX resolves the exact same AxiomX module table without duplicating its state.
local AxiomX = require(script.Parent:WaitForChild("AxiomX"))
return AxiomX
