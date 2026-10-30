--!strict
-- 로컬 표시만 검사한다. 실제 키 UI와 복제는 Studio에서 재확인한다.
local fs, luau = require("@lune/fs"), require("@lune/luau")
local function signal()
	local handlers={}
	return {Connect=function(_,fn)local k={};handlers[k]=fn;return{Disconnect=function()handlers[k]=nil end}end,
		Fire=function(_,...)for _,fn in handlers do fn(...)end end,
		Count=function()local n=0;for _ in handlers do n+=1 end;return n end}
end
local function character()
	local c={DescendantAdded=signal(),children={}}
	c.GetDescendants=function()return c.children end
	return c
end
local function prompt(owner,name,enabled)
	return {Parent={Name=name,IsA=function(_,class)return class=="Attachment"end},Enabled=enabled,
		IsA=function(_,class)return class=="ProximityPrompt"end,IsDescendantOf=function(_,c)return c==owner end}
end
local first,other=character(),character()
local own=prompt(first,"MidnightRescue",true)
local teammate=prompt(other,"MidnightRescue",true)
local unrelated=prompt(first,"OtherAction",true)
local disabled=prompt(first,"MidnightRescue",false)
first.children={own,unrelated,disabled}
local player={Character=first,CharacterAdded=signal(),CharacterRemoving=signal()}
local controller=luau.load(fs.readFile("src/client/Controllers/RescueController.luau"),{environment={
	game={GetService=function(_,name)assert(name=="Players");return{LocalPlayer=player}end}
}})()
local stop=controller.start()
assert(not own.Enabled and teammate.Enabled and unrelated.Enabled and not disabled.Enabled)
local secondDown=prompt(first,"MidnightRescue",true)
first.DescendantAdded:Fire(secondDown);assert(not secondDown.Enabled,"repeated down must hide its new self prompt")
first.DescendantAdded:Fire(teammate);assert(teammate.Enabled,"never disable another player's rescue")
player.CharacterRemoving:Fire(first)
assert(first.DescendantAdded:Count()==0 and own.Enabled and secondDown.Enabled and not disabled.Enabled)
local respawn=character();player.Character=respawn;player.CharacterAdded:Fire(respawn)
local afterRespawn=prompt(respawn,"MidnightRescue",true)
respawn.DescendantAdded:Fire(afterRespawn);assert(not afterRespawn.Enabled)
stop()
assert(afterRespawn.Enabled and teammate.Enabled and respawn.DescendantAdded:Count()==0)
assert(player.CharacterAdded:Count()==0 and player.CharacterRemoving:Count()==0)
print("PASS self rescue hidden, teammate/unrelated prompts preserved, repeated down/respawn and cleanup (client mocks; not Studio)")
