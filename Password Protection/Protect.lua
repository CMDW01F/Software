while true do
    write("Password> ")
    local pwd = read("*")
    if pwd == "let me in" then break end
    print("Incorrect password, try again.")
  end
  setAnalogOutput("back", 15)
  sleep(10.0)