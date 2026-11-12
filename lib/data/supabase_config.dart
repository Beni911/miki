const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const hasSupabaseConfig = supabaseUrl != '' && supabaseAnonKey != '';
