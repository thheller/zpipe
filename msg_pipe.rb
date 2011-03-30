require 'rubygems'
require 'bundler'

Bundler.setup
Bundler.require(:default, 'development')

module MsgPipe
  REPLY_OK = 0x01
  REPLY_ERROR = 0x02

  class << self

    # should only call this once per process
    # should probably check this somehow and fail!
    def run
      pipe = Context.new()

      ['INT'].each do |sig|
        Signal.trap(sig) do
          puts "Process received #{sig}, shutting down pipe."
          pipe.shutdown
          exit(1)
        end
      end

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

    def contact_dealer(address)
      run do |pipe|
        yield(pipe.contact_dealer(address))
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
      @context.close
    end

    def socket(type)
      @sockets << socket = @context.socket(type)
      socket
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

    def contact_dealer(address)
      @sockets << socket = @context.socket(ZMQ::REQ)
      socket.connect(address)

      MsgDealer.new(self, socket, address)
    end
  end

  class RemoteError < StandardError
  end

  class InvalidResponse < StandardError
  end

  # simple client/server rpc
  #
  class MsgClient
    def initialize(pipe, socket, address)
      @pipe = pipe
      @socket = socket
      @address = address
    end

    def call(method, *args)
      @socket.send([method, args].to_msgpack)

      result = @socket.recv()
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
      while msg = @socket.recv
        method, args = MessagePack.unpack(msg)

        result = @default_result

        begin
          begin
            result = [REPLY_OK, @handler.public_send(method, *args)]
          rescue => e
            result = [REPLY_ERROR, "#{e.class}:#{e.message}"]
          end

        ensure
          @socket.send(result.to_msgpack)
        end
      end
    end
  end

  # little more involved client -> dealer -> fanout -> fanin -> reply
  class MsgDealer
    def initialize(pipe, socket, address)
      @pipe = pipe
      @socket = socket
      @address = address 
    end

    attr_reader :socket

    def new_task()
      MsgTask.new(self) 
    end
  end

  class MsgTask
    def initialize(dealer)
      @dealer = dealer
      @task_id = Digest::MD5.hexdigest([Time.now.to_f, rand(), rand()].join(":"))
      @tasks = {}

      @results = {}
      @timeouts = []
    end

    def add(task_name, method, *args)
      @tasks[task_name] = [method, args]
    end

    attr_reader :results, :timeouts

    # I have one speed, one gear: GO!
    def go!(timeout)
      @dealer.socket.send([@task_id, @tasks, timeout].to_msgpack)
      completed, timeouts = MessagePack.unpack(@dealer.socket.recv)

      @results = {}
      completed.each do |k, v|
        @results[k.to_sym] = v
      end

      @timeouts = timeouts
    end
    
    def all_done?
      @timeouts.empty? and @results.size == @tasks.size
    end

  end

end

