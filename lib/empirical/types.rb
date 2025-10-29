# frozen_string_literal: true

module Empirical
	class PositionalParamsType
		def initialize(types: [], rest: nil)
			@types = types
			@rest = rest
		end

		def ===(value)
			return false unless Array === value

			init = value.take(@types.size)

			return false unless _Tuple(*@types) === init

			rest = value.drop(@types.size)

			if @rest
				return false unless @rest === rest
			else
				return false if rest.any?
			end

			true
		end
	end

	class KeywordParamsType
		def initialize(types: {}, rest: nil)
			@types = types
			@rest = rest
		end

		def ===(value)
			return false unless Hash === value

			init = value.take(@types.size).to_h

			return false unless _Map(**@types) === init

			rest = value.drop(@types.size).to_h

			if @rest
				return false unless @rest === rest
			else
				return false if rest.any?
			end

			true
		end
	end
end
