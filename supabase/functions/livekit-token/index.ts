// Issues short-lived LiveKit credentials.  Deploy with:
// supabase functions deploy livekit-token
// Required secrets: LIVEKIT_URL, LIVEKIT_API_KEY, LIVEKIT_API_SECRET.
// The API secret remains inside Supabase and is never sent to either client.
import { AccessToken } from 'npm:livekit-server-sdk@2.15.0';
import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return new Response('Method not allowed', { status: 405, headers: corsHeaders });

  const auth = request.headers.get('Authorization');
  if (!auth?.startsWith('Bearer ')) {
    return new Response(JSON.stringify({ error: 'Authentication required' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  }

  const client = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: auth } } },
  );
  const { data: { user }, error } = await client.auth.getUser();
  if (error || !user) {
    return new Response(JSON.stringify({ error: 'Invalid session' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  }
  const claims = user.app_metadata ?? {};
  const pharmacyId = Number(claims.pharmacy_id);
  const branchId = Number(claims.branch_id);
  const role = String(claims.pharma_role ?? '');
  if (!Number.isInteger(pharmacyId) || pharmacyId <= 0 || !Number.isInteger(branchId) || branchId <= 0 || !['owner', 'device'].includes(role)) {
    return new Response(JSON.stringify({ error: 'Invalid tenant claims' }), { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  }

  const room = `pharmacy-${pharmacyId}-branch-${branchId}`;
  const identity = `${role}-${user.id}`;
  const token = new AccessToken(Deno.env.get('LIVEKIT_API_KEY')!, Deno.env.get('LIVEKIT_API_SECRET')!, {
    identity,
    name: role === 'owner' ? 'Owner' : 'PharmaOS device',
    ttl: '10m',
  });
  token.addGrant({
    roomJoin: true,
    room,
    canPublish: role === 'device',
    canSubscribe: true,
    canPublishData: false,
  });

  return new Response(JSON.stringify({ server_url: Deno.env.get('LIVEKIT_URL'), participant_token: await token.toJwt(), room }), {
    status: 201,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
});
