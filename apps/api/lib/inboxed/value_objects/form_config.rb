# frozen_string_literal: true

module Inboxed
  module ValueObjects
    class FormConfig < Dry::Struct
      attribute :response_mode, Types::String.enum("json", "redirect", "html")
      attribute :redirect_url, Types::String.optional.default(nil)
      attribute :response_html, Types::String.optional.default(nil)
    end
  end
end
