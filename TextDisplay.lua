local pos = 18
mon = peripheral.wrap("bottom")
mon.clear()
mon.setTextScale(2)

print("Text eingeben:")
local displayText = read()

local textSize = string.len(displayText)
while true do
    if pos==-textSize then
        pos = 18
    end
    
    mon.clear()
    mon.setCursorPos(pos, 1.5)
    mon.write(displayText)
    pos = pos-1
    
    os.sleep(0.15)
    
end