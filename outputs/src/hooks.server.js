import { createServerClient } from '@supabase/ssr';
import { env } from '$env/dynamic/public';

export async function handle({ event, resolve }) {
	const url = env.PUBLIC_SUPABASE_URL;
	const key = env.PUBLIC_SUPABASE_PUBLISHABLE_KEY;
	event.locals.supabase = url && key ? createServerClient(url, key, {
		cookies: {
			getAll: () => event.cookies.getAll(),
			setAll: (cookiesToSet) => cookiesToSet.forEach(({ name, value, options }) => event.cookies.set(name, value, { ...options, path: '/' }))
		}
	}) : null;
	event.locals.getSession = async () => {
		if (!event.locals.supabase) return { session: null, user: null };
		const { data: { user } } = await event.locals.supabase.auth.getUser();
		const { data: { session } } = await event.locals.supabase.auth.getSession();
		return { session, user };
	};
	return resolve(event, { filterSerializedResponseHeaders: (name) => name === 'content-range' || name === 'x-supabase-api-version' });
}
