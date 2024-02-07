local pos = 18
mon = peripheral.wrap("bottom")
mon.clear()
mon.setTextScale(2)

print("Geben Sie den Text ein, der Angezeigt werden soll:")
local displayText = read()

local textSize = string.len(displayText) -- Holen Sie sich die Länge des Textes

while true do
    if pos==-textSize then -- Passen Sie die pos-Variable entsprechend der Textgröße an
        pos = 18
    end
    
    mon.clear()
    mon.setCursorPos(pos, 1.5)
    mon.write(displayText) -- Zeigen Sie den vom Benutzer eingegebenen Text an
    pos = pos-1
    
    os.sleep(0.15)
    
end