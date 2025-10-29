# frozen_string_literal: true

class User
	@name :: String

	attr_reader :name

	def good
		@name = "Hello"
	end

	def bad
		@name = 1
	end
end

test do
	user = User.new

	user.good

	assert_equal "Hello", user.name

	assert_raises TypeError do
		user.bad
	end
end
