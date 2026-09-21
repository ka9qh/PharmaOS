const { Client } = require('pg');

const passwords = [
  'Aboody77.',
  'Aboody77',
  'aboody77.'
];

const schemaSql = `
-- جدول الأوامر عن بعد (تطبيق المدير)
CREATE TABLE IF NOT EXISTS public.remote_commands (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pharmacy_id BIGINT REFERENCES public.pharmacies(id) ON DELETE CASCADE,
    branch_id BIGINT REFERENCES public.branches(id) ON DELETE CASCADE,
    command_type TEXT NOT NULL, 
    command_payload JSONB DEFAULT '{}'::jsonb,
    target_device_id TEXT, 
    status TEXT DEFAULT 'pending', 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    executed_at TIMESTAMP WITH TIME ZONE,
    error_message TEXT
);

-- جدول بث الإطارات الحي (الشاشة والكاميرا)
CREATE TABLE IF NOT EXISTS public.cloud_stream_frames (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pharmacy_id BIGINT NOT NULL,
    branch_id BIGINT NOT NULL,
    stream_type TEXT NOT NULL, 
    frame_data TEXT NOT NULL, 
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- جدول الرسائل المباشرة للمدير
CREATE TABLE IF NOT EXISTS public.owner_chat_messages (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    pharmacy_id BIGINT NOT NULL,
    branch_id BIGINT NOT NULL,
    sender_type TEXT NOT NULL, 
    message_text TEXT,
    attachment_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    read_at TIMESTAMP WITH TIME ZONE
);

-- تفعيل التنبيهات اللحظية (Realtime)
ALTER PUBLICATION supabase_realtime ADD TABLE public.remote_commands;
ALTER PUBLICATION supabase_realtime ADD TABLE public.cloud_stream_frames;
ALTER PUBLICATION supabase_realtime ADD TABLE public.owner_chat_messages;
`;

async function run() {
  for (let pwd of passwords) {
    console.log('Trying password:', pwd);
    const client = new Client({
      host: 'db.bwgilcmzffcwdcxhfyfk.supabase.co',
      port: 5432,
      database: 'postgres',
      user: 'postgres',
      password: pwd,
      ssl: { rejectUnauthorized: false }
    });

    try {
      await client.connect();
      console.log('Connected successfully with password:', pwd);
      
      console.log('Executing schema...');
      await client.query(schemaSql);
      console.log('Schema executed successfully!');
      
      await client.end();
      return;
    } catch (e) {
      console.log('Failed with password:', pwd, e.message);
    }
  }
  console.log('All passwords failed.');
}

run();
