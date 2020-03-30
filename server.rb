require "socket"
require "securerandom"
require "json"

class User
	attr_reader :id, :socket
	attr_accessor :name, :active

	def initialize(id, socket, name)
		@id = id
		@socket = socket
		@name = name
		@active = true
	end

	def ==(other)
		if (!other.instanceof? User)
			return false
		end
		return @id == other.id && @name == other.name
	end
end

class Server
	def initialize(port)
		@users = Hash.new()
		@server = TCPServer.new(port)
		puts("Listening on port #{port}")
	end

	private

	# Attempts to get the socket for a given uuid
	def getSocket(uuid)
		if (!@users.key?(uuid))
			puts("Tried to get socket for invalid uuid '#{uuid}'")
			return nil
		end
		return @users[uuid].socket
	end

	# Formats and sends an event to the socket provided
	def sendEvent(socket, event, data=Hash.new())
		if (socket == nil)
			puts("Tried to send event '#{event}' to invalid socket")
			return
		end
		msg = {
			"event" => event, 
			"data" => data
		}
		socket.puts(msg.to_json())
	end

	# Sends the event to all users unless their uuid == except
	def broadcastEvent(event, data=Hash.new(), except=nil)
		@users.each do |uuid, user|
			if (uuid != except && user.active)
				sendEvent(getSocket(uuid), event, data)
			end
		end
	end

	# Called whenever a client sends an event to the server
	def handleEvent(socket, uuid, event, data)
		case event
		when "chatMessage"
			puts("#{uuid}: #{data["content"]}")
			broadcastEvent("chatMessage", {
				"uuid" => uuid,
				"content" => data["content"]
			}, uuid)
		else
			puts("Recieved invalid event: #{data["event"]}")
		end
	end

	public

	def run()
		loop do
			Thread.new(@server.accept) do |socket|
				uuid = SecureRandom.uuid()
				@users[uuid] = User.new(uuid, socket, "Guest");

				puts("#{uuid} joined the chat")

				sendEvent(socket, "init", {"uuid" => uuid})
				broadcastEvent("userJoined", {"uuid" => uuid}, uuid)

				loop do
					msg = socket.gets()
					# A nil message means the user has left
					if (msg == nil)
						puts("Goodbye #{uuid}")
						@users[uuid].active = false
						socket.close()
						Thread.exit
					end
					msg = JSON.parse(msg)
					if (!msg.key?("event") || !msg.key?("data"))
						puts("Recieved invalid msg from #{uuid}: #{msg.to_s()}")
						next
					end
					handleEvent(socket, uuid, msg["event"], msg["data"])
				end
			end
		end
	end
end

server = Server.new(3000)
server.run()