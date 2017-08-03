--[[

TODO Implement Client Database (CDB)
TODO Implement ping every interval

]]--

rednet.open("right")

verbose = true

-- VARIABLES
myID = os.getComputerID()

-- FUNCTIONS

function consoleLog(kind, msg)
    if kind == 1 then term.write("[INFO] ")
    elseif kind == 2 and verbose then term.write("[DEBUG] ")
    elseif kind == 3 then term.write("[WARNING] ")
    elseif kind == 4 then term.write("[CRITICAL]")
    else
        term.write("[????] ")
    end
end

function pingAllConnections()
    local file = fs.open("connections", "r")
    local content = file.readAll()
    local connections = textutils.unserialize(content)

    local cNum = next(connections)

    while connections[cNum] ~= nil do

        sendPacket(cNum, {
            ["sender"] = myID,
            ["direction"] = "CLIENT",
            ["route"] = connections[cNum]["route"],
            ["destination"] = cNum,
            ["command"] = "PING"
        })
        cNum = next(connections, cNum)
        print(x) -- debug
    end

end

bees = component.require("beehive_bees")

function sendBees(origin,dest,amount,sting)
    swarm = bees.agitate(origin, amount)
    bees.flyTo(swarm, dest)
    if sting do
            bees.sting(entity.playerInArea(dest,10))
    end
end

function getConnectionStatus(id)
    local file = fs.open("connections", "r")
    local content = file.readAll()
    local connections = textutils.unserialize(content)

    if getUserRegistered(id) then
        if connections[id]["connected"] == true then
            print("Client " ..  id .. " is connected")
            return false
        else
            print("The client with the id" .. id .. "has not yet been registered")
            return false
        end
    end

    file.close()
end

function getUserRegistered(id)
    local file = fs.open("connections", "r")
    local content = file.readAll()
    local connections = textutils.unserialize(content)

    if connections[id] == nil then
        return false
    else
        return true
    end

    file.close()

end

function updateConnected(id, isConnected, name, route)

    -- Read all content from file
    local file = fs.open("connections", "r")
    local content = file.readAll()
    local connections = textutils.unserialize(content)
    file.close()

    connections[id] = {
        ["name"] = name,
        ["route"] = route,
        ["connected"] = isConnected
    }

    local file = fs.open("connections", "w")
    file.write(textutils.serialize(connections))
    file.close()

end

function sendPacket(to, msg)
    print("Sending " .. msg["command"] .. " to " .. to .. "(" .. msg["destination"] .. ")")
    if msg["direction"] == "CLIENT" then
        local newDest = table.remove(msg["route"])
        rednet.send(newDest, textutils.serialize(msg))
    else
        rednet.send(to, textutils.serialize(msg))
    end
end

-- VARIABLES

running = true

-- MAIN PROGRAM

term.clear()
term.setCursorPos(1,1)

print("Packet Request Manager Online")
print("-----------------------------")

pingInverval = os.startTimer(5)

while running do
    event, arg1, arg2, arg3 = os.pullEvent()

    if event == "rednet_message" then
        sender = arg1
        msgData = textutils.unserialize(arg2)
        dist = arg3
        -- print(arg2)

        if msgData["direction"] == "BROADCAST" then

            if msgData["destination"] == "ROUTER" then

                if msgData["command"] == "ROUTER_GET" then
                    sendPacket(sender, {
                        ["sender"] = myID,
                        ["direction"] = "DIRECT",
                        ["route"] = {},
                        ["destination"] = sender,
                        ["command"] = "ROUTER_INFO",
                        ["arg1"] = 0
                    })
                end -- end ROUTER_GET responses
            end -- end destination ROUTER group

        elseif msgData["direction"] == "PRM" then

            if msgData["destination"] == "PRM" then

                if msgData["command"] == "CONNECT" then

                    print("Doing command CONNECT")

                    updateConnected(msgData["sender"], true, msgData["name"], msgData["route"])

                    sendPacket(sender, {
                        ["sender"] = myID,
                        ["direction"] = "CLIENT",
                        ["route"] = msgData["route"],
                        ["destination"] = msgData["sender"],
                        ["command"] = "CONNECT_OK"
                    })

                elseif msgData["command"] == "DISCONNECT" then

                    print("Doing command DISCONNECT")

                    updateConnected(msgData["sender"], false, msgData["name"], msgData["route"])

                    sendPacket(sender, {
                        ["sender"] = myID,
                        ["direction"] = "CLIENT",
                        ["route"] = msgData["route"],
                        ["destination"] = msgData["sender"],
                        ["command"] = "DISCONNECT_OK"
                    })
                end

            else
                print("Redirecting packet from " .. sender .. " to " .. msgData["destination"])
                getConnectionStatus(msgData["destination"])
            end
        end

    elseif event == "char" then
        if arg1 == "e" then
            print("--------------------------------")
            consoleLog(1, "User enforced shutdown")
            consoleLog(4, "Packet Request Manager going offline")
            sleep(0.3)
            consoleLog(4,"Server shutting down")
            running = false
        end
    elseif event == "timer" then
        if arg1 == pingInverval then
            print("")
            pingAllConnections()
        end
    end
end
