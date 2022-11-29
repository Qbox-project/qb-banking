function loadGangAccount(gangid)
    local self = {}

    self.gid = gangid

    local query = MySQL.single.await("SELECT * FROM `bank_accounts` WHERE `gangid` = ? AND `account_type` = 'Gang'", {
        self.gid
    })

    if query then
        self.accountnumber = query.account_number
        self.sortcode = query.sort_code
        self.balance = query.amount
        self.account_type = query.account_type
        self.accountid = query.record_id
    end

    local state = MySQL.query.await('SELECT * FROM `bank_statements` WHERE `account_number` = ? AND `sort_code` = ? AND `gangid` = ?', {
        self.accountnumber,
        self.sortcode,
        self.gid
    })

    self.accountStatement = state

    self.saveAccount = function()
        MySQL.update('UPDATE `bank_accounts` SET `amount` = ? WHERE `record_id` = ?', {
            self.balance,
            self.accountid
        })
    end

    local rTable = {}

    rTable.getBalance = function()
        return self.balance
    end

    rTable.getStatement = function()
        return self.accountStatement
    end

    rTable.getAccountDetails = function()
        return {
            ['number'] = self.accountnumber,
            ['sortcode'] = self.sortcode
        }
    end

    --- Update Functions
    rTable.addMoney = function(m)
        if type(m) == "number" then
            self.balance = self.balance + m
            self.saveAccount()
        end
    end

    rTable.removeMoney = function(m)
        if type(m) == "number" then
            if self.balance >= m then
                self.balance = self.balance - m
                self.saveAccount()
                return true
            else
                return false
            end
        end
    end

    return rTable
end

local function createGangAccount(gang, startingBalance)
    local newBalance = tonumber(startingBalance) or 0
    local checkExists = MySQL.single.await('SELECT * FROM `bank_accounts` WHERE `gangid` = ?', {
        gang
    })

    if not checkExists then
        local sc = math.random(100000, 999999)
        local acct = math.random(10000000, 99999999)

        MySQL.insert('INSERT INTO `bank_accounts` (`gangid`, `account_number`, `sort_code`, `amount`, `account_type`) VALUES (?, ?, ?, ?, ?)', {
            gang,
            acct,
            sc,
            newBalance,
            'Gang'
        }, function(success)
            if success > 0 then
                gangAccounts[gang] = loadGangAccount(gang)
            end
        end)
    end
end

exports('createGangAccount', function(gang, starting)
    createGangAccount(gang, starting)
end)