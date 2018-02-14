require "buttplugrb"
LOCATION="wss://localhost:12345/buttplug"           #where our server is located, more than likely going to be on localhost:12345/buttplug
client=Buttplug::Client.new(LOCATION)               #initalizing our client 
sleep 0.1                                           #Giving our client a moment to wake up
client.startScanning();                             #Telling the server to start scanning for new devices, ble or otherwise
sleep 1                                             #Giving it a moment to find our device
devices=client.listDevices()                        #Grabing our device list
client.stopScanning()                               #No sense in tying up the server ... not just yet~
controller=Buttplug::Device.new(client,devices[0])  #and generating a new device from the first client on the list
#ok we are gonna make a few assumptions here ... primarily that you are using an xbox controller
if(controller.methods.include? :vibrateAll)         #Ok due to metaprogramming bs we have to check to see if the device in question supports vibration
  (0..20).each{|i|                          #So we are going to do a shortish random curve
    controller.vibrateAll(rand(0.0..1.0))   #Set our vibration somewhere in the range of valid numbers
    sleep(rand(0.5..2))                     #and sleep for a random period of time
  }
  controller.vibrateAll(0.0)                #and shutting off the lights~
end