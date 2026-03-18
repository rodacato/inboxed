export interface SiteOrganization {
	id: string;
	name: string;
	slug: string;
	trial: boolean;
	trial_ends_at: string | null;
	permanent: boolean;
	member_count: number;
	project_count: number;
	created_at: string;
}

export interface SiteUser {
	id: string;
	email: string;
	site_admin: boolean;
	verified: boolean;
	organization: string | null;
	last_sign_in_at: string | null;
	created_at: string;
}

export interface SiteSettings {
	registration_mode: string;
	trial_duration_days: number;
	outbound_smtp_configured: boolean;
	github_oauth_configured: boolean;
	setup_completed_at: string | null;
	user_count: number;
	organization_count: number;
}
