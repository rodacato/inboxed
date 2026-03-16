import { fetchProjects } from '../../features/projects/projects.service';
import type { Project } from '../../features/projects/projects.types';

let projects = $state<Project[]>([]);
let loaded = $state(false);

export const projectsStore = {
	get projects() {
		return projects;
	},
	get loaded() {
		return loaded;
	},
	async load() {
		const res = await fetchProjects();
		projects = res.projects;
		loaded = true;
		return projects;
	},
	remove(id: string) {
		projects = projects.filter((p) => p.id !== id);
	},
	add(project: Project) {
		projects = [project, ...projects];
	},
	reset() {
		projects = [];
		loaded = false;
	}
};
