# frozen_string_literal: true

class Empirical::Processor < Empirical::BaseProcessor
	#: (Prism::ClassNode) -> void
	def visit_class_node(node)
		new_context { super }
	end

	#: (Prism::ModuleNode) -> void
	def visit_module_node(node)
		new_context { super }
	end

	#: (Prism::BlockNode) -> void
	def visit_block_node(node)
		new_context { super }
	end

	#: (Prism::SingletonClassNode) -> void
	def visit_singleton_class_node(node)
		new_context { super }
	end

	#: (Prism::IfNode) -> void
	def visit_if_node(node)
		visit(node.predicate)

		branch { visit(node.statements) }
		branch { visit(node.subsequent) }
	end

	#: (Prism::CaseNode) -> void
	def visit_case_node(node)
		visit(node.predicate)

		node.conditions.each do |condition|
			branch { visit(condition) }
		end

		branch { visit(node.else_clause) }
	end

	#: (Prism::DefinedNode) -> void
	def visit_defined_node(node)
		value = node.value

		return if Prism::InstanceVariableReadNode === value

		super
	end

	#: (Prism::InstanceVariableReadNode) -> void
	def visit_instance_variable_read_node(node)
		name = node.name

		unless @context.include?(name)
			location = node.location

			@context << name

			@annotations.push(
				[location.start_character_offset, 0, "(defined?(#{name}) ? "],
				[location.end_character_offset, 0, " : (::Kernel.raise(::Empirical::NameError.new(self, :#{name}))))"]
			)
		end

		super
	end

	#: () { () -> void } -> void
	private def new_context
		original_context = @context

		@context = Set[]

		begin
			yield
		ensure
			@context = original_context
		end
	end

	#: () { () -> void } -> void
	private def branch
		original_context = @context
		@context = original_context.dup

		begin
			yield
		ensure
			@context = original_context
		end
	end

	def visit_def_node(node)
		new_context do
			return super unless node.equal_loc
			return super unless node in {
				body: {
					body: [
						Prism::CallNode[
							block: Prism::BlockNode[
								body: Prism::StatementsNode
							] => block
						] => call
					]
				}
			}

			type_checks = build_type_checks(node)

			if node.rparen_loc
				@annotations << [
					start = node.rparen_loc.start_offset + 1,
					block.opening_loc.end_offset - start,
					";#{type_checks};__literally_returns__ = (;",
				]
			else
				@annotations << [
					start = node.equal_loc.start_offset - 1,
					block.opening_loc.end_offset - start,
					";__literally_returns__ = (;",
				]
			end

			return_type = if call.closing_loc
				node.slice[(call.start_offset)...(call.closing_loc.end_offset)]
			else
				call.name
			end
			@annotations << [
				block.closing_loc.start_offset,
				0,
				<<~CODE,
					;);(raise ::Empirical::TypeError.return_type_error(value: __literally_returns__, expected: #{return_type}, method_name: "#{node.name}", context: self) unless #{return_type} === __literally_returns__);__literally_returns__;
				CODE
			]

			@annotations << [
				start = block.closing_loc.start_offset,
				block.closing_loc.end_offset - start,
				"end",
			]
		end
	end

	private def build_type_checks(node)
		return unless node.parameters

		if (requireds = node.parameters.requireds)&.any?
			raise Empirical::TypedSignatureError.new("Typed method signatures don't allow required keyword parameters: #{requireds.inspect}")
		elsif (rest = node.parameters.rest)&.any?
			raise Empirical::TypedSignatureError.new("Typed method signatures don't allow a splat array parameter: #{rest.inspect}")
		elsif (posts = node.parameters.posts)&.any?
			raise Empirical::TypedSignatureError.new("Typed method signatures don't allow a splat hash parameter: #{posts.inspect}")
		elsif (keyword_rest = node.parameters.keyword_rest)&.any?
			raise Empirical::TypedSignatureError.new("Typed method signatures don't allow a splat hash parameter: #{keyword_rest.inspect}")
		end

		parameters_assertions = []

		if (optionals = node.parameters.optionals)&.any?
			optionals.each do |optional|
				case optional
				# typed splats, e.g.
				# `(names = [String])` => `(*names); assert(names: _Array(String))` and
				# `(position = [*Position])` => `(*position); assert(position: Position)`
				in { value: Prism::ArrayNode[elements: [type_node]] => value }
					if type_node in Prism::SplatNode
						type = type_node.expression.slice
					else
						type = "::Literal::_Array(#{type_node.slice})"
					end

					# Make the parameter a splat
					@annotations << [optional.name_loc.start_offset, 0, "*"]

					# Remove the type signature (the default value)
					@annotations << [optional.operator_loc.start_offset, value.closing_loc.end_offset - optional.operator_loc.start_offset, ""]
					parameters_assertions << [optional.name, type]
					next
				# With default
				in {
					value: Prism::CallNode[
						block: Prism::BlockNode[
							body: Prism::StatementsNode => default_node
						]
					] => call
				}
					default = "(#{default_node.slice})"

					type = if call.closing_loc
						node.slice[(call.start_offset)...(call.closing_loc.end_offset)]
					else
						call.name
					end
				# No default
				else
					default = "nil"
					type = optional.value.slice
				end

				value_location = optional.value.location
				@annotations << [value_location.start_offset, value_location.end_offset - value_location.start_offset, default]
				parameters_assertions << [optional.name, type]
			end
		end

		if (keywords = node.parameters.keywords)&.any?
			keywords.each do |keyword|
				case keyword
				# Splat
				in { value: Prism::HashNode[elements: [Prism::AssocNode[key: key_type_node, value: val_type_node]]] => value }
					type = "::Literal::_Hash(#{key_type_node.slice}, #{val_type_node.slice})"

					# Make the parameter a splat
					@annotations << [keyword.name_loc.start_offset, 0, "**"]

					# Remove the type signature (the default value) and the colon at the end of the keyword
					@annotations << [keyword.name_loc.end_offset - 1, value.closing_loc.end_offset - keyword.name_loc.end_offset + 1, ""]
					next "#{keyword.name}: #{type}"
				in { value: Prism::HashNode[elements: [Prism::AssocSplatNode[value: val_type_node]]] => value }
					type = val_type_node.slice

					# Make the parameter a splat
					@annotations << [keyword.name_loc.start_offset, 0, "**"]

					# Remove the type signature (the default value) and the colon at the end of the keyword
					@annotations << [keyword.name_loc.end_offset - 1, value.closing_loc.end_offset - keyword.name_loc.end_offset + 1, ""]
					parameters_assertions << [keyword.name, type]
					next
				# With default
				in {
					value: Prism::CallNode[
						block: Prism::BlockNode[
							body: Prism::StatementsNode => default_node
						]
					] => call
				}
					default = "(#{default_node.slice})"

					type = if call.closing_loc
						node.slice[(call.start_offset)...(call.closing_loc.end_offset)]
					else
						call.name
					end
				# No default
				else
					default = "nil"
					type = keyword.value.slice
				end

				value_location = keyword.value.location
				@annotations << [value_location.start_offset, value_location.end_offset - value_location.start_offset, default]
				parameters_assertions << [keyword.name, type]
			end
		end

		parameters_assertions.map do |value, type|
			<<~CODE
				(raise ::Empirical::TypeError.argument_type_error(name: "#{value}", value: #{value}, expected: #{type}, method_name: "#{node.name}", context: self) unless #{type} === #{value})
			CODE
		end.join(";")
	end
end
