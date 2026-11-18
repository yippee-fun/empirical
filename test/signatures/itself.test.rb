# frozen_string_literal: true

class ItselfExample
	fun returns_self => itself do
		self
	end

	fun returns_other => itself do
		ItselfExample.new
	end

	fun returns_self_early => itself do
		return self if true
		ItselfExample.new
	end

	fun returns_other_early => itself do
		return ItselfExample.new if true
		self
	end

	fun returns_nil_early => itself do
		return if true
		self
	end

	fun returns_self_from_instance_eval => itself do
		receiver = self
		Object.new.instance_eval { return receiver }
	end

	fun returns_other_from_instance_eval => itself do
		Object.new.instance_eval { return self }
	end

	fun self.build => itself do
		self
	end

	fun self.build_instance => itself do
		new
	end
end

class ItselfWithEqualOverride
	def equal?(other) = true

	fun returns_other => itself do
		ItselfWithEqualOverride.new
	end
end

test "itself passes when the method returns self" do
	example = ItselfExample.new

	assert example.returns_self.equal?(example)
end

test "itself raises when the method returns another instance of the same class" do
	error = assert_raises(Empirical::TypeError) do
		ItselfExample.new.returns_other
	end

	assert error.message.include?("Method returns_other returned a different object instead of itself.")
	assert error.message.include?("ItselfExample#returns_other")
end

test "itself passes on an early return of self" do
	example = ItselfExample.new

	assert example.returns_self_early.equal?(example)
end

test "itself raises on an early return of another object" do
	assert_raises(Empirical::TypeError) do
		ItselfExample.new.returns_other_early
	end
end

test "itself raises on a bare early return" do
	assert_raises(Empirical::TypeError) do
		ItselfExample.new.returns_nil_early
	end
end

test "itself compares against the method’s receiver on an early return from instance_eval" do
	example = ItselfExample.new

	assert example.returns_self_from_instance_eval.equal?(example)

	assert_raises(Empirical::TypeError) do
		ItselfExample.new.returns_other_from_instance_eval
	end
end

test "itself refers to the receiver of a singleton method" do
	assert ItselfExample.build.equal?(ItselfExample)

	assert_raises(Empirical::TypeError) do
		ItselfExample.build_instance
	end
end

test "itself doesn’t trust an overridden equal?" do
	assert_raises(Empirical::TypeError) do
		ItselfWithEqualOverride.new.returns_other
	end
end
