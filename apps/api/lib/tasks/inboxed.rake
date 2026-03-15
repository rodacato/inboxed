# frozen_string_literal: true

namespace :inboxed do
  desc "Create a default project and API key for development"
  task setup: :environment do
    project = ProjectRecord.find_or_create_by!(slug: "default") do |p|
      p.id = SecureRandom.uuid
      p.name = "Default Project"
    end

    existing = ApiKeyRecord.find_by(project: project, label: "dev")
    if existing
      puts "Project: #{project.name} (#{project.slug})"
      puts "API key already exists (label: dev). Token was shown on first creation only."
      puts ""
      puts "To create a new key, run: rails inboxed:new_key"
    else
      token = SecureRandom.hex(32)
      ApiKeyRecord.create!(
        id: SecureRandom.uuid,
        project: project,
        label: "dev",
        token_prefix: token[0, 8],
        token_digest: BCrypt::Password.create(token)
      )

      puts "Project: #{project.name} (#{project.slug})"
      puts "API Key: #{token}"
      puts ""
      puts "SMTP config for your app:"
      puts "  SMTP_HOST=localhost"
      puts "  SMTP_PORT=2525"
      puts "  SMTP_USER=#{token}"
      puts "  SMTP_PASS=#{token}"
    end
  end

  desc "Generate a new API key for the default project"
  task new_key: :environment do
    project = ProjectRecord.find_by!(slug: "default")
    token = SecureRandom.hex(32)
    label = ENV.fetch("LABEL", "key-#{ApiKeyRecord.where(project: project).count + 1}")

    ApiKeyRecord.create!(
      id: SecureRandom.uuid,
      project: project,
      label: label,
      token_prefix: token[0, 8],
      token_digest: BCrypt::Password.create(token)
    )

    puts "API Key: #{token}"
    puts "Label: #{label}"
    puts "Project: #{project.name}"
  end
end
