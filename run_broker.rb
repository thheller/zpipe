require './msg_pipe.rb'

MsgPipe.broker!('tcp://*:7893', 'tcp://*:7894')

# never actually gets here ...
# using ZMQ::QUEUE Device which simply does its thing and never returns
#
# basically accepts requests from clients on port 7893
# then distributes the requests among workers on port 7894
#
# could just as well use ipc for the backend instead of tcp
