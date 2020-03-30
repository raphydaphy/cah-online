require "socket"
require "json"

class Client
	attr_reader :uuid

	def initialize(host, port)
		@socket = TCPSocket.new(host, port)
		createListener()
	end

	def sendEvent(event, data)
		@socket.puts({
			"event" => event,
			"data" => data
		}.to_json());
	end

	private

	def handleEvent(event, data)
		if (event == "init")
			puts("Obtained uuid '#{data["uuid"]}'")
			@uuid = data["uuid"]
		elsif (event == "userJoined")
			puts("#{data["uuid"]} joined the chat")
		elsif (event == "chatMessage")
			puts("#{data["uuid"]}: #{data["content"]}")
		else
			puts("Recieved unknown event: #{event}")
		end
	end

	def createListener()
		return Thread.new do
		  loop do
		  	msg = JSON.parse(@socket.gets())
		  	if (!msg.key?("event") || !msg.key?("data"))
		  		puts("Recieved invalid message: #{msg}")
		  		next
		  	end
		  	handleEvent(msg["event"], msg["data"])
		  end
		end
	end
end


client = Client.new("localhost", 3000)

puts("test")

loop do
	print("> ")
	content = gets.chomp
	client.sendEvent("chatMessage", {
		"content" => content
	})
end
