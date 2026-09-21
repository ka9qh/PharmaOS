const SUPABASE_URL = 'https://bwgilcmzffcwdcxhfyfk.supabase.co';
const SUPABASE_SERVICE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ3Z2lsY216ZmZjd2RjeGhmeWZrIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4ODkwMzMzMSwiZXhwIjoyMTA0NDc5MzMxfQ.RIYWIyMsX7HY3dBCX-EDjQaeizAetyUakArlWZ9TqRM';

// Initialize Supabase Client with Service Role (Bypass RLS)
window.supabaseClient = supabase.createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
