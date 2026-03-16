# frozen_string_literal: true

module AuthHelpers
  def create_authenticated_user(email: "admin@test.dev", password: "password123", site_admin: false)
    org = OrganizationRecord.create!(
      name: "Test Org",
      slug: "test-org-#{SecureRandom.hex(4)}",
      trial_ends_at: nil
    )

    user = UserRecord.create!(
      email: email,
      password: password,
      site_admin: site_admin,
      verified_at: Time.current
    )

    MembershipRecord.create!(user: user, organization: org, role: "org_admin")

    [user, org]
  end

  def sign_in(user)
    post "/auth/sessions", params: {email: user.email, password: "password123"}, as: :json
  end

  def auth_headers_for(user)
    # For request specs, we need to establish a session
    # Use rack_test cookie jar approach
    post "/auth/sessions", params: {email: user.email, password: "password123"}, as: :json
    # The session cookie is automatically maintained by the test framework
    {}
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
end
