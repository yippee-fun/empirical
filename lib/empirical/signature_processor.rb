# frozen_string_literal: true

class Empirical::SignatureProcessor < Empirical::BaseProcessor
	RETURN_LOCAL = Empirical::FunGenerator::RETURN_LOCAL
	METHOD_DEFINING_BLOCKS = Set[:lambda, :define_method, :define_singleton_method].freeze

	def initialize(...)
		super
		@parser = Empirical::FunParser.new(path: @path)

		# What a `return` returns from, innermost last. nil when it isn’t the body of a `fun`.
		@return_scopes = [nil]
		@scope_for_block = {}.compare_by_identity
		@compiled = Set[].compare_by_identity
	end

	def visit_call_node(node)
		body = node.block if Prism::BlockNode === node.block

		unless @compiled.include?(node)
			if fun?(node)
				compile(node, body:, wrappers: [])
			elsif body && (wrapped = wrapped_fun(node))
				fun, wrappers = wrapped
				compile(fun, body:, wrappers:)
			end
		end

		@scope_for_block[body] = nil if body && METHOD_DEFINING_BLOCKS.include?(node.name)

		super
	end

	def visit_block_node(node)
		if @scope_for_block.key?(node)
			with_return_scope(@scope_for_block[node]) { super }
		else
			super
		end
	end

	def visit_def_node(node)
		with_return_scope(nil) { super }
	end

	def visit_lambda_node(node)
		with_return_scope(nil) { super }
	end

	def visit_return_node(node)
		keyword_end = node.keyword_loc.end_offset
		arguments = node.arguments&.arguments

		case @return_scopes.last
		in nil
			# not in a `fun`
		in { kind: :void }
			@parser.fail!(node, "A `void` method can’t return a value.") if arguments
			@annotations << [keyword_end, 0, "(::Empirical::Void)"]
		in { kind: :never }
			if arguments
				wrap(keyword_end, node.location.end_offset, " (::Kernel.raise(::Empirical::NeverError.new);(", "))")
			else
				@annotations << [keyword_end, 0, " ::Kernel.raise(::Empirical::NeverError.new)"]
			end
		in { kind: :typed, return_check: }
			check = ";(#{return_check});#{RETURN_LOCAL})"

			case arguments
			in nil
				@annotations << [keyword_end, 0, " (#{RETURN_LOCAL} = nil#{check}"]
			in [Prism::SplatNode] | [_, _, *]
				wrap(keyword_end, node.location.end_offset, " (#{RETURN_LOCAL} = [", "]#{check}")
			in [_]
				wrap(keyword_end, node.location.end_offset, " (#{RETURN_LOCAL} = (", ")#{check}")
			end
		end

		super
	end

	private def fun?(node)
		node.name == :fun && node.receiver.nil? && (node.arguments || node.block)
	end

	# In `private fun foo => Type do ... end`, Ruby attaches the block to `private`, not to `fun`.
	private def wrapped_fun(outer)
		wrappers = [outer]
		current = outer

		loop do
			case current.arguments&.arguments
			in [Prism::CallNode => current]
				return [current, wrappers] if fun?(current)
				return if current.block
				wrappers << current
			else
				return
			end
		end
	end

	private def compile(call, body:, wrappers:)
		fun = @parser.parse(call, body:, wrappers:)
		generator = Empirical::FunGenerator.new(fun, source: @source, site:).call

		@annotations.concat(generator.annotations)
		@compiled << call
		@scope_for_block[fun.body] = { kind: fun.return_type.kind, return_check: generator.return_check }
	end

	private def with_return_scope(scope)
		@return_scopes << scope
		yield
	ensure
		@return_scopes.pop
	end
end
