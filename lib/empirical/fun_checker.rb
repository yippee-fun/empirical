# frozen_string_literal: true

# Finds values in a fun whose type is known from the source alone and that flow into a declared
# type. The known values are literals, parameters the body never reassigns, and ivars with a prop in
# the same class. The declared types are the return type, parameter types (for defaults) and those
# props. It produces statements that check them once, when the method is defined.
class Empirical::FunChecker
	NEW_RETURN_SCOPES = Set[:lambda, :define_method, :define_singleton_method].freeze

	# parameter_types and ivar_types map names to source that evaluates to the type.
	def initialize(fun, parameter_types:, return_type:, ivar_types: {})
		@fun = fun
		@body = fun.body.body
		@parameter_types = parameter_types
		@return_type = return_type
		@ivar_types = ivar_types
		@method_name = fun.signature.name

		# Values returned from inside a block, where `self` might not be this object.
		@returned_in_block = Set[].compare_by_identity
		@block_depth = 0
	end

	#: () -> Array[String]
	def statements
		[*default_checks, *return_checks, *ivar_write_checks]
	end

	private def default_checks
		@fun.parameters.filter_map do |parameter|
			default = parameter.default
			next unless default && literal_source?(default)

			value_check(@parameter_types.fetch(parameter.name), default, parameter.default_line, "The default for `#{parameter.name}` in `#{@method_name}` is")
		end
	end

	private def return_checks
		return [] unless @return_type

		[*tails(@body), *explicit_returns(@body)].filter_map do |node|
			case node
			in nil
				value_check(@return_type, "nil", @fun.body.location.start_line, "`#{@method_name}` returns")
			in Prism::ReturnNode
				value_check(@return_type, "nil", node.location.start_line, "`#{@method_name}` returns")
			in Empirical::LiteralNode
				value_check(@return_type, node.slice, node.location.start_line, "`#{@method_name}` returns") unless node.slice.include?("\n")
			else
				type = declared_type(node, in_block: @returned_in_block.include?(node))
				type_check(@return_type, type, node, "`#{@method_name}` returns `#{node.slice}`") if type
			end
		end
	end

	# A parameter written straight to a typed ivar. Literals and other ivars written to one are
	# checked by the IvarProcessor, which sees every method in the class.
	private def ivar_write_checks
		ivar_writes(@body).filter_map do |write|
			expected = @ivar_types[write.name]
			actual = declared_type(write.value, in_block: false) unless Prism::InstanceVariableReadNode === write.value

			type_check(expected, actual, write, "`#{write.name}` is assigned `#{write.value.slice}`") if expected && actual
		end
	end

	# The declared type of an expression, when it is a parameter or an ivar that must still hold it.
	private def declared_type(node, in_block:)
		case node
		in Prism::LocalVariableReadNode[name:]
			known_parameters[name]
		in Prism::CallNode[name:] if node.variable_call?
			# Keyword parameters aren't locals in the `fun` source, so Prism parses reading one as a call.
			known_parameters[name]
		in Prism::InstanceVariableReadNode[name:] unless in_block
			@ivar_types[name]
		else
			nil
		end
	end

	private def value_check(type, source, line, description)
		Empirical::StaticCheck.value_check_source(type, source, line, description)
	end

	private def type_check(expected, actual, node, description)
		"::Empirical::StaticCheck.type(#{expected}, #{actual}, __FILE__, #{node.location.start_line}, #{description.inspect})"
	end

	private def literal_source?(source)
		Prism.parse(source).value.statements.body in [Empirical::LiteralNode]
	end

	# The expressions whose value the body evaluates to. nil stands for an empty body, which returns nil.
	# An `if` with no `else` only contributes its own branch, since the missing one may never run.
	private def tails(node)
		case node
		in nil
			[nil]
		in Prism::StatementsNode
			tails(node.body.last)
		in Prism::ParenthesesNode
			tails(node.body)
		in Prism::IfNode
			[*tails(node.statements), *(tails(node.subsequent) if node.subsequent)]
		in Prism::UnlessNode
			[*tails(node.statements), *(tails(node.else_clause) if node.else_clause)]
		in Prism::ElseNode
			tails(node.statements)
		in Prism::BeginNode
			# A `return` in an `ensure` replaces whatever the body evaluated to.
			return [] if explicit_returns(node.ensure_clause).any?

			[*tails(node.else_clause || node.statements), *(tails(node.rescue_clause) if node.rescue_clause)]
		in Prism::RescueNode
			[*tails(node.statements), *(tails(node.subsequent) if node.subsequent)]
		in Prism::ReturnNode
			[]
		else
			[node]
		end
	end

	# The value of every `return` that returns from this method, or the node itself for a bare `return`.
	private def explicit_returns(node, found = [])
		case node
		in nil | Prism::DefNode | Prism::LambdaNode | Prism::ClassNode | Prism::ModuleNode | Prism::SingletonClassNode
			# returns in here belong to something else
		in Prism::DefinedNode
			# never evaluated
		in Prism::CallNode[block: Prism::BlockNode] if defines_fun?(node)
			# a nested fun has its own returns
		in Prism::CallNode[name:, block: Prism::BlockNode] if NEW_RETURN_SCOPES.include?(name)
			explicit_returns(node.receiver, found)
			explicit_returns(node.arguments, found)
		in Prism::BlockNode
			@block_depth += 1
			node.compact_child_nodes.each { |child| explicit_returns(child, found) }
			@block_depth -= 1
		in Prism::ReturnNode
			case node.arguments&.arguments
			in nil
				found << node
			in [Prism::SplatNode] | [_, _, *]
				# returns an array
			in [value]
				found << value
				@returned_in_block << value if @block_depth > 0
			end
		else
			node.compact_child_nodes.each { |child| explicit_returns(child, found) }
		end

		found
	end

	# Writes to an ivar that run as this method, on this object: not in a block or a nested definition.
	private def ivar_writes(node, found = [])
		case node
		in nil | Prism::BlockNode | Prism::DefNode | Prism::LambdaNode | Prism::DefinedNode
			# somewhere else, or never evaluated
		in Prism::ClassNode | Prism::ModuleNode | Prism::SingletonClassNode
			# a different `self`
		in Prism::InstanceVariableWriteNode
			found << node
			ivar_writes(node.value, found)
		else
			node.compact_child_nodes.each { |child| ivar_writes(child, found) }
		end

		found
	end

	# True for `fun ... do` and for calls that wrap one, like `private fun ... do`, where Ruby gives
	# the block to the outer call.
	private def defines_fun?(node)
		loop do
			return true if node.name == :fun && node.receiver.nil?

			case node.arguments&.arguments
			in [Prism::CallNode => node]
				# keep unwrapping
			else
				return false
			end
		end
	end

	# Typed parameters that the body never assigns to or shadows, so they still hold what was passed.
	private def known_parameters
		@known_parameters ||= begin
			reassigned = Set[]
			collect_local_writes(@body, reassigned)

			@parameter_types.except(*reassigned)
		end
	end

	private def collect_local_writes(node, names)
		return unless node

		case node
		in Prism::LocalVariableReadNode
			# a read
		in { name: Symbol => name } if node.class.name.match?(/LocalVariable|Parameter|BlockLocal/)
			names << name
		else
			# not a local
		end

		node.compact_child_nodes.each { |child| collect_local_writes(child, names) }
	end
end
