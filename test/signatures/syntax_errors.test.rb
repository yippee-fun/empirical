# frozen_string_literal: true

test do
	mod = Module.new do
		extend self

		# ✔︎
		fun foo => String do
			"Hello"
		end
	end

	assert_equal mod.foo, "Hello"
end
