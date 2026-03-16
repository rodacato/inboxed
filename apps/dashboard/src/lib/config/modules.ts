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
	},
	{
		id: 'hooks',
		label: 'Hooks',
		icon: 'webhook',
		route: (pid) => `/projects/${pid}/hooks`,
		countKey: 'hook_request_count',
		enabled: true
	}
];

export function getEnabledModules(features?: Record<string, boolean>): SidebarModule[] {
	if (!features) return MODULES.filter((m) => m.enabled);
	return MODULES.filter((m) => features[m.id] ?? m.enabled);
}
