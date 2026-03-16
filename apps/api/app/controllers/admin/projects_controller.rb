# frozen_string_literal: true

module Admin
  class ProjectsController < BaseController
    include TrialEnforced

    def index
      projects = Inboxed::CurrentTenant.scope_projects(ProjectRecord)
        .order(created_at: :desc)
        .limit(pagination_limit)

      render json: {
        projects: projects.map { |p| serialize_project(p) }
      }
    end

    def show
      project = Inboxed::CurrentTenant.scope_projects(ProjectRecord).find(params[:id])
      render json: {project: serialize_project(project)}
    end

    def create
      project_params = params.require(:project).permit(:name, :slug, :default_ttl_hours, :max_inbox_count)

      id = Inboxed::Services::CreateProject.new.call(
        name: project_params[:name],
        slug: project_params[:slug],
        default_ttl_hours: project_params[:default_ttl_hours]&.to_i,
        max_inbox_count: project_params.fetch(:max_inbox_count, 100).to_i,
        organization_id: current_user.organization&.id
      )

      project = ProjectRecord.find(id)
      render json: {project: serialize_project(project)}, status: :created
    end

    def update
      project = Inboxed::CurrentTenant.scope_projects(ProjectRecord).find(params[:id])
      project_params = params.require(:project).permit(:name, :default_ttl_hours, :max_inbox_count)
      project.update!(project_params)
      render json: {project: serialize_project(project)}
    end

    def destroy
      project = Inboxed::CurrentTenant.scope_projects(ProjectRecord).find(params[:id])
      InboxRecord.where(project_id: project.id).find_each do |inbox|
        Inboxed::Services::DeleteInbox.new.call(inbox_id: inbox.id)
      end
      ApiKeyRecord.where(project_id: project.id).delete_all
      project.destroy!
      head :no_content
    end

    private

    def serialize_project(record)
      {
        id: record.id,
        name: record.name,
        slug: record.slug,
        default_ttl_hours: record.default_ttl_hours,
        max_inbox_count: record.max_inbox_count,
        inbox_count: InboxRecord.where(project_id: record.id).count,
        created_at: record.created_at.iso8601
      }
    end
  end
end
