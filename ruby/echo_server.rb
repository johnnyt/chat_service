#!/usr/bin/env ruby
require 'rubygems'
require 'nsq'

consumer = Nsq::Consumer.new(
  nsqd: 'nsqd:4150',
  topic: 'input',
  channel: 'roobee'
)

producer = Nsq::Producer.new(nsqd: 'nsqd:4150', topic: 'chat')

producer.write('Ohhai')

while msg = consumer.pop
  msg.finish
  p msg.body
  producer.write(URI.encode(msg.body))
end
