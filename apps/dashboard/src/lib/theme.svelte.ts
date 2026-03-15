type Theme = 'light' | 'dark';

let current = $state<Theme>(getInitialTheme());

function getInitialTheme(): Theme {
	if (typeof window === 'undefined') return 'light';
	const stored = localStorage.getItem('theme') as Theme | null;
	if (stored) return stored;
	return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

function apply(theme: Theme) {
	document.documentElement.classList.toggle('dark', theme === 'dark');
}

if (typeof window !== 'undefined') {
	apply(current);
}

export function getTheme() {
	return {
		get current() {
			return current;
		},
		get isDark() {
			return current === 'dark';
		},
		toggle() {
			current = current === 'dark' ? 'light' : 'dark';
			localStorage.setItem('theme', current);
			apply(current);
		}
	};
}
