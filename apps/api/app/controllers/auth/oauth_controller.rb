# frozen_string_literal: true

module Auth
  class OauthController < ApplicationController
    def github
      redirect_to github_authorize_url, allow_other_host: true
    end

    def github_callback
      github_user = exchange_code_for_user(params[:code])
      return redirect_to "/login?error=github_failed", allow_other_host: true unless github_user

      user = find_or_create_github_user(github_user)
      session[:user_id] = user.id
      user.update!(last_sign_in_at: Time.current, sign_in_count: user.sign_in_count + 1)

      redirect_to "/projects", allow_other_host: true
    end

    private

    def github_authorize_url
      client_id = ENV.fetch("GITHUB_CLIENT_ID")
      redirect_uri = "#{ENV.fetch("INBOXED_BASE_URL")}/auth/github/callback"
      "https://github.com/login/oauth/authorize?client_id=#{client_id}&redirect_uri=#{CGI.escape(redirect_uri)}&scope=user:email"
    end

    def exchange_code_for_user(code)
      return nil unless code.present?

      uri = URI("https://github.com/login/oauth/access_token")
      response = Net::HTTP.post_form(uri, {
        client_id: ENV.fetch("GITHUB_CLIENT_ID"),
        client_secret: ENV.fetch("GITHUB_CLIENT_SECRET"),
        code: code
      })

      token_params = URI.decode_www_form(response.body).to_h
      access_token = token_params["access_token"]
      return nil unless access_token

      user_uri = URI("https://api.github.com/user")
      user_request = Net::HTTP::Get.new(user_uri)
      user_request["Authorization"] = "Bearer #{access_token}"
      user_request["Accept"] = "application/json"
      user_response = Net::HTTP.start(user_uri.hostname, user_uri.port, use_ssl: true) { |http| http.request(user_request) }
      return nil unless user_response.is_a?(Net::HTTPSuccess)

      JSON.parse(user_response.body, symbolize_names: true)
    rescue => e
      Rails.logger.error("GitHub OAuth error: #{e.message}")
      nil
    end

    def find_or_create_github_user(gh)
      user = UserRecord.find_by(github_uid: gh[:id].to_s)
      return user if user

      user = UserRecord.find_by(email: gh[:email])
      if user
        user.update!(github_uid: gh[:id].to_s, github_username: gh[:login])
        return user
      end

      user = UserRecord.create!(
        email: gh[:email],
        password: SecureRandom.hex(32),
        github_uid: gh[:id].to_s,
        github_username: gh[:login],
        verified_at: Time.current
      )

      # Create org for GitHub user
      trial_days = ENV.fetch("TRIAL_DURATION_DAYS", "7").to_i
      org = OrganizationRecord.create!(
        name: "#{gh[:login]}'s workspace",
        slug: SecureRandom.uuid.split("-").first,
        trial_ends_at: (trial_days > 0) ? trial_days.days.from_now : nil
      )

      MembershipRecord.create!(user: user, organization: org, role: "org_admin")

      project = ProjectRecord.create!(
        name: "My Project",
        slug: SecureRandom.uuid.split("-").first,
        organization: org,
        default_ttl_hours: 24
      )

      Inboxed::Services::IssueApiKey.new.call(project_id: project.id, label: "Default key")

      user
    end
  end
end
