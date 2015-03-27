require 'nsq'

consumer = Nsq::Consumer.new(
  nsqd: '127.0.0.1:49250',
  topic: 'input',
  channel: 'roobee'
)

producer = Nsq::Producer.new(nsqd: '127.0.0.1:49250', topic: 'chat')

producer.write('Ohhai')

while msg = consumer.pop
  msg.finish
  p msg.body
  producer.write(URI.encode(msg.body))
end