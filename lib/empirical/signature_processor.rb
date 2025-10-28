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
			@block_stack << node
			visit node.receiver
			visit node.arguments
			@block_stack.pop
			visit node.block
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

		method_name = nil

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
			method_name = signature.name
			body_block = node.block || @block_stack.first.block
			post_def_buffer = []
			pre_end_buffer = []
			post_end_buffer = []
			positional_splat_type_buffer = []
			positional_params_type_buffer = []
			keyword_params_type_buffer = []
			keyword_splat_type_buffer = []

			overloading = @block_stack.any? { it.name == :overload }

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

						param_type_slice = "::Literal::_Array(#{type.slice})"
						param_type_ident = unique_type_ident(param_type_slice)

						positional_splat_type_buffer << param_type_ident
						post_end_buffer << store_type(param_type_slice, as: param_type_ident)
						post_def_buffer << argument_type_check(name:, type: param_type_ident)

					# Positional (e.g. `a = Type` becomes `a = nil` or `a = default`)
					in Prism::LocalVariableWriteNode[name: name, value: typed_param]
						param_type_slice = typed_param.slice
						default_string = "nil"

						# replace the typed_param from the argument with the appropriate default value
						@annotations << [
							(start = typed_param.location.start_offset),
							typed_param.location.end_offset - start,
							default_string,
						]

						param_type_ident = unique_type_ident(param_type_slice)

						positional_params_type_buffer << "::Empirical::TypeStore::#{param_type_ident}"
						post_end_buffer << store_type(param_type_slice, as: param_type_ident)
						post_def_buffer << argument_type_check(name:, type: param_type_ident)

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

								param_type_slice = "::Literal::_Hash(#{key_type.slice}, #{value_type.slice})"
								param_type_ident = unique_type_ident(param_type_slice)

								keyword_splat_type_buffer << "#{name}: ::Empirical::TypeStore::#{param_type_ident}"
								post_end_buffer << store_type(param_type_slice, as: param_type_ident)
								post_def_buffer << argument_type_check(name:, type: param_type_ident)
							else

								param_type_slice = if nilable
									"::Literal::_Nilable(#{typed_param.slice})"
								else
									typed_param.slice
								end

								default_string = "nil"

								# replace the typed_param from the argument with the appropriate default value
								@annotations << [
									(start = typed_param.location.start_offset),
									typed_param.location.end_offset - start,
									default_string,
								]

								param_type_ident = unique_type_ident(param_type_slice)

								keyword_params_type_buffer << "#{name}: ::Empirical::TypeStore::#{param_type_ident}"
								post_end_buffer << store_type(param_type_slice, as: param_type_ident)
								post_def_buffer << argument_type_check(name:, type: param_type_ident)
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

			post_def_buffer << "__literally_returns__ = ("
			pre_end_buffer << ")"

			if overloading
				post_end_buffer << "((::Empirical::OVERLOADED_METHODS[self] ||= {})[:#{method_name}] ||= []) << ::Empirical::Signature.new(method: instance_method(:#{method_name}), positional_params_type: ::Empirical::PositionalParamsType.new(types: [#{positional_params_type_buffer.join(', ')}], rest: #{positional_splat_type_buffer.first || 'nil'}), keyword_params_type: ::Empirical::KeywordParamsType.new(types: {#{keyword_params_type_buffer.join(', ')}}, rest: #{keyword_splat_type_buffer.first || 'nil'}))"
				post_end_buffer << "::Empirical.generate_root_overloaded_method(self, :#{method_name})"
			end

			case return_type
			in Prism::LocalVariableReadNode[name: :void] | Prism::CallNode[name: :void, receiver: nil, block: nil, arguments: nil]
				pre_end_buffer << "::Empirical::Void"
			in Prism::LocalVariableReadNode[name: :never] | Prism::CallNode[name: :never, receiver: nil, block: nil, arguments: nil]
				pre_end_buffer << "raise(::Empirical::NeverError.new)"
			else
				return_type_slice = return_type.slice
				return_type_ident = unique_type_ident(return_type_slice)

				post_end_buffer << "::Empirical::TypeStore::#{return_type_ident} = #{return_type_slice}"

				pre_end_buffer << "raise(::Empirical::TypeError.return_type_error(value: __literally_returns__, expected: ::Empirical::TypeStore::#{return_type_ident}, method_name: __method__, context: self)) unless ::Empirical::TypeStore::#{return_type_ident} === __literally_returns__"
				pre_end_buffer << "__literally_returns__"
			end

			# Replace `fun` with `def`
			@annotations << [
				(start = node.message_loc.start_offset),
				node.message_loc.end_offset - start,
				"def",
			]

			# Remove the return type and `do` and replace with post_def_buffer
			@annotations << [
				(start = signature.location.end_offset),
				body_block.opening_loc.end_offset - start,
				";#{post_def_buffer.join(';')};",
			]

			# Insert pre_end_buffer
			@annotations << [
				body_block.closing_loc.start_offset,
				0,
				";#{pre_end_buffer.join(';')};",
			]

			# Insert post_end_buffer
			if post_end_buffer.any?
				@annotations << [
					body_block.closing_loc.end_offset,
					0,
					";#{post_end_buffer.join(';')};",
				]
			end
		else
			# TODO: better error message
			raise SyntaxError
		end

		return_type
	end

	private def argument_type_check(name:, type:)
		"raise(::Empirical::TypeError.argument_type_error(name: '#{name}', value: #{name}, expected: ::Empirical::TypeStore::#{type}, method_name: __method__, context: self)) unless ::Empirical::TypeStore::#{type} === #{name}"
	end

	# Takes a type as a string and converts it into a unique constant identifier
	private def unique_type_ident(type)
		"T__#{type.tr('()', '_').gsub(/[^a-zA-Z0-9_]/, '')}__#{SecureRandom.alphanumeric(32)}"
	end

	private def store_type(type, as:)
		"::Empirical::TypeStore::#{as} = #{type}"
	end

	# Takes a signature as a string and converts it into a unique method identifier
	private def unique_method_ident(signature)
		"#{signature.tr('()', '_').gsub(/[^a-zA-Z0-9_]/, '')}__#{SecureRandom.alphanumeric(32)}"
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
					");(raise ::Empirical::TypeError.return_type_error(value: __literally_returning__, expected: #{@return_type.slice}, method_name: __method__, context: self) unless #{@return_type.slice} === __literally_returning__);return(__literally_returning__))",
				]
			)
		end

		super
	end
end
