# frozen_string_literal: true

# Wire domain events to ActionCable broadcasts for real-time dashboard updates.
# See ADR-011 for architecture details.

Rails.application.config.after_initialize do
  Inboxed::EventStore::Bus.subscribe(Inboxed::Events::EmailReceived) do |event|
    email = EmailRecord.find_by(id: event.data[:email_id])
    next unless email

    payload = EmailListSerializer.render(email)

    ActionCable.server.broadcast("inbox_#{event.data[:inbox_id]}", {
      type: "email_received",
      email: payload
    })

    ActionCable.server.broadcast("project_#{email.inbox.project_id}", {
      type: "inbox_updated",
      inbox_id: event.data[:inbox_id],
      email_count_delta: 1
    })
  end

  Inboxed::EventStore::Bus.subscribe(Inboxed::Events::EmailDeleted) do |event|
    ActionCable.server.broadcast("inbox_#{event.data[:inbox_id]}", {
      type: "email_deleted",
      email_id: event.data[:email_id]
    })
  end

  Inboxed::EventStore::Bus.subscribe(Inboxed::Events::InboxPurged) do |event|
    ActionCable.server.broadcast("inbox_#{event.data[:inbox_id]}", {
      type: "inbox_purged",
      deleted_count: event.data[:deleted_count]
    })
  end

  # Webhook dispatch for all supported events
  [
    Inboxed::Events::EmailReceived,
    Inboxed::Events::EmailDeleted,
    Inboxed::Events::InboxCreated,
    Inboxed::Events::InboxPurged
  ].each do |event_class|
    Inboxed::EventStore::Bus.subscribe(event_class) do |event|
      Inboxed::Services::DispatchWebhooks.new.call(event: event)
    end
  end

  Inboxed::EventStore::Bus.subscribe(Inboxed::Events::InboxCreated) do |event|
    inbox = InboxRecord.find_by(id: event.data[:inbox_id])
    next unless inbox

    ActionCable.server.broadcast("project_#{inbox.project_id}", {
      type: "inbox_created",
      inbox: {id: inbox.id, address: inbox.address, email_count: 0,
              created_at: inbox.created_at.iso8601}
    })
  end
end
