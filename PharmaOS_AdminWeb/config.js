// This file is served to browsers.  A service-role key must never be placed
// here: it bypasses every Row Level Security policy.  The host injects only
// the publishable key at deploy time; privileged operations belong in an
// authenticated Edge Function.
const config = window.PHARMAOS_CONFIG ?? {};
const SUPABASE_URL = config.supabaseUrl;
const SUPABASE_PUBLISHABLE_KEY = config.supabasePublishableKey;

if (!SUPABASE_URL || !SUPABASE_PUBLISHABLE_KEY) {
  throw new Error('Missing PHARMAOS_CONFIG. Configure Supabase URL and publishable key in the hosting environment.');
}

window.supabaseClient = supabase.createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY);
