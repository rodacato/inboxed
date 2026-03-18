import { redirect } from '@sveltejs/kit';

export function GET() {
	redirect(301, '/docs/index.html');
}
