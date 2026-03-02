class AppConfig {
  const AppConfig._();

  static const String appName = 'Nest';
  static const String brandLine = '우리 아이가 날아오르기 전, 따뜻한 둥지';

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://avursvhmilcsssabqtkx.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF2dXJzdmhtaWxjc3NzYWJxdGt4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI0MjkyOTcsImV4cCI6MjA4ODAwNTI5N30.5hM86lAonGgnEVKfPH4iMkBsv6ayBpMHJm2tQ1FYyls',
  );

  static const String oauthStoragePrefix = 'nest.oauth';
  static const String oauthCallbackPath = '/oauth/google/callback.html';
}
