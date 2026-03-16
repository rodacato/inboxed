# frozen_string_literal: true

class InvitationMailer < ApplicationMailer
  default from: -> { ENV.fetch("OUTBOUND_FROM_EMAIL", "noreply@inboxed.dev") }

  def invite(invitation)
    @invitation = invitation
    @org = invitation.organization
    @url = "#{base_url}/invitation?token=#{invitation.token}"
    mail(to: invitation.email, subject: "You're invited to #{@org.name} on Inboxed")
  end

  private

  def base_url
    ENV.fetch("INBOXED_BASE_URL", "http://localhost:5179")
  end
end
