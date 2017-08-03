--[[

TODO Implement Client Database (CDB)
TODO Implement ping every interval

]]--

rednet.open("right")

-- VARIABLES
myID = os.getComputerID()

-- FUNCTIONS

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
            print("Client " .. id .. " is not connected")
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
        print("Client " ..  id .. " is not registered")
        return false
    else
        print("Client " .. id .. " is registered")
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

    -- Debug info
    -- print(id)
    -- print(isConnected)
    -- print(textutils.serialize(connections))

    local file = fs.open("connections", "w")
    file.write(textutils.serialize(connections))
    file.close()

    -- print(textutils.serialize(connections[id]))

end

function sendPacket(to, msg)
    print("Sending " .. msg["command"] .. " to " .. to .. "(" .. msg["destination"] .. ")")
    -- print(textutils.serialize(msg))
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
            print("[INFO] User enforced shutdown...")
            sleep(0.3)
            print("[CRITICAL] Packet Request Manager Offline")
            running = false
        end
    elseif event == "timer" then
        if arg1 == pingInverval then
            print("")
            pingAllConnections()
        end
    end
end
