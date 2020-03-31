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

class Corner
  attr_reader :columns, :rows

  def initialize(radius)
    @columns = @rows = radius

    clear, solid = 0x00.chr, 0xff.chr

    lower_half = (0...radius).map do |y|
      x = Math.sqrt(radius ** 2 - y ** 2).round
      right_half = "#{solid * x}#{clear * (radius - x)}"
    end.join
    alpha_channel = lower_half.reverse
    @blob = alpha_channel.gsub(/./) { |alpha| solid * 3 + alpha }
  end

  def to_blob
    @blob
  end
end

class Window < Gosu::Window
	def initialize(width, height)
		super(width, height, {:resizable => true})
		self.caption = "Cards Against Humanity"

		@scale = 1.0
		@backgroundColor = Gosu::Color.new(255, 224, 224, 224)
		@borderColor = Gosu::Color.new(255, 155, 155, 155)
		@bigFont = Gosu::Font.new(24, {:name => "Helvetica Neue", :bold => true})
		@smallFont = Gosu::Font.new(9, {:name => "Helvetica Neue", :bold => true})

		@cornerRadius = 30
		@cardWidth = 270.0
		@cardHeight = 378.0
		@corner = Gosu::Image.new(Corner.new(@cornerRadius))
	end

	# Draws a line of text without spaces between underscores
	def drawLineWithBlanks(font, text, x, y, z, color, scale)
		text.split(" ").each do |word|
			if (word.match(/_/))
				split = word.scan(/(_*)(.*)/)[0]
				blankWidth = font.text_width(split[0]) * scale

				Gosu.draw_rect(x, y + (font.height - 3) * scale, blankWidth, 1 * scale, color, z)

				x += blankWidth
				if (split.length > 1)
					font.draw_text(split[1], x, y, z, scale, scale, color)
					x += font.text_width("#{split[1]} ") * scale
				else
					x += font.text_width(" ") * scale
				end
			else
				font.draw_text(word, x, y, z, scale, scale, color)
				x += font.text_width("#{word} ") * scale
			end
		end
	end

	# Automatically wraps a chunk of text to the provided width
	def wrapText(font, text, x, y, z, maxWidth, color, scale=1)
		lineText = ""
		lineNum = 0

		text.split(" ").each do |word|
			lineWidth = font.text_width("#{lineText} #{word}") * scale
			if (lineWidth > maxWidth * scale)
				
				drawLineWithBlanks(font, lineText, x, y + lineNum * font.height * scale, z, color, scale)
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
			drawLineWithBlanks(font, lineText, x, y + lineNum * font.height * scale, z, color, scale)
		end
	end

	# Draws a very small, square card, as seen in the Cards Against Humanity logo
	def drawTinyCard(x, y, rotation=0, white=true)
		Gosu.rotate(rotation, x, y) do
			Gosu.draw_rect(x - 1, y - 1, 9 * @scale + 2, 10 * @scale + 2, @borderColor, ZOrder::TOP)
			Gosu.draw_rect(x, y, 9 * @scale, 10 * @scale, white ? Gosu::Color::WHITE :  Gosu::Color::BLACK, ZOrder::TOP)
		end
	end

	# Draws a quarter-circle, which is used to round out the edges of the cards
	def drawCorner(cardX, cardY, color, top=true, left=true)
		drawX = cardX + (left ? 0 : (@cardWidth - @cornerRadius) * @scale)
		drawY = cardY + (top ? 0 : (@cardHeight - @cornerRadius) * @scale)
		Gosu.draw_rect(drawX, drawY, @cornerRadius * @scale, @cornerRadius * @scale, @backgroundColor, ZOrder::MIDDLE)

		drawX += (left ? 0 : @cornerRadius * @scale)
		drawY += (top ? 0 : @cornerRadius * @scale)
		@corner.draw(drawX, drawY, ZOrder::MIDDLE, left ? @scale : -@scale, top ? @scale : -@scale, color)
	end

	# Draws a Cards-Against-Humanity style card with the given text and color
	def drawCard(x, y, text, white=true)
		paddingX = 20.0
		paddingY = 18.0

		cardColor = white ? Gosu::Color::WHITE : Gosu::Color::BLACK
		textColor = white ? Gosu::Color::BLACK : Gosu::Color::WHITE

		# Card background
		Gosu.draw_rect(x, y, @cardWidth * @scale, @cardHeight * @scale, cardColor, ZOrder::MIDDLE)

		# Cut out and draw the corners
		for i in 0..3 do
			drawCorner(x, y, cardColor, i & 1 == 0, i & 2 == 0)
		end

    # The main text
    wrapText(@bigFont, text, x + paddingX * @scale, y + paddingY * @scale, ZOrder::TOP, @cardWidth - paddingX * 2, textColor, @scale)

    # Cards Against Humanity 'logo'
    logoX = x + paddingX * @scale
    logoY = y + (@cardHeight - 28 - 9) * @scale

		drawTinyCard(logoX, logoY, -15, false)
		drawTinyCard(logoX + 5 * @scale, logoY - 1 * @scale)
		drawTinyCard(logoX + 10 * @scale, logoY - 1 * @scale, 17)

  	@smallFont.draw_text("Cards Against Humanity", x + (paddingX + 20) * @scale, y + (@cardHeight - 28 - 7) * @scale, ZOrder::TOP, @scale, @scale, textColor)

	end

	# Gosu draw method
	def draw
    Gosu.draw_rect(0, 0, self.width, self.height, @backgroundColor, ZOrder::BACKGROUND)
    drawCard(30 * @scale, 30 * @scale, "50% of all marriages end in ___________.", false)
    drawCard(320 * @scale, 30 * @scale, "Politics.");
    drawCard(610 * @scale, 30 * @scale, "This new Netflix documentary you just haaaaaave to see.");
	end

	# Show the cursor at all times
	def needs_cursor?
		return true
	end
end

client = Client.new("localhost", 3000)
window = Window.new(920, 438)

window.show()