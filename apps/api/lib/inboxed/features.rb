# frozen_string_literal: true

module Inboxed
  class Features
    def self.all
      {
        mail: true,
        hooks: ENV.fetch("INBOXED_FEATURE_HOOKS", "true") == "true",
        forms: ENV.fetch("INBOXED_FEATURE_FORMS", "true") == "true",
        heartbeats: ENV.fetch("INBOXED_FEATURE_HEARTBEATS", "true") == "true",
        mcp: true,
        html_preview: true
      }
    end

    def self.enabled?(feature)
      all.fetch(feature.to_sym, false)
    end
  end
end
