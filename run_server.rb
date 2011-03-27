require './msg_pipe.rb'
require './handler.rb'

MsgPipe.server('tcp://127.0.0.1:7893', Handler.new) do |server|
  puts 'server starting to accept work'

  server.work!
  # this only exits on interrupt
end
