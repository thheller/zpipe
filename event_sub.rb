require './msg_pipe.rb'

MsgPipe.run do |pipe|
  socket = pipe.socket(ZMQ::SUB)
  socket.connect('tcp://localhost:7899')
  socket.setsockopt(ZMQ::SUBSCRIBE, '')

  while msg = socket.recv()
    p msg
  end
end
