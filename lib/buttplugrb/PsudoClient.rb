require 'logger'
module Buttplug
=begin rdoc
This is a class to emulate a connection to a buttplug server for testing purposes, primarily to check to see if things are echoing across right ... It will not generate a proper connection to the server specified ...
=end
    class PsudoClient < Buttplug::Client
        def initialize(serverLocation,logLocation, logLevel)
          @log=Logger.new(logLocation)
          @location=serverLocation
          @eventQueue=EM::Queue.new
          @log.level=Logger::DEBUG
          @devices=[]
          @eventMachine=Thread.new{EM.run{
            log=@log
            eventQueue=@eventQueue
            devices=@devices
            #Emulating our Normal Tick loop
            tickLoop=EM.tick_loop do 
              #emulating our normal tick loop ... 
              eventQueue.pop{|msg|
                log.debug "Message Sent: #{msg[1]}"
                p [Time.now, :message_send, msg[1]] 
                              #Aaaand Emulating our messages that we'd expect a response on ... mainly adding a device
              if JSON.parse(msg[1])[0].keys.include? "RequestDeviceList"
                msg<<{"DeviceList"=>{"Id"=>msg[0],"Devices"=>devices}}
              else 
                msg <<[{"Ok"=>{"Id"=>msg[0]}}]
              end
              }
            end
          }}
        end
        def addVirtualDevice(deviceInfo)
          @devices<<deviceInfo
        end
        def addVirtualGenericVibrator()
          id=generateID()
          addVirtualDevice({"DeviceName"=> "TestDevice #{id}","DeviceIndex"=>id-1,"DeviceMessages"=>{"SingleMotorVibrateCmd"=>{},"VibrateCmd"=>{"FeatureCount"=>2},"StopDeviceCmd"=>{}}})
        end
        def addVirtualGenericStroker()
          id=generateID()
          addVirtualDevice({"DeviceName"=> "TestDevice #{id}","DeviceIndex"=>id-1,"DeviceMessages"=>{"LinearCmd"=>{"FeatureCount"=>1},"StopDeviceCmd"=>{}}})
        end
        def addVirtualGenericRotator()
          id=generateID()
          addVirtualDevice({"DeviceName"=> "TestDevice #{id}","DeviceIndex"=>id-1,"DeviceMessages"=>{"RotateCmd"=>{"FeatureCount"=>1},"StopDeviceCmd"=>{}}})
        end
      end
end
