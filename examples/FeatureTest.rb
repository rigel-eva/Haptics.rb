load "../lib/buttplugrb.rb"
client=Buttplug::PsudoClient.new("wss://[::]:12345/buttplug","/Users/rigel/Documents/Programing/buttplugrb/testingLog.txt","")
client.addVirtualGenericVibrator
client.addVirtualGenericStroker
client.addVirtualGenericRotator
devices=client.listDevices
vibe=Buttplug::Device.new(client, devices[0])
stroke=Buttplug::Device.new(client, devices[1])
rotate=Buttplug::Device.new(client, devices[2])
if(vibe.methods.include? :vibrateAll)
    vibe.vibrateAll(0.2)
    vibe.vibrateAll(1.0)
    vibe.vibrateAll(0.9)
    vibe.vibrateAll(0.67)
    vibe.stopDevice()
end
if(stroke.methods.include? :strokeAll)
    stroke.strokeAll({"Duration"=>300, "Position"=>0.2})
    stroke.strokeAll({"Duration"=>1000, "Position"=>1.0})
    stroke.strokeAll({"Duration"=>1, "Position"=>0.1})
    stroke.strokeAll({"Duration"=>100000, "Position"=>0.3})
    stroke.stopDevice()
end
if(rotate.methods.include? :rotateAll)
    rotate.rotateAll({"Speed"=>0.5,"Clockwise"=>true})
    rotate.rotateAll({"Speed"=>1.0,"Clockwise"=>false})
    rotate.rotateAll({"Speed"=>0.9,"Clockwise"=>false})
    rotate.rotateAll({"Speed"=>0.6,"Clockwise"=>true})
    rotate.rotateAll({"Speed"=>0.7,"Clockwise"=>true})
    rotate.stopDevice()
end
client.stopAllDevices