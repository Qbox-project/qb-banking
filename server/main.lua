local QBCore = exports['qb-core']:GetCoreObject()

CreateThread(function()
    local accts = MySQL.query.await('SELECT * FROM bank_accounts WHERE account_type = ?', {
        'Business'
    })

    if accts[1] then
        for _, v in pairs(accts) do
            local acctType = v.business

            if not businessAccounts[acctType] then
                businessAccounts[acctType] = {}
            end

            businessAccounts[acctType][tonumber(v.businessid)] = GeneratebusinessAccount(tonumber(v.account_number), tonumber(v.sort_code), tonumber(v.businessid))

            while not businessAccounts[acctType][tonumber(v.businessid)] do
                Wait(0)
            end
        end
    end

    local savings = MySQL.query.await('SELECT * FROM bank_accounts WHERE account_type = ?', {
        'Savings'
    })

    if savings then
        for _, v in pairs(savings) do
            savingsAccounts[v.citizenid] = generateSavings(v.citizenid)
        end
    end

    local gangs = MySQL.query.await('SELECT * FROM bank_accounts WHERE account_type = ?', {
        'Gang'
    })

    if gangs then
        for _, v in pairs(gangs) do
            gangAccounts[v.gangid] = loadGangAccount(v.gangid)
        end
    end
end)

exports('business', function(acctType, bid)
    if businessAccounts[acctType] then
        if businessAccounts[acctType][tonumber(bid)] then
            return businessAccounts[acctType][tonumber(bid)]
        end
    end
end)

exports('registerAccount', function(cid)
    local _cid = tonumber(cid)

    currentAccounts[_cid] = generateCurrent(_cid)
end)

exports('current', function(cid)
    if currentAccounts[cid] then
        return currentAccounts[cid]
    end
end)

exports('debitcard', function(cardnumber)
    if bankCards[tonumber(cardnumber)] then
        return bankCards[tonumber(cardnumber)]
    else
        return false
    end
end)

exports('savings', function(cid)
    if savingsAccounts[cid] then
        return savingsAccounts[cid]
    end
end)

exports('gang', function(gid)
    if gangAccounts[gid] then
        return gangAccounts[gid]
    end
end)

local function format_int(number)
    local _, _, minus, int, fraction = tostring(number):find('([-]?)(%d+)([.]?%d*)')

    int = int:reverse():gsub("(%d%d%d)", "%1,")

    return minus .. int:reverse():gsub("^,", "") .. fraction
end

-- Get all bank statements for the current player
local function getBankStatements(cid)
    local bankStatements = MySQL.query.await('SELECT * FROM bank_statements WHERE citizenid = ? ORDER BY record_id DESC LIMIT 30', {
        cid
    })

    return bankStatements
end

-- Adds a bank statement to the database
local function addBankStatement(cid, accountType, amountDeposited, amountWithdrawn, accountBalance, statementDescription)
    local time = os.date("%Y-%m-%d %H:%M:%S")

    MySQL.insert('INSERT INTO `bank_statements` (`account`, `citizenid`, `deposited`, `withdraw`, `balance`, `date`, `type`) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        accountType,
        cid,
        amountDeposited,
        amountWithdrawn,
        accountBalance,
        time,
        statementDescription
    })
end

-- Get all bank cards for the current player
local function getBankCard(cid)
    local bankCard = MySQL.query.await('SELECT * FROM bank_cards WHERE citizenid = ? ORDER BY record_id DESC LIMIT 1', {
        cid
    })

    return bankCard[1]
end

-- Adds a new bank card to the database, replaces existing card if it exists
local function addNewBankCard(citizenid, cardNumber, cardPin, cardActive, cardLocked, cardType)
    -- The use of REPLACE will act just like INSERT if there are no results that match on the citizenid key
    -- If there are existing results, it will replace the item with the new data
    MySQL.insert('REPLACE INTO bank_cards (`citizenid`, `cardNumber`, `cardPin`, `cardActive`, `cardLocked`, `cardType`) VALUES (?, ?, ?, ?, ?, ?)', {
        citizenid,
        cardNumber,
        cardPin,
        cardActive,
        cardLocked,
        cardType
    })
end

-- Toggle the lock status of a bank card
local function toggleBankCardLock(cid, lockStatus)
    MySQL.update('UPDATE bank_cards SET cardLocked = ? WHERE citizenid = ?', { lockStatus, cid})
end

QBCore.Functions.CreateCallback('qb-banking:getBankingInformation', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)

    if not Player then
        return cb(nil)
    end

    local bankStatements = getBankStatements(Player.PlayerData.citizenid)
    local bankCard = getBankCard(Player.PlayerData.citizenid)
    local banking = {
        ['name'] = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
        ['bankbalance'] = '$'.. format_int(Player.PlayerData.money['bank']),
        ['cash'] = '$'.. format_int(Player.PlayerData.money['cash']),
        ['accountinfo'] = Player.PlayerData.charinfo.account,
        ['cardInformation'] = bankCard,
        ['statement'] = bankStatements,
    }

    if savingsAccounts[Player.PlayerData.citizenid] then
        local cid = Player.PlayerData.citizenid

        banking['savings'] = {
            ['amount'] = savingsAccounts[cid].GetBalance(),
            ['details'] = savingsAccounts[cid].getAccount(),
            ['statement'] = savingsAccounts[cid].getStatement()
        }
    end

    cb(banking)
