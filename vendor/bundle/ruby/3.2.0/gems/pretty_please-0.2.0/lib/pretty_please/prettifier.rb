# frozen_string_literal: true

class PrettyPlease::Prettifier
	Null = Object.new

	def self.call(object, ...)
		new(...).call(object)
	end

	def initialize(indent: 0, tab_width: 2, max_width: 30, max_items: 10, max_depth: 5)
		@indent = indent
		@tab_width = tab_width
		@max_width = max_width
		@max_items = max_items
		@max_depth = max_depth
		@indent_bytes = " " * @tab_width
		@running_depth = 0

		@buffer = +""
		@lines = 0 # note, this is not reset within a capture
		@stack = []
		@original_object = Null
	end

	def call(object)
		prettify(object)
		@buffer
	end

	def prettify(object)
		original_object = @original_object

		if original_object == Null
			@original_object = object
		else
			if original_object.equal?(object)
				push "self"
				return
			end
		end

		@stack.push(object)

		if object.respond_to?(:pretty_please)
			object.pretty_please(self)
		else
			case object
			when Symbol, String, Integer, Float, Regexp, Range, Rational, Complex, TrueClass, FalseClass, NilClass
				push object.inspect
			when Module
				push object.name
			when File, defined?(Pathname) && Pathname
				push %(#{object.class.name}("#{object.to_path}"))
			when MatchData, (defined?(Date) && Date), (defined?(DateTime) && DateTime), (defined?(Time) && Time), (defined?(URI) && URI)
				push %(#{object.class.name}("#{object}"))
			when Array
				push "["
				map(object) { |it| capture { prettify(it) } }
				push "]"
			when Exception
				push %(#{object.class.name}("#{object.message}"))
			when Hash
				push "{"
				map(object, around_inline: " ") do |key, value|
					case key
					when Symbol
						"#{key.name}: #{capture { prettify(value) }}"
					else
						key = capture { prettify(key) }
						value = capture { prettify(value) }
						"#{key} => #{value}"
					end
				end
				push "}"
			when Struct, defined?(Data) && Data
				push "#{object.class.name}("
				items = object.members.map { |key| [key, object.__send__(key)] }
				map(items) { |key, value| "#{key}: #{capture { prettify(value) }}" }
				push ")"
			when defined?(Set) && Set
				push "Set["
				map(object) { |it| capture { prettify(it) } }
				push "]"
			when defined?(ActiveRecord::Base) && ActiveRecord::Base
				max_items_before = @max_items
				@max_items = object.attributes.length

				push "#{object.class.name}("
				map(object.attributes) do |(key, value)|
					"#{key}: #{capture { prettify(value) }}"
				end
				push ")"

				@max_items = max_items_before
			else
				push "#{object.class.name}("
				map(object.instance_variables) do |name|
					"#{name} = #{capture { prettify(object.instance_variable_get(name)) }}"
				end
				push ")"
			end
		end

		@stack.pop
	end

	def map(object, around_inline: nil)
		if @stack.size >= @max_depth
			push "..."
			return
		end

		@running_depth += 1

		return unless object.any?

		length = 0
		length += around_inline.bytesize * 2 if around_inline

		original_lines = @lines
		exceeds_max_items = object.length > @max_items
		current_running_depth = @running_depth

		items = indent do
			object.take(@max_items).map do |item|
				pretty_item = yield(item)
				length += pretty_item.bytesize + 2 # for the ", "
				pretty_item
			end
		end

		if (@lines > original_lines) || (length > @max_width) || (@running_depth > current_running_depth)
			indent do
				items.each do |item|
					newline
					push item
					push ","
				end

				if exceeds_max_items
					newline
					push "..."
				end
			end
			newline

		else # inline
			push around_inline
			push items.join(", ")
			push ", ..." if exceeds_max_items
			push around_inline
		end
	end

	def indent
		@indent += 1
		value = yield
		@indent -= 1
		value
	end

	def newline
		@lines += 1
		push "\n#{@indent_bytes * @indent}"
	end

	def push(string)
		return unless string
		@buffer << string
	end

	def capture
		original_buffer = @buffer
		new_buffer = +""
		@buffer = new_buffer
		yield
		@buffer = original_buffer
		new_buffer
	end
end
