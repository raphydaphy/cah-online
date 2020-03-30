require "gosu"
require "socket"
require "json"

module ZOrder
	BACKGROUND, MIDDLE, TOP = *0..2
end

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

class Window < Gosu::Window
	def initialize(width, height)
		super(width, height, {:resizable => true})
		self.caption = "Cards Against Humanity"
		@scale = 0.8
		@backgroundColor = Gosu::Color.new(255, 224, 224, 224)
		@borderColor = Gosu::Color.new(255, 155, 155, 155)
		@bigFont = Gosu::Font.new(24, {:name => "Helvetica Neue", :bold => true})
		@smallFont = Gosu::Font.new(9, {:name => "Helvetica Neue", :bold => true})
	end

	def update
		# update
	end

	def wrapText(font, text, x, y, z, maxWidth, color, scale=1)
		lineText = ""
		lineNum = 0

		text.split(" ").each do |word|
			lineWidth = font.text_width("#{lineText} #{word}") * scale
			if (lineWidth > maxWidth * scale)
				font.draw_text(lineText, x, y + lineNum * font.height * scale, z, scale, scale, color)
				lineText = word
				lineNum += 1
			else
				if (lineText.empty?)
					lineText = word
				else
					lineText += " #{word}"
				end
			end
		end
		if (!lineText.empty?)
			font.draw_text(lineText, x, y + lineNum * font.height * scale, z, scale, scale, color)
		end
	end

	def drawTinyCard(x, y, rotation=0, white=true)
		Gosu.rotate(rotation, x, y) do
			Gosu.draw_rect(x - 1, y - 1, 9 * @scale + 2, 10 * @scale + 2, @borderColor, ZOrder::BACKGROUND)
			Gosu.draw_rect(x, y, 9 * @scale, 10 * @scale, white ? Gosu::Color::WHITE :  Gosu::Color::BLACK, ZOrder::BACKGROUND)
		end
	end

	def drawCard(x, y, text, white=true)
		width = 270.0
		height = 378.0
		paddingX = 20.0
		paddingY = 18.0

		textColor = white ? Gosu::Color::BLACK : Gosu::Color::WHITE

		Gosu.draw_rect(x, y, width * @scale, height * @scale, white ? Gosu::Color::WHITE : Gosu::Color::BLACK, ZOrder::BACKGROUND)
    wrapText(@bigFont, text, x + paddingX * @scale, y + paddingY * @scale, ZOrder::TOP, width - paddingX * 2, textColor, @scale)

    logoX = x + paddingX * @scale
    logoY = y + (height - 28 - 9) * @scale

		drawTinyCard(logoX, logoY, -15, false)
		drawTinyCard(logoX + 5 * @scale, logoY - 1 * @scale)
		drawTinyCard(logoX + 10 * @scale, logoY - 1 * @scale, 17)

  	@smallFont.draw_text("Cards Against Humanity", x + (paddingX + 20) * @scale, y + (height - 28 - 7) * @scale, ZOrder::TOP, @scale, @scale, textColor)

	end

	def draw
    Gosu.draw_rect(0, 0, self.width, self.height, @backgroundColor, ZOrder::BACKGROUND)
    drawCard(30, 30, "Bees?");
    drawCard(640, 30, "And the academy award for _____ goes to _____!", false)
	end

	def button_down(id)
		if id == Gosu::KB_ESCAPE or id == Gosu::GP_BUTTON_1
			close
		end
	end

	def needs_cursor?
		return true
	end
end


client = Client.new("localhost", 3000)
window = Window.new(1080, 720)

window.show()