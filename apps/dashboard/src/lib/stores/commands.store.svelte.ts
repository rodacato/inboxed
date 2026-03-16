export interface Command {
	id: string;
	label: string;
	category: 'navigation' | 'action' | 'recent';
	icon?: string;
	keywords?: string[];
	execute: () => void;
}

let commands = $state<Command[]>([]);
let open = $state(false);

import { SvelteSet } from 'svelte/reactivity';

export const commandStore = {
	get items() {
		return commands;
	},

	get isOpen() {
		return open;
	},

	toggle() {
		open = !open;
	},

	show() {
		open = true;
	},

	hide() {
		open = false;
	},

	register(command: Command) {
		commands = [...commands.filter((c) => c.id !== command.id), command];
	},

	registerMany(newCommands: Command[]) {
		const ids = new SvelteSet(newCommands.map((c) => c.id));
		commands = [...commands.filter((c) => !ids.has(c.id)), ...newCommands];
	},

	unregister(id: string) {
		commands = commands.filter((c) => c.id !== id);
	},

	unregisterByPrefix(prefix: string) {
		commands = commands.filter((c) => !c.id.startsWith(prefix));
	},

	search(query: string): Command[] {
		if (!query) return commands;
		const q = query.toLowerCase();
		return commands.filter(
			(c) =>
				c.label.toLowerCase().includes(q) ||
				c.keywords?.some((k) => k.toLowerCase().includes(q))
		);
	}
};
