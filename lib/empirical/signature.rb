# frozen_string_literal: true

class Empirical::Signature < Literal::Data
	prop :method, UnboundMethod
	prop :positional_params_type, Empirical::PositionalParamsType
	prop :keyword_params_type, Empirical::KeywordParamsType
end
