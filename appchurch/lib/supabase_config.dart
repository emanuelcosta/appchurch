const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://xfjtwpnnjodhfbodqxwx.supabase.co',
);
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const apiHost = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://10.0.2.2:3000',
);
const apiBaseUrl = '$apiHost/api/v1';
const defaultCongregationId = String.fromEnvironment(
  'CONGREGATION_ID',
  defaultValue: 'f4f1212d-b728-4a42-8fee-fec6abab33f1',
);
