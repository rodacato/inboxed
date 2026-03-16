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

      fetch_github_profile(access_token)
    rescue => e
      Rails.logger.error("GitHub OAuth error: #{e.message}")
      nil
    end

    def fetch_github_profile(access_token)
      uri = URI("https://api.github.com/user")
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{access_token}"
      request["Accept"] = "application/json"
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
      return nil unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body, symbolize_names: true)
    end

    def find_or_create_github_user(gh)
      user = UserRecord.find_by(github_uid: gh[:id].to_s)
      return user if user

      user = UserRecord.find_by(email: gh[:email])
      if user
        user.update!(github_uid: gh[:id].to_s, github_username: gh[:login])
        return user
      end

      create_new_github_user(gh)
    end

    def create_new_github_user(gh)
      user = UserRecord.create!(
        email: gh[:email],
        password: SecureRandom.hex(32),
        github_uid: gh[:id].to_s,
        github_username: gh[:login],
        verified_at: Time.current
      )

      Inboxed::Services::CreateOrganizationWithDefaults.new.call(
        name: "#{gh[:login]}'s workspace",
        user: user
      )

      user
    end
  end
end
