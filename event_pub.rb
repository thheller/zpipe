
require './msg_pipe.rb'

MsgPipe.run do |pipe|

  socket = pipe.socket(ZMQ::PUB)
  socket.bind('tcp://*:7899')

  i = 0

  while true
    socket.send("event:#{i}")
    i = i + 1

    sleep(rand() / 10)
  end

end
