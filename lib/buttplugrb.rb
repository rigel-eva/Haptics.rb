require 'faye/websocket'
require 'eventmachine'
require 'json'
=begin rdoc
Our Module for containg the functions and classes relating to the Buttplugrb gem
=end
module Buttplug
=begin rdoc
Our Client for a buttplug.io server
=end
  class Client
=begin rdoc
Creates a new client for buttplug.io

Arguments:
* serverLocation (string) - Where our buttplug.io server is hosted. this will tend to be: <code>"wss://localhost:12345/buttplug"</code>

Returns:
* A shiney new buttplug client ready for some action
=end
    def initialize(serverLocation)
      @location=serverLocation
      #Ok Explanation time!
      # * @EventQueue - The events we are triggering on the server, Expected to be an array, with the first element being the message Id, and the second being the message itself!
      # * @responseQueue - And our messages back from the server! Will be an array with the 
      @eventQueue=EM::Queue.new
      @eventMachine=Thread.new{EM.run{
        eventQueue=@eventQueue 
        messageWatch={}
        tickLoop=EM.tick_loop do #Should improve response times~
          eventQueue.pop{|msg|
            ws.send msg[1]
            messageWatch[msg[0]]=msg
            p [Time.now, :message_send, msg[1]] 
          }
        end
        ws = Faye::WebSocket::Client.new(@location)
        ws.on :open do |event|
          p [Time.now, :open]
          ws.send '[{"RequestServerInfo": {"Id": 1, "ClientName": "roboMegumin", "MessageVersion": 1}}]'
        end
        ws.on :message do |event|
          message=JSON::parse(event.data)[0]
          message.each{|key,value|
            #We don't really care about the key just yet ... We are going to just care about finding our ID
            if(messageWatch.keys.include?(value["Id"]))
              messageWatch[value["Id"]]<<{key => value}#And now we care about our key!
              puts messageWatch[value["Id"]].object_id
              messageWatch.delete(value["Id"])
              p [Time.now, :message_recieved, [{key => value}]]
              next
            elsif(key=="ServerInfo")
              p [Time.now, :server_info, value]
            end
          }
        end
        ws.on :close do |event|
          p [Time.now, :close, event.code, event.reason]
          ws = nil
        end
        EM.add_periodic_timer(0.5){
          ws.send "[{\"Ping\": {\"Id\": #{generateID()}}}]"
        }
      }}
      @eventMachine.run
    end
=begin rdoc
Tells our server to start scanning for new devices
=end
    def startScanning()
      id=generateID()
      @eventQueue.push([id,"[{\"StartScanning\":{\"Id\":#{id}}}]"])
    end
=begin rdoc
Tells our server to stop scanning for new devices
=end
    def stopScanning()
      id=generateID()
      @eventQueue.push([id,"[{\"StopScanning\":{\"Id\":#{id}}}]"])
    end
=begin rdoc
Lists all devices available to the server

Returns:
* An array of available devices from the server

Example:
    client.listDevices()
       [{"DeviceName"=>"XBox Compatible Gamepad (XInput)", "DeviceIndex"=>1, "DeviceMessages"=>{"SingleMotorVibrateCmd"=>{}, "VibrateCmd"=>{"FeatureCount"=>2}, "StopDeviceCmd"=>{}}}]
=end  
    def listDevices()
      id=generateID()
      deviceRequest=[id,"[{\"RequestDeviceList\": {\"Id\":#{id}}}]"]
      @eventQueue.push(deviceRequest)
      while(deviceRequest.length<3) do
        sleep 0.01#Just so we arn't occupying all the time on the system while we are waiting for our device list to come back.
      end
      return deviceRequest[2]["DeviceList"]["Devices"]
    end
=begin rdoc
Stops all devices currently controlled by the server
=end
    def stopAllDevices()
      id=generateID()
      deviceRequest=[id,"[{\"StopAllDevices\": {\"ID\":#{id}}}]"]
      @eventQueue.push(deviceRequest)
    end
=begin rdoc
Sends a message to our buttplug server

Arguments:
* message (JSON formatted string) - The message we are sending to our server

Returns:
* the Response from our server 
=end
    def sendMessage(message)
      @eventQueue.push(message)
      while(message.length<3) do
        sleep 0.01
      end
      return message[3]
    end
