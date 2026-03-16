# frozen_string_literal: true

class ChangeAllowedMethodsDefault < ActiveRecord::Migration[8.1]
  def change
    change_column_default :http_endpoints, :allowed_methods,
      from: ["POST"],
      to: %w[GET POST PUT PATCH DELETE HEAD OPTIONS]
  end
end
