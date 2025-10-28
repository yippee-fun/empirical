# frozen_string_literal: true

require "prism"

module Dispersion
	autoload :Annotator, "dispersion/annotator"
	autoload :Tokens, "dispersion/tokens"

	THEME = {
		Tokens::COMMENT => "\e[90m",
		Tokens::KEYWORD => "\e[31m",
		Tokens::CONSTANT => "\e[34m",
		Tokens::FUNCTION => "\e[33m",
		Tokens::PUNCTUATION => "\e[37m",
		Tokens::LOCAL_VARIABLE => "\e[32m",
		Tokens::INSTANCE_VARIABLE => "\e[35m",
		Tokens::OPERATOR => "\e[33m",
		Tokens::STRING => "\e[32m",
		Tokens::SYMBOL => "\e[36m",
		Tokens::INTEGER => "\e[33m",
		Tokens::FLOAT => "\e[33m",
	}.freeze

	def self.annotate(code)
		Annotator.call(code)
	end

	def self.ansi(code)
		code.dup.tap do |buffer|
			offset = 0

			for start_offset, end_offset, token in annotate(code)
				start = THEME.fetch(token)

				buffer.bytesplice(start_offset + offset, 0, start)
				offset += start.bytesize

				buffer.bytesplice(end_offset + offset, 0, "\e[0m")
				offset += 4
			end
		end
	end
end
