require 'spec_helper'

describe "Publisher Publishing Messages" do
  let(:config) do
    {
      :header_template => nil,
      :message_template => "~text~",
      :footer_template => nil,
      :ping_message_interval => nil
    }
  end

  it "should receive the published message" do
    body = 'published unique message'
    channel = 'ch_test_publish_messages'

    nginx_run_server(config) do |conf|
      EventMachine.run do
        sub = EventMachine::HttpRequest.new(nginx_address + '/sub/' + channel.to_s).get :head => headers
        sub.stream do |chunk|
          chunk.should eql(body)
          EventMachine.stop
        end

        publish_message_inline(channel, headers, body)
      end
    end
  end

  it "should publish a message with PUT method" do
    body = 'published unique message'
    channel = 'ch_test_publish_messages_with_put'

    nginx_run_server(config, :timeout => 5) do |conf|
      EventMachine.run do
        sub = EventMachine::HttpRequest.new(nginx_address + '/sub/' + channel.to_s).get :head => headers
        sub.stream do |chunk|
          chunk.should eql(body)
          EventMachine.stop
        end

        EM.add_timer(0.5) do
          EventMachine::HttpRequest.new(nginx_address + '/pub?id=' + channel.to_s ).put :head => headers, :body => body, :timeout => 30
        end
      end
    end
  end

  it "should accept messages with different bytes" do
    channel = 'ch_test_publish_messages_with_different_bytes'

    nginx_run_server(config.merge(:client_max_body_size => '130k', :client_body_buffer_size => '130k', :subscriber_connection_ttl => "1s")) do |conf|
      ranges = [0..255]
      ranges.each do |range|
        bytes = []
        range.each do |i|
          0.upto(255) do |j|
            bytes << "%s%s" % [i.chr, j.chr]
          end
        end

        body = bytes.join('')
        response = ''

        EventMachine.run do
          sub = EventMachine::HttpRequest.new(nginx_address + '/sub/' + channel.to_s).get :head => headers
          sub.stream do |chunk|
            response += chunk
          end

          sub.callback do
            response.bytes.to_a.should eql(body.bytes.to_a)
            EventMachine.stop
          end

          publish_message_inline(channel, headers, body)
        end
      end
    end
  end

  it "should receive large messages" do
    channel = 'ch_test_publish_large_messages'
    small_message = "^|" + ("0123456789" * 1020) + "|$"
    large_message = "^|" + ("0123456789" * 419430) + "|$"

    response_sub = ''
    response_sub_1 = ''

    nginx_run_server(config.merge(client_max_body_size: '5m', client_body_buffer_size: '1m', subscriber_connection_ttl: '5s', shared_memory_size: '15m'), timeout: 10) do |conf|
      EventMachine.run do
        start = Time.now
        sub = EventMachine::HttpRequest.new(nginx_address + '/sub/' + channel.to_s).get :head => headers
        sub.stream do |chunk|
          response_sub += chunk

          if response_sub.include?('A')
            response_sub.should eql(large_message + 'A')
            response_sub = ''

            # check if getting old messages works fine too
            sub_1 = EventMachine::HttpRequest.new(nginx_address + '/sub/' + channel.to_s + ".b1").get :head => headers
            sub_1.stream do |chunk_1|
              response_sub_1 += chunk_1

              if response_sub_1.include?('A')
                response_sub_1.should eql(large_message + 'A')
                response_sub_1 = ''

                publish_message_inline(channel, headers, small_message + 'B')
              end
            end

            sub_1.callback do
              fail("should not disconnect the client")
            end
          end
        end

        sub.callback do
          fail("should not disconnect the client")
        end

        EM.add_timer(3) do
          if response_sub.include?('B') && response_sub_1.include?('B')
            response_sub.should eql(small_message + 'B')
            response_sub_1.should eql(small_message + 'B')

            large_message.size.should eql(4194304) # 4mb
            small_message.size.should eql(10204) # 10k
            EventMachine.stop
          end
        end

        publish_message_inline(channel, headers, large_message + 'A')
      end
    end
  end

  it "should format message with text contains huge number of template patterns" do
    channel = 'ch_test_publish_messages_with_template_patterns'
    body = "|~id~|~channel~|~text~|~event-id~|~tag~" * 20000 + "|"
    response = ''

    nginx_run_server(config.merge(:client_max_body_size => '2000k', :client_body_buffer_size => '2000k', :message_template => '{\"id\": \"~id~\", \"channel\": \"~channel~\", \"text\": \"~text~\", \"event_id\": \"~event-id~\",\"tag\": \"~tag~\"}'), :timeout => 15) do |conf|
      EventMachine.run do
        start = Time.now
        pub = EventMachine::HttpRequest.new(nginx_address + '/pub?id=' + channel.to_s ).post :head => headers, :body => body
        pub.stream do |chunk|
          response += chunk
        end
        pub.callback do
          (Time.now - start).should be < 0.1 #should fast proccess message
          response.strip.should eql('{"channel": "ch_test_publish_messages_with_template_patterns", "published_messages": "1", "stored_messages": "1", "subscribers": "0"}')
          EventMachine.stop
        end
      end
    end
  end

  it "should publish many messages in the same channel" do
    body_prefix = 'published_message_'
    channel = 'ch_test_publish_many_messages_in_the_same_channel'
    messagens_to_publish = 1500

    response = ""
    nginx_run_server(config.merge(:max_reserved_memory => "256m", :keepalive_requests => 500, :message_template => "~text~|")) do |conf|
      EventMachine.run do
        sub = EventMachine::HttpRequest.new(nginx_address + '/sub/' + channel.to_s).get :head => headers
        sub.stream do |chunk|
          response += chunk
          recieved_messages = response.split("|")

          if recieved_messages.length == messagens_to_publish
            recieved_messages.last.should eql(body_prefix + messagens_to_publish.to_s)
            EventMachine.stop
          end
        end

        EM.add_timer(0.5) do
          0.step(messagens_to_publish - 1, 500) do |i|
            socket = open_socket(nginx_host, nginx_port)
            1.upto(500) do |j|
              resp_headers, body = post_in_socket("/pub?id=#{channel}", "#{body_prefix}#{i+j}", socket, {:wait_for => "}\r\n"})
              fail("Message was not published: " + body_prefix + (i+j).to_s) unless resp_headers.include?("HTTP/1.1 200 OK")
            end
            socket.close
          end
        end
      end
    end
  end

  it "should set an event id to the message through header parameter" do
    event_id = 'event_id_with_generic_text_01'
    body = 'test message'
    channel = 'ch_test_set_an_event_id_to_the_message_through_header_parameter'
    response = ''

    nginx_run_server(config.merge(:message_template => '{\"id\": \"~id~\", \"channel\": \"~channel~\", \"text\": \"~text~\", \"event_id\": \"~event-id~\"}')) do |conf|
      EventMachine.run do
        sub = EventMachine::HttpRequest.new(nginx_address + '/sub/' + channel.to_s).get
        sub.stream do |chunk|
          response = JSON.parse(chunk)
          response["id"].to_i.should eql(1)
          response["channel"].should eql(channel)
          response["text"].should eql(body)
          response["event_id"].should eql(event_id)
          EventMachine.stop
        end

        publish_message_inline(channel, headers.merge('Event-Id' => event_id), body)
      end
    end
  end

  it "should set an event type to the message through header parameter" do
    event_type = 'event_type_with_generic_text_01'
    body = 'test message'
    channel = 'ch_test_set_an_event_type_to_the_message_through_header_parameter'
    response = ''

    nginx_run_server(config.merge(:message_template => '{\"id\": \"~id~\", \"channel\": \"~channel~\", \"text\": \"~text~\", \"event_type\": \"~event-type~\"}')) do |conf|
      EventMachine.run do
        sub = EventMachine::HttpRequest.new(nginx_address + '/sub/' + channel.to_s).get
        sub.stream do |chunk|
          response = JSON.parse(chunk)
          response["id"].to_i.should eql(1)
          response["channel"].should eql(channel)
          response["text"].should eql(body)
          response["event_type"].should eql(event_type)
          EventMachine.stop
        end

        publish_message_inline(channel, headers.merge('Event-type' => event_type), body)
      end
    end
  end

  it "should ignore event id header parameter which not match exactly" do
    event_id = 'event_id_with_generic_text_01'
    body = 'test message'
    channel = 'ch_test_set_an_event_id_to_the_message_through_header_parameter'
    response = ''

    nginx_run_server(config.merge(:message_template => '{\"id\": \"~id~\", \"channel\": \"~channel~\", \"text\": \"~text~\", \"event_id\": \"~event-id~\"}')) do |conf|
      EventMachine.run do
        sub = EventMachine::HttpRequest.new(nginx_address + '/sub/' + channel.to_s).get
        sub.stream do |chunk|
          response = JSON.parse(chunk)
          response["id"].to_i.should eql(1)
          response["channel"].should eql(channel)
          response["text"].should eql(body)
          response["event_id"].should eql("")
          EventMachine.stop
        end

        publish_message_inline(channel, headers.merge('Event-Ids' => event_id), body)
      end

      EventMachine.run do
        sub = EventMachine::HttpRequest.new(nginx_address + '/sub/' + channel.to_s).get
        sub.stream do |chunk|
          response = JSON.parse(chunk)
          response["id"].to_i.should eql(2)
          response["channel"].should eql(channel)
          response["text"].should eql(body)
          response["event_id"].should eql("")
          EventMachine.stop
        end

        publish_message_inline(channel, headers.merge('Event-I' => event_id), body)
      end
    end
  end

  it "should expose message publish time through message template" do
    body = 'test message'
    channel = 'ch_test_expose_message_publish_time_through_message_template'
    response = ''
    now = nil

    nginx_run_server(config.merge(:message_template => '{\"id\": \"~id~\", \"channel\": \"~channel~\", \"text\": \"~text~\", \"publish_time\": \"~time~\"}')) do |conf|
      EventMachine.run do
        sub = EventMachine::HttpRequest.new(nginx_address + '/sub/' + channel.to_s).get
        sub.stream do |chunk|
          response = JSON.parse(chunk)
          response["id"].to_i.should eql(1)
          response["channel"].should eql(channel)
          response["text"].should eql(body)
          response["publish_time"].size.should eql(29)
          publish_time = Time.parse(response["publish_time"])
          publish_time.to_i.should be_in_the_interval(now.to_i, now.to_i + 1)

          EventMachine.stop
        end

        now = Time.now
        publish_message_inline(channel, headers, body)
      end
    end
  end

  it "should expose message tag through message template" do
    body = 'test message'
    channel = 'ch_test_expose_message_tag_through_message_template'
    response = ''

    nginx_run_server(config.merge(:message_template => '{\"id\": \"~id~\", \"channel\": \"~channel~\", \"text\": \"~text~\", \"tag\": \"~tag~\"}')) do |conf|
      EventMachine.run do
        sub = EventMachine::HttpRequest.new(nginx_address + '/sub/' + channel.to_s).get
        sub.stream do |chunk|
          response += chunk
          lines = response.split('\r\n')
          if lines.size > 1
            lines.each_with_index do |line, i|
              resp = JSON.parse(line)
              resp["id"].to_i.should eql(i + 1)
              resp["channel"].should eql(channel)
              resp["text"].should eql(body)
              resp["tag"].to_i.should eql(i)
            end
          end

          EventMachine.stop
        end

        publish_message_inline(channel, headers, body)
        publish_message_inline(channel, headers, body)
      end
    end
  end
end
