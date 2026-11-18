# frozen_string_literal: true

# Finds values in a fun whose type is known from the source alone and that flow into one of its
# declared types: literal defaults, and literals or untouched parameters that are returned. It
# produces statements that check them once, when the method is defined.
class Empirical::FunChecker
	NEW_RETURN_SCOPES = Set[:lambda, :define_method, :define_singleton_method].freeze

	def initialize(fun, parameter_types:, return_type:)
		@fun = fun
		@parameter_types = parameter_types
		@return_type = return_type
		@method_name = fun.signature.name
	end

	#: () -> Array[String]
	def statements
		[*default_checks, *return_checks]
	end

	private def default_checks
		@fun.parameters.filter_map do |parameter|
			default = parameter.default
			next unless default && literal_source?(default)

			value_check(@parameter_types.fetch(parameter.name), default, parameter.node, "The default for `#{parameter.name}` in `#{@method_name}` is")
		end
	end

	private def return_checks
		return [] unless @return_type

		body = @fun.body.body
		known = known_parameters(body)

		[*tails(body), *explicit_returns(body)].filter_map do |node|
			case node
			in nil
				value_check(@return_type, "nil", @fun.body, "`#{@method_name}` returns")
			in Prism::ReturnNode
				value_check(@return_type, "nil", node, "`#{@method_name}` returns")
			in Empirical::LiteralNode
				value_check(@return_type, node.slice, node, "`#{@method_name}` returns") unless node.slice.include?("\n")
			in Prism::LocalVariableReadNode[name:] if known.key?(name)
				"::Empirical::StaticCheck.type(#{@return_type}, #{known[name]}, __FILE__, #{node.location.start_line}, #{"`#{@method_name}` returns `#{name}`".inspect})"
			else
				nil
			end
		end
	end

	private def value_check(type, source, node, description)
		"::Empirical::StaticCheck.value(#{type}, (#{source}), __FILE__, #{node.location.start_line}, #{description.inspect})"
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
		in Prism::CallNode[name:, block: Prism::BlockNode] if NEW_RETURN_SCOPES.include?(name)
			explicit_returns(node.receiver, found)
			explicit_returns(node.arguments, found)
		in Prism::ReturnNode
			case node.arguments&.arguments
			in nil
				found << node
			in [Prism::SplatNode] | [_, _, *]
				# returns an array
			in [value]
				found << value
			end
		else
			node.compact_child_nodes.each { |child| explicit_returns(child, found) }
		end

		found
	end

	# Typed parameters that the body never assigns to or shadows, so they still hold what was passed.
	private def known_parameters(body)
		reassigned = Set[]
		collect_local_writes(body, reassigned)

		@parameter_types.except(*reassigned)
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
