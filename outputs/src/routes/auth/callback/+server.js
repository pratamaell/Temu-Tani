import { redirect } from '@sveltejs/kit';

export async function GET({ url, locals }) {
	const code = url.searchParams.get('code');
	const next = url.searchParams.get('next') ?? '/';
	if (code && locals.supabase) {
		await locals.supabase.auth.exchangeCodeForSession(code);
	}
	throw redirect(303, next.startsWith('/') && !next.startsWith('//') ? next : '/');
}