=begin rdoc
Does exactly what it says on the tin, generates a random id for our messages

Returns:
* a number between 2 and 4294967295
=end
    def generateID()
      return rand(2..4294967295)
    end
  end
=begin rdoc
This class creates a Wrapper for your various devices you fetched from listDevices for your controlling pleasure!
=end
  class Device
=begin rdoc
Creates our Device wrapper for our client

Note: This does create a few functions on the fly. you should check to see if they are available using  .methods.include

Arguments:
* client (Buttplug::Client) - Our buttplugrb client that we are gonna use to control our device
* deviceInfo (Hash) - Our information that we should have fetched from the list_devices() instance method ... should look like:
     {"DeviceName"=>"XBox Compatible Gamepad (XInput)", "DeviceIndex"=>1, "DeviceMessages"=>{"SingleMotorVibrateCmd"=>{}, "VibrateCmd"=>{"FeatureCount"=>2}, "StopDeviceCmd"=>{}}}

Returns:
* Our nicely bundled up device ready to be domminated~
=end
    def initialize(client, deviceInfo)
      #Ok we are gonna expect our deviceInfo to be a Hash so we can do some ... fun things ...
      #{"DeviceName"=>"XBox Compatible Gamepad (XInput)", "DeviceIndex"=>1, "DeviceMessages"=>{"SingleMotorVibrateCmd"=>{}, "VibrateCmd"=>{"FeatureCount"=>2}
      @deviceName=deviceInfo["DeviceName"]
      @deviceIndex=deviceInfo["DeviceIndex"]
      @client=client
      #Ok so we are starting our weird metaProgramming BS here
      if(deviceInfo["DeviceMessages"].keys.include? "VibrateCmd")
        @vibeMotors=deviceInfo["DeviceMessages"]["VibrateCmd"]["FeatureCount"]
        define_singleton_method(:vibrate){|speeds|
          #And now the real fun, we are gonna craft our message!
          id=client.generateID()
          cmd=[{"VibrateCmd"=>{"Id"=>id,"DeviceIndex"=>@deviceIndex,"Speeds"=>[]}}]
          #Ok we arn't gonna really care about how many speeds we are fed in here, we are gonna make sure that our total array isn't empty.
          (0..@vibeMotors-1).each{|i|
            if speeds[i].nil?
              speeds[i]=0
            end 
            cmd[0]["VibrateCmd"]["Speeds"]<<{"Index"=>i,"Speed"=>speeds[i]}
          }
          client.sendMessage([id,cmd.to_json])
        }
        generateActivateAllCommand(:vibrate,@vibeMotors,:vibrateAll)
      end
      if(deviceInfo["DeviceMessages"].keys.include? "LinearCmd")
        @linearActuators=deviceInfo["DeviceMessages"]["LinearCmd"]["FeatureCount"]
        generateArrayedHashCommand({"Duration"=>0, "Position"=>0.0},@linearActuators,"LinearCmd","Vectors",:stroke)
        generateActivateAllCommand(:stroke,@linearActuators,:strokeAll)
      end
      if(deviceInfo["DeviceMessages"].keys.include? "RotateCmd")
        @rotationMotors=deviceInfo["DeviceMessages"]["RotateCmd"]["FeatureCount"]
        generateArrayedHashCommand({"Speed"=>0.0,"Clockwise"=>true},@rotationMotors,"RotateCmd","Rotations",:rotate)
        generateActivateAllCommand(:rotate,@rotationMotors,:rotateAll)
      end
      if(deviceInfo["DeviceMessages"].keys.include? "RawCmd")
      #TODO: Do some stuff here with RawCmd? ... Honestly I don't know what devices would support this ... possibly estim but at the moment 🤷 I have no idea. 🤷 
      #To implement: https://metafetish.github.io/buttplug/generic.html#rawcmd
      end
    end
=begin rdoc
Stops the Device from any current actions that it might be taking. 
=end
    def stopDevice
      id=client.generateID()
      cmd="[{\"StopDeviceCmd\": {\"ID\":#{id},\"DeviceIndex\":#{@deviceIndex}}}]"
      client.sendMessage([id,cmd])
    end
