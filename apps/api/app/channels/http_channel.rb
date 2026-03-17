# frozen_string_literal: true

class HttpChannel < ApplicationCable::Channel
  def subscribed
    stream_from "project_#{params[:project_id]}_http"
  end
end
