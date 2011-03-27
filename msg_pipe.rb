require 'rubygems'
require 'bundler/setup'

require 'ffi-rzmq'
require 'msgpack'

module MsgPipe
  REPLY_OK = 0x01
  REPLY_ERROR = 0x02

  class << self
    def run
      pipe = Context.new()
      begin
        yield(pipe)
      ensure
        pipe.shutdown
      end
    end

    def broker!(frontend, backend)
      run do |pipe|
        pipe.broker(frontend, backend)
      end
    end

    def worker(address, handler)
      run do |pipe|
        yield(pipe.worker(address, handler))
      end
    end

    def server(address, handler)
      run do |pipe|
        yield(pipe.server(address, handler))
      end 
    end

    def client(address)
      run do |pipe|
        yield(pipe.client(address))
      end
    end
  end

  class Context
    def initialize(io_threads = 1)
      @context = ZMQ::Context.new(io_threads)
      @sockets = []
    end

    def shutdown
      @sockets.each { |it| it.close }
      @context.terminate
    end

    def broker(frontend, backend)
      @sockets << fs = @context.socket(ZMQ::XREP)
      @sockets << bs = @context.socket(ZMQ::XREQ)

      fs.bind(frontend)
      bs.bind(backend)

      puts 'starting broker'
      ZMQ::Device.new(ZMQ::QUEUE, fs, bs)
    end

    def worker(address, handler)
      @sockets << socket = @context.socket(ZMQ::REP)
      socket.connect(address)

      MsgServer.new(self, socket, address, handler)
    end

    def server(address, handler)
      @sockets << socket = @context.socket(ZMQ::REP)
      socket.bind(address)

      MsgServer.new(self, socket, address, handler)
    end

    def client(server_address)
      @sockets << socket = @context.socket(ZMQ::REQ)
      socket.connect(server_address)

      MsgClient.new(self, socket, server_address)
    end
  end

  class RemoteError < StandardError
  end

  class InvalidResponse < StandardError
  end

  class MsgClient
    def initialize(pipe, socket, address)
      @pipe = pipe
      @socket = socket
      @address = address
    end

    def call(method, *args)
      @socket.send_string([method, args].to_msgpack)

      result = @socket.recv_string()
      result_type, result = MessagePack.unpack(result)
      case result_type
      when REPLY_OK
        result
      when REPLY_ERROR
        raise RemoteError.new(result)
      else
        raise InvalidResponse, "#{method} returned something unexpected"
      end
    end
  end

  class MsgServer
    def initialize(pipe, socket, address, handler)
      @pipe = pipe
      @socket = socket
      @address = address
      @handler = handler
      @default_result = [REPLY_ERROR, "Boom"]
      @public_methods = handler.public_methods.collect { |it| it.to_s }.freeze # 1.9 == symbols
    end

    def work!
      begin
        while msg = @socket.recv_string
          method, args = MessagePack.unpack(msg)

          result = @default_result

          begin
            begin
              result = [REPLY_OK, @handler.public_send(method, *args)]
            rescue => e
              result = [REPLY_ERROR, "#{e.class}:#{e.message}"]
            end

          ensure
            @socket.send_string(result.to_msgpack)
          end
        end
      rescue => e
        @pipe.shutdown
        raise
      end
    end
  end
end

