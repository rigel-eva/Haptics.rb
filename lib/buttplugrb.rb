require 'faye/websocket'
require 'eventmachine'
require 'json'

=begin rdoc
Our Module for containg the functions and classes relating to the Buttplugrb gem
=end
module Buttplug
=begin rdoc
  The module holding all of our various log levels that our client can set our server to
=end
  module LogLevel
    Off = 0
    Fatal = 1
    Error = 2
    Warn = 3
    Info = 4
    Debug = 5
    Trace = 6
  end
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
    def initialize(serverLocation, clientName="buttplugrb")
      @messageID=1
      @location=serverLocation
      #Ok Explanation time!
      # * @EventQueue - The events we are triggering on the server, Expected to be an array, with the first element being the message Id, and the second being the message itself!
      @eventQueue=EM::Queue.new
      @logLevel=Buttplug::LogLevel::Off
      @scanning=false
      @currentDevices=[];
      startEventMachine()
      @eventMachine.run
    end
    def setLogLevel(logLevel)
      @logLevel=logLevel
    end
=begin rdoc
Tells our server to start scanning for new devices
=end
    def startScanning()
      id=generateID()
      response=sendMessage([id,"[{\"StartScanning\":{\"Id\":#{id}}}]"])
      if(response[0].keys.include? "Error")
        #TODO: Add Error Handling code
      end
    end
=begin rdoc
Tells our server to stop scanning for new devices
=end
    def stopScanning()
      id=generateID()
      @eventQueue.push([id,"[{\"StopScanning\":{\"Id\":#{id}}}]"])
    end
    def isScanning?()
      return @scanning
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
      @messageID+=1
      return @messageID
    end
    def currentDevices()
      return @currentDevices
    end
    def deviceSusbscribe(id,&code)
      #TODO: Add Code here to allow a class like Buttplug::Device to subscribe to events, annnnd realize that the device has disconnected when that does happen (like the hush has a tendeancy to do ... )
    end
    protected 
    def startEventMachine()
      @eventMachine=Thread.new{EM.run{
        eventQueue=@eventQueue
        messageWatch={}
        logLevel=@logLevel
        scanning=@scanning
        currentDevices=@currentDevices
        ws = Faye::WebSocket::Client.new(@location)
        tickLoop=EM.tick_loop do #Should improve response times~
          eventQueue.pop{|msg|
            ws.send msg[1]
            messageWatch[msg[0]]=msg
            p [Time.now, :message_send, msg[1]] 
          }
        end
        ws.on :open do |event|
          p [Time.now, :open]
          ws.send "[{\"RequestServerInfo\": {\"Id\": 1, \"ClientName\": \"#{clientName}\", \"MessageVersion\": 1}}]"
          #TODO: Add MaxPingTime Code
        end
        ws.on :message do |event|
          #Ok, first of all let's grab 
          message=JSON::parse(event.data).each{|event|
            message.each{|key,value|
              #We don't really care about the key just yet ... We are going to just care about finding our ID
              if(messageWatch.keys.include?(value["Id"]))
                messageWatch[value["Id"]]<<{key => value}#And now we care about our key!
                puts messageWatch[value["Id"]].object_id
                messageWatch.delete(value["Id"])
                p [Time.now, :message_recieved, [{key => value}]]
                next
              #If we are currently scanning, we should Probably check and see if we recieved a ScanningFinished message
              elsif(scanning&&key=="ScanningFinished")
                p [Time.now,:ScanningFinished]
                scanning=false
              #If we are logging, we should probably Check and see if this is a log ... 
              elsif(logLevel>Buttplug::LogLevel::Off&&key=="Log")
                p [Time.now,:ServerLog,value]
              #and last but not least if we spot our server info we should probably log it ...
              elsif(key=="DeviceAdded")
                #Oh? Sweet let's go ahead and add it's information to our array!
                currentDevices.push(
                  {"DeviceName" => value["DeviceName"], "DeviceIndex" => value["DeviceIndex"], "DeviceMessages" => value["DeviceMessages"]})
              elsif(key=="DeviceRemoved")
                #well darn, and to just have compatability with the current js version of buttplug.io we are gonna do this a bit diffrently than I'd like ... we are totally not doing this because I'm feeling lazy and want to push out this itteration, no sir
                currentDevices.reject!{|device|
                  device["Id"]==value["Id"]
                }
              elsif(key=="ServerInfo")
                p [Time.now, :server_info, value]
              end
            }
          }
        end
        ws.on :close do |event|
          p [Time.now, :close, event.code, event.reason]
          ws = nil
          #TODO: Add Nil checks for Sends, and Nil out the ping when closed
        end
        EM.add_periodic_timer(0.5){
          ws.send "[{\"Ping\": {\"Id\": #{generateID()}}}]"
        }
        #TODO: Add Error code https://metafetish.github.io/buttplug/status.html#error
          #So, I should probably add some basic error handling to most of the code then ... 
        #TODO: Add Log code https://metafetish.github.io/buttplug/status.html#requestlog 
          #Done, I think ... please correct me if I'm wrong
      }}
    end
    #TODO: Add Method to disconnect from current Server
    #TODO: Add Method for reconnecting to a Server
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
      id=@client.generateID()
      cmd="[{\"StopDeviceCmd\": {\"ID\":#{id},\"DeviceIndex\":#{@deviceIndex}}}]"
      @client.sendMessage([id,cmd])
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
        id=@client.generateID()
        cmd=[{controlName=>{"Id"=>id,"DeviceIndex"=>@deviceIndex,arrayName=>[]}}]
        (0..featureCount-1).each{|i|
          if hash[i].nil?
            hash[i]=blankHash
          end
          hash[i]["Index"]=i
          cmd[0][controlName][arrayName]<<hash[i]
        }
        @client.sendMessage([id,cmd.to_json])
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
#And loading in any other things that might help (including debug ...)
Dir["#{File.dirname(__FILE__)}/buttplugrb/*.rb"].each {|file| require file }
