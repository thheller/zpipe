# simple handler class
# every public method will be reachable via rpc

class Handler

  def add(a, b)
    a + b
  end

  def hi
    'hello'
  end

  def echo(string)
    string
  end

  def sleepy
    sleep(1)
    true
  end

  def who_are_you
    "Hi, I'm #{Process.pid}" 
  end

  def throw
    raise StandardError, 'hell'
  end

  private

  def private_method
    'oh no'
  end
end

