local Cards = {
	Rarities = {
		Common = { Name = "Common", Color = Color3.fromRGB(163, 162, 165), Chance = 50, Rank = 1, Vfx = { Rate = 5, Size = 1, Light = 0 } },
		Rare = { Name = "Rare", Color = Color3.fromRGB(0, 162, 255), Chance = 30, Rank = 2, Vfx = { Rate = 15, Size = 2, Light = 5 } },
		Epic = { Name = "Epic", Color = Color3.fromRGB(170, 0, 255), Chance = 15, Rank = 3, Vfx = { Rate = 30, Size = 3, Light = 10 } },
		Legendary = { Name = "Legendary", Color = Color3.fromRGB(255, 170, 0), Chance = 4.5, Rank = 4, Vfx = { Rate = 60, Size = 4, Light = 15, Shake = true } },
		Mythic = { Name = "Mythic", Color = Color3.fromRGB(255, 0, 0), Chance = 0.5, Rank = 5, Vfx = { Rate = 120, Size = 6, Light = 30, Shake = true, Flash = true } },
	},

	Items = {
		{ Name = "Midoriya",    Rarity = "Common",    Description = "The successor of One For All.",           Image = "rbxassetid://136042757299582" },
		{ Name = "Luffy",         Rarity = "Common",    Description = "Wants to be the Pirate King.",                  Image = "rbxassetid://0" },
		{ Name = "Naruto",        Rarity = "Common",    Description = "The host of the Nine-Tails.",                   Image = "rbxassetid://0" },

		{ Name = "Vegeta",        Rarity = "Rare",      Description = "Prince of all Saiyans.",                        Image = "rbxassetid://0" },
		{ Name = "Zoro",          Rarity = "Rare",      Description = "The three-sword style master.",                 Image = "rbxassetid://0" },

		{ Name = "Tanjiro",       Rarity = "Epic",      Description = "A demon slayer with a heart of gold.",          Image = "rbxassetid://0" },
		{ Name = "Killua",        Rarity = "Epic",      Description = "The lightning-fast assassin.",                  Image = "rbxassetid://0" },

		{ Name = "Saitama",       Rarity = "Legendary", Description = "One punch is all he needs.",                    Image = "rbxassetid://0" },
		{ Name = "Gojo",          Rarity = "Legendary", Description = "The strongest sorcerer.",                       Image = "rbxassetid://0" },

		{ Name = "Gear 5 Luffy",  Rarity = "Mythic",    Description = "The warrior of liberation.",                    Image = "rbxassetid://0" },
		{ Name = "Madara Uchiha", Rarity = "Mythic",    Description = "The legendary leader of the Uchiha clan.",      Image = "rbxassetid://0" },
		{ Name = "Naruto nine tails", Rarity = "Mythic",    Description = "The nine tails ultimate ninja.",      Image = "rbxassetid://82708853252930" }
	}
}

function Cards.GetItemsByRarity(rarityName)
	local result = {}
	for _, item in ipairs(Cards.Items) do
		if item.Rarity == rarityName then
			table.insert(result, item)
		end
	end
	return result
end

return Cards
