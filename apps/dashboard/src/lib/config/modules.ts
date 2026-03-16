export interface SidebarModule {
	id: string;
	label: string;
	icon: string;
	route: (projectId: string) => string;
	countKey: string;
	enabled: boolean;
}

export const MODULES: SidebarModule[] = [
	{
		id: 'mail',
		label: 'Mail',
		icon: 'mail',
		route: (pid) => `/projects/${pid}/mail`,
		countKey: 'email_count',
		enabled: true
	}
	// Phase 8 modules will be added here:
	// { id: 'hooks', label: 'Hooks In', icon: 'webhook', route: (pid) => `/projects/${pid}/hooks`, countKey: 'request_count', enabled: false },
	// { id: 'forms', label: 'Forms', icon: 'description', route: (pid) => `/projects/${pid}/forms`, countKey: 'form_count', enabled: false },
	// { id: 'heartbeats', label: 'Heartbeats', icon: 'favorite', route: (pid) => `/projects/${pid}/heartbeats`, countKey: 'heartbeat_count', enabled: false },
];

export function getEnabledModules(features?: Record<string, boolean>): SidebarModule[] {
	if (!features) return MODULES.filter((m) => m.enabled);
	return MODULES.filter((m) => features[m.id] ?? m.enabled);
}
