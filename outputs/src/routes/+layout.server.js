export async function load({ locals }) {
	const { session, user } = await locals.getSession();
	return { session, user, supabaseConfigured: Boolean(locals.supabase) };
}
