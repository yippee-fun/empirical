# frozen_string_literal: true

test "optional keyword argument" do
	mod = Module.new do
		extend self

		fun example(name: _Nilable(String)) => String do
			if name
				"Hello #{name}"
			else
				"Hello"
			end
		end
	end

	assert_equal mod.example, "Hello"
	assert_equal mod.example(name: "Joel"), "Hello Joel"
end
