# frozen_string_literal: true

class AddOrganizationIdToProjects < ActiveRecord::Migration[8.1]
  def change
    add_reference :projects, :organization, type: :uuid, foreign_key: {on_delete: :cascade}
    add_index :projects, :organization_id, name: "idx_projects_organization"
  end
end
