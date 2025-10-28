# frozen_string_literal: true

class Difftastic::ANSI
	RED = "\e[91;1m"
	GREEN = "\e[92;1m"
	RESET = "\e[0m"

	def self.green(string = "")
		"#{GREEN}#{string}"
	end

	def self.red(string = "")
		"#{RED}#{string}"
	end

	def self.reset(string = "")
		"#{RESET}#{string}"
	end

	def self.strip_formatting(string)
		string.to_s.gsub(/\e\[[0-9;]*m/, "")
	end
end
