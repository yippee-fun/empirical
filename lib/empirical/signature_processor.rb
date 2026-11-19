# frozen_string_literal: true

class Empirical::SignatureProcessor < Empirical::BaseProcessor
	METHOD_DEFINING_BLOCKS = Set[:lambda, :define_method, :define_singleton_method].freeze

	def initialize(...)
		super
		@parser = Empirical::FunParser.new(path: @path)

		# What a `return` returns from, innermost last. nil when it isn’t the body of a `fun`.
		@return_scopes = [nil]
		@scope_for_block = {}.compare_by_identity
		@compiled = Set[].compare_by_identity
		@ivar_types = {}
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

	# The ivars declared in the class a fun is written in have a known type. They are looked up by
	# name when the fun is defined, since a declaration below it in the class won’t have been stored yet.
	def visit_class_node(node)
		ivar_types = declarations_in(node.body).to_h do |ivar, _type, ident|
			[ivar, "::Empirical::TypeStore.lookup(:#{ident})"]
		end

		with_ivar_types(ivar_types) { super }
	end

	def visit_module_node(node)
		with_ivar_types({}) { super }
	end

	def visit_singleton_class_node(node)
		with_ivar_types({}) { super }
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
		in { kind: :typed | :itself, return_local:, return_check: }
			check = ";(#{return_check});#{return_local})"

			case arguments
			in nil
				@annotations << [keyword_end, 0, " (#{return_local} = nil#{check}"]
			in [Prism::SplatNode] | [_, _, *]
				wrap(keyword_end, node.location.end_offset, " (#{return_local} = [", "]#{check}")
			in [_]
				wrap(keyword_end, node.location.end_offset, " (#{return_local} = (", ")#{check}")
			end
		end

		super
	end

	private def compile(call, body:, wrappers:)
		fun = @parser.parse(call, body:, wrappers:)
		ivar_types = instance_method_fun?(call) ? @ivar_types : {}
		generator = Empirical::FunGenerator.new(fun, source: @source, site:, ivar_types:).call

		@annotations.concat(generator.annotations)
		@compiled << call
		@scope_for_block[fun.body] = {
			kind: fun.return_type.kind,
			return_local: generator.return_local,
			return_check: generator.return_check,
		}
	end

	private def with_ivar_types(ivar_types)
		original = @ivar_types
		@ivar_types = ivar_types
		yield
	ensure
		@ivar_types = original
	end

	private def with_return_scope(scope)
		@return_scopes << scope
		yield
	ensure
		@return_scopes.pop
	end
end
