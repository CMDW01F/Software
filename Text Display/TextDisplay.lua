print("Bitte geben Sie die Monitor-ID ein [monitor_#]:")
local ID = read()

mon = peripheral.wrap(ID)
mon.clear()
mon.setTextScale(2)

print("Geben Sie den Text ein, den Sie anzeigen möchten:")
local Text = read()

local textSize = string.len(Text)

while true do
    if pos==-textSize then
        pos = 18
    end
    
    mon.clear()
    mon.setCursorPos(pos, 1.5)
    mon.write(Text)
    pos = pos-1
    
    os.sleep(0.15)
end