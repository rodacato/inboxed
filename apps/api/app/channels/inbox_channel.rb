# frozen_string_literal: true

class InboxChannel < ApplicationCable::Channel
  def subscribed
    stream_from "inbox_#{params[:inbox_id]}"
  end
end
