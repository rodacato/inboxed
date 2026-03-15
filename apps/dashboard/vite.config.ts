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
			'/admin': 'http://localhost:3100'
		}
	}
});
