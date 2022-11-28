Config = Config or {}

Config.cardTypes = {"visa", "mastercard"}

Config.UseTarget = GetConvar('UseTarget', 'false') == 'true'

Config.Zones = {
    [1] = {
        coords = vec3(149.05, -1041.3, 29.37),
        size = vec3(2, 2, 2),
        rotation = 250
    },
    [2] = {
        coords = vec3(313.32, -280.03, 54.17),
        size = vec3(2, 2, 2),
        rotation = 250
    },
    [3] = {
        coords = vec3(-351.94, -50.72, 49.04),
        size = vec3(2, 2, 2),
        rotation = 71
    },
    [4] = {
        coords = vec3(-1212.68, -331.83, 37.78),
        size = vec3(2, 2, 2),
        rotation = 297
    },
    [5] = {
        coords = vec3(-2961.67, 482.31, 15.7),
        size = vec3(2, 2, 2),
        rotation = 358
    },
    [6] = {
        coords = vec3(1175.64, 2707.71, 38.09),
        size = vec3(2, 2, 2),
        rotation = 90
    },
    [7] = {
        coords = vec3(247.65, 223.87, 106.29),
        size = vec3(2, 2, 2),
        rotation = 250
    },
    [8] = {
        coords = vec3(-111.98, 6470.56, 31.63),
        size = vec3(2, 2, 2),
        rotation = 45
    }
}

Config.Blip = {
    blipName = Lang:t('info.bank_blip'),
    blipType = 108,
    blipColor = 2,
    blipScale = 0.55
}

Config.ATMModels = {
    "prop_atm_01",
    "prop_atm_02",
    "prop_atm_03",
    "prop_fleeca_atm"
}

Config.BankLocations = {
    vec3(149.9, -1040.46, 29.37),
    vec3(314.23, -278.83, 54.17),
    vec3(-350.8, -49.57, 49.04),
    vec3(-1213.0, -330.39, 37.79),
    vec3(-2962.71, 483.0, 15.7),
    vec3(1175.07, 2706.41, 38.09),
    vec3(246.64, 223.20, 106.29),
    vec3(-113.22, 6470.03, 31.63)
}