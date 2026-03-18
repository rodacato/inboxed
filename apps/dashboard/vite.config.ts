import { sveltekit } from '@sveltejs/kit/vite';
import tailwindcss from '@tailwindcss/vite';
import { defineConfig } from 'vite';

export default defineConfig({
	plugins: [tailwindcss(), sveltekit()],
	server: {
		host: '0.0.0.0',
		port: 5179,
		proxy: {
			'/api': 'http://localhost:3100',
			'/admin': 'http://localhost:3100',
			'/site_admin': 'http://localhost:3100',
			'/auth': 'http://localhost:3100',
			'/setup': {
				target: 'http://localhost:3100',
				bypass(req) {
					// Let SvelteKit handle browser navigation (HTML requests)
					// Only proxy API calls (JSON requests)
					const accept = req.headers['accept'] || '';
					if (accept.includes('text/html')) {
						return req.url;
					}
				}
			},
			'/up': 'http://localhost:3100',
			'/hook': 'http://localhost:3100',
			'/cable': {
				target: 'ws://localhost:3100',
				ws: true
			}
		}
	}
});
