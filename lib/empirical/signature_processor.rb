# frozen_string_literal: true

class Empirical::SignatureProcessor < Empirical::BaseProcessor
	def initialize(...)
		@return_type = nil
		@block_stack = []
		super
	end

	def visit_call_node(node)
		case node
		in { name: :fun }
			original_return_type = @return_type
			@return_type = visit_fun_call_node(node)
			super # ensures any early returns are processed (also, technically, any internal method defs)
			@return_type = original_return_type

		# handle "method macros" (like `private`, `protected`, etc.)
		# because the body block is attached to that call node,
		# not the `fun` call node
		in { block: Prism::BlockNode }
			@block_stack << node.block
			super
			@block_stack.pop
		else
			original_return_type = @return_type
			super # ensures any early returns are processed (also, technically, any internal method defs)
			@return_type = original_return_type
		end
	end

	def visit_fun_call_node(node)
		# TODO: better error messages
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
			]
		}
			body_block = node.block || @block_stack.first
			preamble = []
			postamble = []

			case signature
			# parameterless method defs (e.g. `fun foo` or `fun foo()`)
			in Prism::LocalVariableReadNode | Prism::ConstantReadNode
			# no-op
			# parameterful method defs (e.g. `fun foo(a: Type)` or `fun foo(a = Type)`)
			in Prism::CallNode
				raise SyntaxError if signature.block

				signature.arguments&.arguments&.each do |argument|
					case argument
					# Positional splat (e.g. `a = [Type]` becomes `*a`)
					in Prism::LocalVariableWriteNode[name: name, value: Prism::ArrayNode[elements: [type]]]
						# make argument a splat
						@annotations << [
							argument.name_loc.start_offset,
							0,
							"*",
						]

						# remove the type and equals operator from the argument
						@annotations << [
							argument.name_loc.end_offset,
							type.location.end_offset - argument.name_loc.end_offset + 1,
							"",
						]

						preamble << "raise(::Empirical::TypeError.argument_type_error(name: '#{name}', value: #{name}, expected: ::Literal::_Array(#{type.slice}), method_name: __method__, context: self)) unless ::Literal::_Array(#{type.slice}) === #{name}"

					# Positional (e.g. `a = Type` becomes `a = nil` or `a = default`)
					in Prism::LocalVariableWriteNode[name: name, value: typed_param]
						case typed_param
						# Positional with default (e.g. `a = Type | 1` becomes `a = 1`)
						in Prism::CallNode[name: :|, receiver: type, arguments: Prism::ArgumentsNode[arguments: [default]]]
							type_slice = type.slice
							default_string = default.slice
						# Positional without default (e.g. `a = Type` becomes `a = nil`)
						else
							type_slice = typed_param.slice
							default_string = "nil"
						end

						# replace the typed_param from the argument with the appropriate default value
						@annotations << [
							(start = typed_param.location.start_offset),
							typed_param.location.end_offset - start,
							default_string,
						]

						preamble << "raise(::Empirical::TypeError.argument_type_error(name: '#{name}', value: #{name}, expected: #{type_slice}, method_name: __method__, context: self)) unless #{type_slice} === #{name}"

					# Keyword (e.g. `a: Type` becomes `a: nil` or `a: default`)
					in Prism::KeywordHashNode
						argument.elements.each do |argument|
							name = argument.key.unescaped

							nilable = false

							if name.end_with?("?")
								name = name[0..-2]
								nilable = true

								@annotations << [
									argument.key.location.end_offset - 2,
									1,
									"",
								]
							end

							typed_param = argument.value

							case typed_param
							# Keyword splat (e.g. `a: {Type => Type}` becomes `**a`)
							in Prism::HashNode[elements: [Prism::AssocNode[key: key_type, value: value_type]]]
								# make argument a splat
								@annotations << [
									argument.key.location.start_offset,
									0,
									"**",
								]

								# remove the typed_param and equals operator from the argument
								@annotations << [
									argument.key.location.end_offset - 1,
									typed_param.location.end_offset - argument.key.location.end_offset + 1,
									"",
								]

								preamble << "raise(::Empirical::TypeError.argument_type_error(name: '#{name}', value: #{name}, expected: ::Literal::_Hash(#{key_type.slice}, #{value_type.slice}), method_name: __method__, context: self)) unless ::Literal::_Hash(#{key_type.slice}, #{value_type.slice}) === #{name}"
							else
								case typed_param
								# Keyword with default
								in Prism::CallNode[name: :|, receiver: type, arguments: Prism::ArgumentsNode[arguments: [default]]]
									type_slice = if nilable
										"::Literal::_Nilable(#{type.slice})"
									else
										type.slice
									end

									default_string = default.slice
								else
									type_slice = if nilable
										"::Literal::_Nilable(#{typed_param.slice})"
									else
										typed_param.slice
									end

									default_string = "nil"
								end

								# replace the typed_param from the argument with the appropriate default value
								@annotations << [
									(start = typed_param.location.start_offset),
									typed_param.location.end_offset - start,
									default_string,
								]

								preamble << "raise(::Empirical::TypeError.argument_type_error(name: '#{name}', value: #{name}, expected: #{type_slice}, method_name: __method__, context: self)) unless #{type_slice} === #{name}"
							end
						end
					else
						# TODO: better error message
						raise SyntaxError
					end
				end
			else
				# TODO: better error message
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
				(start = node.message_loc.start_offset),
				node.message_loc.end_offset - start,
				"def",
			]

			# Remove the return type and `do` and replace with preamble
			@annotations << [
				(start = signature.location.end_offset),
				body_block.opening_loc.end_offset - start,
				";#{preamble.join(';')};",
			]

			# Insert postamble
			@annotations << [
				body_block.closing_loc.start_offset,
				0,
				";#{postamble.join(';')};",
			]
		else
			# TODO: better error message
			raise SyntaxError
		end

		return_type
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
