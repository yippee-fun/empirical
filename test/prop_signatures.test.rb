# frozen_string_literal: true

class User
	prop :name, String, reader: :public

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
