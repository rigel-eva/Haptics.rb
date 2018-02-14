require 'faye/websocket'
require 'eventmachine'
require 'json'
module Buttplug

  class Client
    def initialize(serverLocation)
      @location=serverLocation
      #Ok Explanation time!
      # * @EventQueue - The events we are triggering on the server, Expected to be an array, with the first element being the message Id, and the second being the message itself!
      # * @responseQueue - And our messages back from the server! Will be an array with the 
      @eventQueue=EM::Queue.new
      @eventMachine=Thread.new{EM.run{
        eventQueue=@eventQueue 
        messageWatch={}
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
          eventQueue.pop{|msg|
            ws.send msg[1]
            messageWatch[msg[0]]=msg
            p [Time.now, :message_send, msg[1]] 
          }
        }
      }}
      @eventMachine.run
    end
    def startScanning()
      id=generateID()
      @eventQueue.push([id,"[{\"StartScanning\":{\"Id\":#{id}}}]"])
    end
    def stopScanning()
      id=generateID()
      @eventQueue.push([id,"[{\"StopScanning\":{\"Id\":#{id}}}]"])
    end
    def listDevices()
      id=generateID()
      deviceRequest=[id,"[{\"RequestDeviceList\": {\"Id\":#{id}}}]"]
      @eventQueue.push(deviceRequest)
      while(deviceRequest.length<3) do
        sleep 0.01#Just so we arn't occupying all the time on the system while we are waiting for our device list to come back.
      end
      return deviceRequest[2]["DeviceList"]["Devices"]
    end
    def sendMessage(message)
      @eventQueue.push(message)
      while(message.length<3) do
        sleep 0.01
      end
    end
    def generateID()
      return rand(2..4294967295)
    end
  end
  class Device
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
        define_singleton_method(:vibrateAll){|speed|
          speeds=[]
          (0..@vibeMotors-1).each{|i|
            speeds<<speed
          }
          vibrate(speeds)
        }
      end
    end

  end
end

if __FILE__==$0
  client=Buttplug::Client.new("wss://192.168.1.40:6969/buttplug")
  sleep 0.1
  client.startScanning();
  sleep 1
  devices=client.listDevices()
  client.stopScanning()
  controller=Buttplug::Device.new(client,devices[0])
 # if(request.length==2)#Ok, So something has gone wrong if our request length is 2. it should have returned something.
    #client.instance_variable_get(:@eventMachine).join
  #end
  #ok we are gonna make a few assumptions here ... primarily that you are using an xbox controller
  if(controller.methods.include? :vibrateAll)
    (0..20).each{|i|
      controller.vibrateAll(rand(0.0..1.0))
      sleep(rand(0.5..2))
    }
    controller.vibrateAll(0.0)
  end
end
