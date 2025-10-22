# frozen_string_literal: true

class Empirical::SignatureProcessor < Empirical::BaseProcessor
	def initialize(...)
		@return_type = nil
		super
	end

	def visit_call_node(node)
		return super unless :fun == node.name

		raise SyntaxError unless node.arguments
		raise SyntaxError unless nil == node.receiver

		case node
		in {
			arguments: Prism::ArgumentsNode[
				arguments: [
					Prism::KeywordHashNode[
						elements: [
							Prism::AssocNode[
								key: signature,
								value: return_type
							]
						]
					]
				]
			],
			block: Prism::BlockNode => body_block
		}
			preamble = []
			postamble = []

			case signature
			in Prism::LocalVariableReadNode | Prism::ConstantReadNode
				# no-op
				# method_name = signature.name
			in Prism::CallNode
				# method_name = signature.name
				raise SyntaxError if signature.block

				signature.arguments&.arguments&.each do |argument|
					case argument
					# Positional splat e.g. `a = [Integer]` becomes `*a`
					in Prism::LocalVariableWriteNode[name: name, value: Prism::ArrayNode[elements: [type]]]
						@annotations << [
							argument.name_loc.start_offset,
							0,
							"*",
						]

						@annotations << [
							argument.name_loc.end_offset,
							type.location.end_offset - argument.name_loc.end_offset + 1,
							"",
						]

						preamble << "raise(::Empirical::TypeError.argument_type_error(name: '#{name}', value: #{name}, expected: ::Literal::_Array(#{type.slice}), method_name: __method__, context: self)) unless ::Literal::_Array(#{type.slice}) === #{name}"

					# Positional (a)
					in Prism::LocalVariableWriteNode[name: name, value: type]
						case type

						# Positional with default (a = 1)
						in Prism::CallNode[name: :|, receiver: t, arguments: Prism::ArgumentsNode[arguments: [default]]]
							type_string = t.slice
							default_string = default.slice
						else
							type_string = type.slice
							default_string = "nil"
						end

						@annotations << [
							type.location.start_offset,
							type.location.end_offset - type.location.start_offset,
							default_string,
						]

						preamble << "raise(::Empirical::TypeError.argument_type_error(name: '#{name}', value: #{name}, expected: #{type_string}, method_name: __method__, context: self)) unless #{type_string} === #{name}"
					in Prism::KeywordHashNode
						argument.elements.each do |argument|
							name = argument.key.unescaped
							type = argument.value

							case type
							# Keyword splat (**foo)
							in Prism::HashNode[elements: [Prism::AssocNode[key: key_type, value: value_type]]]
								@annotations << [
									argument.key.location.start_offset,
									0,
									"**",
								]

								@annotations << [
									argument.key.location.end_offset - 1,
									type.location.end_offset - argument.key.location.end_offset + 1,
									"",
								]

								preamble << "raise(::Empirical::TypeError.argument_type_error(name: '#{name}', value: #{name}, expected: ::Literal::_Hash(#{key_type.slice}, #{value_type.slice}), method_name: __method__, context: self)) unless ::Literal::_Hash(#{key_type.slice}, #{value_type.slice}) === #{name}"
							else
								case type
								# Keyword with default
								in Prism::CallNode[name: :|, receiver: t, arguments: Prism::ArgumentsNode[arguments: [default]]]
									type_string = t.slice
									default_string = default.slice
								else
									type_string = type.slice
									default_string = "nil"
								end

								@annotations << [
									type.location.start_offset,
									type.location.end_offset - type.location.start_offset,
									default_string,
									]

								preamble << "raise(::Empirical::TypeError.argument_type_error(name: '#{name}', value: #{name}, expected: #{type_string}, method_name: __method__, context: self)) unless #{type_string} === #{name}"
							end
						end
					else
						raise SyntaxError
					end
				end
			else
				raise SyntaxError
			end

			preamble << "__literally_returns__ = ("
			postamble << ")"

			case return_type
			in Prism::LocalVariableReadNode[name: :void] | Prism::CallNode[name: :void, receiver: nil, block: nil, arguments: nil]
				postamble << "::Empirical::Void"
			in Prism::LocalVariableReadNode[name: :never] | Prism::CallNode[name: :never, receiver: nil, block: nil, arguments: nil]
				postamble << "raise(::Empirical::NeverError.new)"
			else
				postamble << "raise(::Empirical::TypeError.return_type_error(value: __literally_returns__, expected: #{return_type.slice}, method_name: __method__, context: self)) unless #{return_type.slice} === __literally_returns__"
				postamble << "__literally_returns__"
			end

			# Replace `fun` with `def`
			@annotations << [
				node.message_loc.start_offset,
				node.message_loc.end_offset - node.message_loc.start_offset,
				"def",
			]

			# Remove the return type and `do` and replace with preamble
			@annotations << [
				signature.location.end_offset,
				body_block.opening_loc.end_offset - signature.location.end_offset,
				";#{preamble.join(';')};",
			]

			# Insert postamble
			@annotations << [
				body_block.closing_loc.start_offset,
				0,
				";#{postamble.join(';')};",
			]
		end

		# TODO: This won’t track properly if the guards are the top of the method aren’t satisfied
		original_return_type = @return_type
		@return_type = return_type
		super
		@return_type = original_return_type
	end

	def visit_return_node(node)
		case @return_type
		in nil
			# no-op
		in Prism::LocalVariableReadNode[name: :void] | Prism::CallNode[name: :void, receiver: nil, block: nil, arguments: nil]
			if node.arguments
				raise "You’re returning something"
			else
				@annotations << [
					node.keyword_loc.end_offset,
					0,
					"(::Empirical::Void)",
				]
			end
		in Prism::LocalVariableReadNode[name: :never] | Prism::CallNode[name: :never, receiver: nil, block: nil, arguments: nil]
			@annotations << [
				node.keyword_loc.start_offset,
				node.keyword_loc.end_offset - node.keyword_loc.start_offset,
				"(raise(::Empirical::NeverError.new))",
			]
		else
			@annotations.push(
				[
					node.keyword_loc.start_offset,
					node.keyword_loc.end_offset - node.keyword_loc.start_offset,
					"(__literally_returning__ = (",
				],
				[
					node.location.end_offset,
					0,
					");(raise ::Empirical::TypeError.return_type_error(value: __literally_returning__, expected: #{@return_type}, method_name: __method__, context: self) unless #{@return_type} === __literally_returning__);return(__literally_returning__))",
				]
			)
		end

		super
	end
end
