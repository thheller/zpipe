require './msg_pipe.rb'

# zmq gem does not seem to have device support, or i didnt find it
# so make our own QUEUE broker, just shuffle all messages from front to back
def forward_messages(from, to)
  msg = from.recv()

  while from.getsockopt(ZMQ::RCVMORE)
    to.send(msg, ZMQ::SNDMORE)
    msg = from.recv()
  end

  to.send(msg)
end

MsgPipe.run do |pipe|
  
  frontend = pipe.socket(ZMQ::XREP)
  frontend.bind('tcp://*:7893')

  backend = pipe.socket(ZMQ::XREQ)
  backend.bind('tcp://*:7894')

  puts 'starting broker action'

  while true
    if selected = ZMQ.select([frontend, backend], [], [], 1)

      selected[0].each do |it|
        case it
        when frontend
          forward_messages(frontend, backend)
        when backend
          forward_messages(backend, frontend)
        end
      end
    else
      # timeout, not gonna do anything, just wait again
    end
  end
end
