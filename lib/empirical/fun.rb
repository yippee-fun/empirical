# frozen_string_literal: true

module Empirical
	# A parsed `fun` definition. Built by FunParser, turned into source edits by FunGenerator.
	Fun = Data.define(:call, :signature, :body, :parameters, :return_type)

	# kind is one of:
	#   :positional        `a = Type`
	#   :positional_splat  `a = [Type]`
	#   :keyword           `a: Type` or `a?: Type`
	#   :keyword_splat     `a: {KeyType => ValueType}`
	#   :untyped           `*args`, `**kwargs`, `&block` or `...`, which are already valid in a `def`
	#
	# type is the node the type was written as. type_source and default are single-line Ruby source.
	Fun::Parameter = Data.define(:kind, :name, :node, :type, :type_source, :default, :optional)

	# kind is :void, :never, :itself or :typed
	Fun::ReturnType = Data.define(:kind, :node, :source)
end