end)

-- Creates a new bank card.
-- If the player already has a card it will replace the existing card with the new one
RegisterNetEvent('qb-banking:createBankCard', function(pin)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local cid = Player.PlayerData.citizenid
    local cardNumber = math.random(1000000000000000, 9999999999999999)

    Player.Functions.SetCreditCard(cardNumber)

    local info = {}
    local selectedCard = Config.cardTypes[math.random(1, #Config.cardTypes)]

    info.citizenid = cid
    info.name = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    info.cardNumber = cardNumber
    info.cardPin = tonumber(pin)
    info.cardActive = true
    info.cardType = selectedCard

    if selectedCard == "visa" then
        Player.Functions.AddItem('visa', 1, nil, info)
    elseif selectedCard == "mastercard" then
        Player.Functions.AddItem('mastercard', 1, nil, info)
    end

    addNewBankCard(cid, cardNumber, info.cardPin, info.cardActive, 0, info.cardType)

    TriggerClientEvent('qb-banking:openBankScreen', src)
    TriggerClientEvent('qb-banking:successAlert', src, Lang:t('success.debit_card'))
    TriggerEvent('qb-log:server:CreateLog', 'banking', 'Banking', 'lightgreen', "**" .. GetPlayerName(Player.PlayerData.source) .. " (citizenid: " .. Player.PlayerData.citizenid .. " | id: " .. Player.PlayerData.source .. ")** successfully ordered a debit card")
end)

RegisterNetEvent('qb-banking:doQuickDeposit', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    local currentCash = Player.Functions.GetMoney('cash')

    if tonumber(amount) <= currentCash then
        Player.Functions.RemoveMoney('cash', tonumber(amount), 'banking-quick-depo')

        local bank = Player.Functions.AddMoney('bank', tonumber(amount), 'banking-quick-depo')
        local newBankBalance = Player.Functions.GetMoney('bank')

        addBankStatement(Player.PlayerData.citizenid, 'Bank', amount, 0, newBankBalance, Lang:t('info.deposit', {
            amount = amount
        }))

        if bank then
            TriggerClientEvent('qb-banking:openBankScreen', src)
            TriggerClientEvent('qb-banking:successAlert', src, Lang:t('success.cash_deposit', {
                value = amount
            }))
            TriggerEvent('qb-log:server:CreateLog', 'banking', 'Banking', 'lightgreen', "**" .. GetPlayerName(Player.PlayerData.source) .. " (citizenid: " .. Player.PlayerData.citizenid .. " | id: " .. Player.PlayerData.source .. ")** made a cash deposit of $" .. amount .. " successfully.")
        end
    end
end)

RegisterNetEvent('qb-banking:toggleCard', function(toggle)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    toggleBankCardLock(Player.PlayerData.citizenid, toggle)
end)

RegisterNetEvent('qb-banking:doQuickWithdraw', function(amount, _)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    local currentCash = Player.Functions.GetMoney('bank')
    local newBankBalance = Player.Functions.GetMoney('bank')

    addBankStatement(Player.PlayerData.citizenid, 'Bank', 0, amount, newBankBalance, Lang:t('info.withdraw', {
        amount = amount
    }))

    if tonumber(amount) <= currentCash then
        local cash = Player.Functions.RemoveMoney('bank', tonumber(amount), 'banking-quick-withdraw')

        bank = Player.Functions.AddMoney('cash', tonumber(amount), 'banking-quick-withdraw')

        if cash then
            TriggerClientEvent('qb-banking:openBankScreen', src)
            TriggerClientEvent('qb-banking:successAlert', src, Lang:t('success.cash_withdrawal', {
                value = amount
            }))
            TriggerEvent('qb-log:server:CreateLog', 'banking', 'Banking', 'red', "**" .. GetPlayerName(Player.PlayerData.source) .. " (citizenid: " .. Player.PlayerData.citizenid .. " | id: " .. Player.PlayerData.source .. ")** made a cash withdrawal of $" .. amount .. " successfully.")
        end
    end
end)

RegisterNetEvent('qb-banking:updatePin', function(currentBankCard, newPin)
    if newPin then
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)

        if not Player then
            return
        end

        MySQL.update('UPDATE bank_cards SET cardPin = ? WHERE record_id = ?', {
            newPin,
            currentBankCard.record_id
        }, function(result)
            if result == 1 then
                TriggerClientEvent('qb-banking:openBankScreen', src)
                TriggerClientEvent('qb-banking:successAlert', src, Lang:t('success.updated_pin'))
            else
                TriggerClientEvent('QBCore:Notify', src, 'Error updating pin', "error")
            end
        end)
    end
end)

RegisterNetEvent('qb-banking:savingsDeposit', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    local currentBank = Player.Functions.GetMoney('bank')

    if tonumber(amount) <= currentBank then
        local bank = Player.Functions.RemoveMoney('bank', tonumber(amount))
        local savings = savingsAccounts[Player.PlayerData.citizenid].AddMoney(tonumber(amount), Lang:t('info.current_to_savings'))

        if not bank then
            return
        end

        if not savings then
            return
        end

        TriggerClientEvent('qb-banking:openBankScreen', src)
        TriggerClientEvent('qb-banking:successAlert', src, Lang:t('success.savings_deposit', {
            value = tostring(amount)
        }))
        TriggerEvent('qb-log:server:CreateLog', 'banking', 'Banking', 'lightgreen', "**" .. GetPlayerName(Player.PlayerData.source) .. " (citizenid: " .. Player.PlayerData.citizenid .. " | id: " .. Player.PlayerData.source .. ")** made a savings deposit of $" .. tostring(amount) .. " successfully.")
    end
end)

RegisterNetEvent('qb-banking:savingsWithdraw', function(amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)

    if not Player then
        return
    end

    local currentSavings = savingsAccounts[Player.PlayerData.citizenid].GetBalance()

    if tonumber(amount) <= currentSavings then
        local savings = savingsAccounts[Player.PlayerData.citizenid].RemoveMoney(tonumber(amount), Lang:t('info.savings_to_current'))
        local bank = Player.Functions.AddMoney('bank', tonumber(amount), 'banking-quick-withdraw')

        if not bank then
            return
        end

        if not savings then
            return
        end

        TriggerClientEvent('qb-banking:openBankScreen', src)
        TriggerClientEvent('qb-banking:successAlert', src, Lang:t('success.savings_withdrawal', {
            value = tostring(amount)
        }))
        TriggerEvent('qb-log:server:CreateLog', 'banking', 'Banking', 'red', "**" .. GetPlayerName(Player.PlayerData.source) .. " (citizenid: " .. Player.PlayerData.citizenid .. " | id: " .. Player.PlayerData.source .. ")** made a savings withdrawal of $" .. tostring(amount) .. " successfully.")
    end
end)

RegisterNetEvent('qb-banking:createSavingsAccount', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local success = createSavingsAccount(Player.PlayerData.citizenid)

    repeat
        Wait(0)
    until success

    TriggerClientEvent('qb-banking:openBankScreen', src)
    TriggerClientEvent('qb-banking:successAlert', src, Lang:t('success.opened_savings'))
    TriggerEvent('qb-log:server:CreateLog', 'banking', 'Banking', "lightgreen", "**" .. GetPlayerName(Player.PlayerData.source) .. " (citizenid: " .. Player.PlayerData.citizenid .. " | id: " .. Player.PlayerData.source .. ")** opened a savings account")
end)

QBCore.Commands.Add('givecash', Lang:t('command.givecash'), {
    {name = 'id', help = 'Player ID'},
    {name = 'amount', help = 'Amount'}
}, true, function(source, args)
	local id = tonumber(args[1])
	local amount = math.ceil(tonumber(args[2]))

	if id and amount then
		local Player = QBCore.Functions.GetPlayer(source)
		local Target = QBCore.Functions.GetPlayer(id)

		if Target and Player then
			if not Player.PlayerData.metadata.isdead then
				local distance = Player.PlayerData.metadata.inlaststand and 3.0 or 10.0

				if #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(GetPlayerPed(id))) < distance then
                    if amount > 0 then
                        if Player.Functions.RemoveMoney('cash', amount) then
                            if Target.Functions.AddMoney('cash', amount) then
                                TriggerClientEvent('QBCore:Notify', source, Lang:t('success.give_cash', {
                                    id = tostring(id),
                                    cash = tostring(amount)
                                }), "success")
                                TriggerClientEvent('QBCore:Notify', id, Lang:t('success.received_cash', {
                                    id = tostring(source),
                                    cash = tostring(amount)
                                }), "success")
                                TriggerClientEvent("payanimation", source)
                            else
                                -- Return player cash
                                Player.Functions.AddMoney('cash', amount)

                                TriggerClientEvent('QBCore:Notify', source, Lang:t('error.not_give'), "error")
                            end
                        else
                            TriggerClientEvent('QBCore:Notify', source, Lang:t('error.not_enough'), "error")
                        end
                    else
                        TriggerClientEvent('QBCore:Notify', source, Lang:t('error.invalid_amount'), "error")
                    end
				else
					TriggerClientEvent('QBCore:Notify', source, Lang:t('error.too_far_away'), "error")
				end
			else
				TriggerClientEvent('QBCore:Notify', source, Lang:t('error.dead'), "error")
			end
		else
			TriggerClientEvent('QBCore:Notify', source, Lang:t('error.wrong_id'), "error")
		end
	else
		TriggerClientEvent('QBCore:Notify', source, Lang:t('error.givecash'), "error")
	end
end)

RegisterNetEvent("payanimation", function()
    TriggerEvent('animations:client:EmoteCommandStart', {"id"})
end)