##
# :method: vibrate
#
# Vibrates the motors on the device! (⁄ ⁄•⁄ω⁄•⁄ ⁄)
#
# Arguments:
# * speeds (Array - Float) - Array of speeds, any extra speeds will be dropped, and any ommitted speeds will be set to 0
#
# example:
#       device.vibrate([0.2,0.3,1])

##
# :method: vibrateAll
#
# Vibrates all motors on the device (⁄ ⁄>⁄ ▽ ⁄<⁄ ⁄)
#
# Arguments:
# * speed (Float) - The speed that all motors on the device to be set to
#
# example:
#       device.vibrateAll(0.2)

##
# :method: stroke
# Sends a command to well ... Actuate the linear motors of the device („ಡωಡ„)
#
# Arguments:
# * vectors (Array - Hash) - Array of Vectors, any extra will be dropped, and any ommited will be set to a duration of 0 and a posision of 0.0.
#
# example:
#       device.stroke([{"Duration"=>300, "Position"=>0.2},{"Duration"=>1000, "Position"=>0.8}])

##
# :method: strokeAll
#
# Sends a command to all linear actuators to respond to a vector (ง ื▿ ื)ว
#
# Arguments:
# * vector (Hash) - A single vector. 
# 
# example: 
#       device.strokeAll({"Duration"=>300, "Position"=>0.2})

##
# :method: rotate
# Spins whatever feature rotates right round ... baby right round~ (ノ*°▽°*)
#
# Arguments:
# * rotations (Array - Hash) - Array of Vectors, any extra will be dropped, and any ommited will be set to a duration of 0 and a posision of 0.0.
#
# example:
#       device.rotate([{"Speed"=>0.5,"Clockwise"=>true},{"Speed=>1, "Clockwise"=>false}])

##
# :method: rotateAll
# Spins All the features Right round like a record, baby Right round round round (*ﾉωﾉ)
#
# Arguments:
# * rotation (Hash) - Our single rotation we are sending to all the features
#
# example:
#       device.rotateAll({"Speed"=>0.5,"Clockwise"=>true})

##
#
    protected
=begin rdoc
Helper Function to generate Metaprogrammed Methods for various buttplug stuff

Arguments:
* blankHash (Hash) - An example of a Nilled out hash so the newly minted function knows what 0 looks like
* featureCount (Int) - How many features are we talking about here? I've heard rumors of a dildo with 10 vibrators~ 
* controlName (String) - And what command are we exactly sending to our server? 
# arrayName (String) - What Buttplug.io is expecting the array to be called
* cmdName (Method) - Annnnd what are we gonna call our newly minted method?

example:
     generateArrayedHashCommand({"Speed"=>0.0,"Clockwise"=>true},@rotationMotors,"RotateCmd",:rotate)  
=end
    def generateArrayedHashCommand(blankHash, featureCount, controlName, arrayName ,cmdName) #AKA I have a feeling that if we get a dedicated function for estim boxes I feel like I'd have to rewrite this code again... so let's dry it the fuck up!
      define_singleton_method(cmdName){|hash|
        id=client.generateID()
        cmd=[{"cmdName"=>{"Id"=>id,"DeviceIndex"=>@deviceIndex,controlName=>[]}}]
        (0..@linearActuators-1).each{|i|
          if vectors[i].nil?
            hash[i]=blankHash
          end
          vectors[i]["Index"]=i
        cmd[0]["LinearCmd"][arrayName]<<vectors[i]
        }
        client.sendMessage([id,cmd.to_json])
      }
    end
=begin rdoc
Helper Function to generate Metaprogrammed methods to set all instances of a feature to the same value

Arguments:
* cmdToAll (Method) - The command we are gonna call when we want to send our DO ALL THE THINGS signal
* featureCount (Int) - How many features are we controlling?
* cmdName (Method) - Annnnd what are we gonna call our newly minted command?
=end
    def generateActivateAllCommand(cmdToAll, featureCount, cmdName)
      define_singleton_method(cmdName){|var|
        vars=[]
        (0..featureCount-1).each{|i|
          vars<<var
        }
        self.public_send(cmdToAll, vars)
      }
    end
  end
end