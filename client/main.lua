local QBCore = exports['qb-core']:GetCoreObject()
local blips = {}
local BankControlPress = false

-- Functions
local function createBlips()
    for k, v in pairs(Config.BankLocations) do
        blips[k] = AddBlipForCoord(v.x, v.y, v.z)

        SetBlipSprite(blips[k], Config.Blip.blipType)
        SetBlipDisplay(blips[k], 4)
        SetBlipScale(blips[k], Config.Blip.blipScale)
        SetBlipColour(blips[k], Config.Blip.blipColor)
        SetBlipAsShortRange(blips[k], true)

        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(tostring(Config.Blip.blipName))
        EndTextCommandSetBlipName(blips[k])
    end
end

local function removeBlips()
    for k, _ in pairs(Config.BankLocations) do
        RemoveBlip(blips[k])
    end

    blips = {}
end

local function openAccountScreen()
    QBCore.Functions.TriggerCallback('qb-banking:getBankingInformation', function(banking)
        if banking ~= nil then
            SetNuiFocus(true, true)
            SendNUIMessage({
                status = "openbank",
                information = banking
            })
        end
    end)
end

-- Events
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    createBlips()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    removeBlips()
end)

RegisterNetEvent('qb-banking:transferError', function(msg)
    SendNUIMessage({
        status = "transferError",
        error = msg
    })
end)

RegisterNetEvent('qb-banking:successAlert', function(msg)
    SendNUIMessage({
        status = "successMessage",
        message = msg
    })
end)

RegisterNetEvent('qb-banking:openBankScreen', function()
    openAccountScreen()
end)

local function BankControl()
    CreateThread(function()
        BankControlPress = true

        while BankControlPress do
            if IsControlPressed(0, 38) then
                TriggerEvent('qb-banking:openBankScreen')
            end

            Wait(0)
        end
    end)
end

CreateThread(function()
    if Config.UseTarget then
        for _, v in pairs(Config.Zones) do
            exports.ox_target:addBoxZone({
                coords = v.coords,
                size = v.size,
                rotation = v.rotation,
                options = {
                    {
                        name = 'qb-banking:bank',
                        event = "qb-banking:openBankScreen",
                        icon = "fas fa-university",
                        label = "Access Bank",
                        distance = 1.5
                    }
                }
            })
        end
    else
        local bankPoly = {}

        for _, v in pairs(Config.BankLocations) do
            bankPoly[#bankPoly + 1] = lib.zones.box({
                coords = v,
                size = vec3(1.5, 1.5, 1.5),
                rotation = -20,
                onEnter = function(_)
                    lib.showTextUI(Lang:t('info.access_bank_key'))

                    BankControl()
                end,
                onExit = function(_)
                    BankControlPress = false

                    lib.hideTextUI()
                end
            })
        end
    end
end)

-- NUI
RegisterNetEvent("hidemenu", function()
    SetNuiFocus(false, false)
    SendNUIMessage({
        status = "closebank"
    })
end)

RegisterNetEvent('qb-banking:client:newCardSuccess', function(cardno, ctype)
    SendNUIMessage({
        status = "updateCard",
        number = cardno,
        cardtype = ctype
    })
end)

-- NUI Callbacks
RegisterNUICallback("NUIFocusOff", function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({
        status = "closebank"
    })

    cb("ok")
end)

RegisterNUICallback("createSavingsAccount", function(_, cb)
    TriggerServerEvent('qb-banking:createSavingsAccount')

    cb("ok")
end)

RegisterNUICallback("doDeposit", function(data, cb)
    if tonumber(data.amount) ~= nil and tonumber(data.amount) > 0 then
        TriggerServerEvent('qb-banking:doQuickDeposit', data.amount)

        openAccountScreen()

        cb("ok")
    end

    cb(nil)
end)

RegisterNUICallback("doWithdraw", function(data, cb)
    if tonumber(data.amount) ~= nil and tonumber(data.amount) > 0 then
        TriggerServerEvent('qb-banking:doQuickWithdraw', data.amount, true)

        openAccountScreen()

        cb("ok")
    end

    cb(nil)
end)

RegisterNUICallback("doATMWithdraw", function(data, cb)
    if tonumber(data.amount) ~= nil and tonumber(data.amount) > 0 then
        TriggerServerEvent('qb-banking:doQuickWithdraw', data.amount, false)

        openAccountScreen()

        cb("ok")
    end

    cb(nil)
end)

RegisterNUICallback("savingsDeposit", function(data, cb)
    if tonumber(data.amount) ~= nil and tonumber(data.amount) > 0 then
        TriggerServerEvent('qb-banking:savingsDeposit', data.amount)

        openAccountScreen()

        cb("ok")
    end

    cb(nil)
end)

RegisterNUICallback("savingsWithdraw", function(data, cb)
    if tonumber(data.amount) ~= nil and tonumber(data.amount) > 0 then
        TriggerServerEvent('qb-banking:savingsWithdraw', data.amount)

        openAccountScreen()

        cb("ok")
    end

    cb(nil)
end)

RegisterNUICallback("doTransfer", function(data, cb)
    if data ~= nil then
        TriggerServerEvent('qb-banking:initiateTransfer', data)

        cb("ok")
    end

    cb(nil)
end)

RegisterNUICallback("createDebitCard", function(data, cb)
    if data.pin ~= nil then
        TriggerServerEvent('qb-banking:createBankCard', data.pin)

        cb("ok")
    end

    cb(nil)
end)

RegisterNUICallback("lockCard", function(_, cb)
    TriggerServerEvent('qb-banking:toggleCard', true)

    cb("ok")
end)

RegisterNUICallback("unLockCard", function(_, cb)
    TriggerServerEvent('qb-banking:toggleCard', false)

    cb("ok")
end)

RegisterNUICallback("updatePin", function(data, cb)
    if data.pin and data.currentBankCard then
        TriggerServerEvent('qb-banking:updatePin', data.currentBankCard, data.pin)

        cb("ok")
    end

    cb(nil)
end)