# frozen_string_literal: true

class User
	prop :name, String, reader: :public, writer: :public

	def good
		@name = "Hello"
	end

	def bad
		@name = 1
	end
end

test "instance variable writes" do
	user = User.new

	user.good
	assert_equal user.name, "Hello"

	assert_raises TypeError do
		user.bad
	end
end

test "generated writer/reader" do
	user = User.new
	user.name = "Joel"
	assert_equal user.name, "Joel"

	assert_raises TypeError do
		user.name = 1
	end
end
