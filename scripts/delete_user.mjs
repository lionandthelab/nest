const SUPABASE_URL = process.env.SUPABASE_URL || 'https://avursvhmilcsssabqtkx.supabase.co';
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

const headers = {
  apikey: SERVICE_ROLE_KEY,
  Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
  'Content-Type': 'application/json',
};

const TARGET_EMAIL = 'ikess0330@gmail.com';

async function main() {
  // 1. Find user by email (paginate through all users)
  let user = null;
  let page = 1;
  while (!user) {
    const usersRes = await fetch(`${SUPABASE_URL}/auth/v1/admin/users?page=${page}&per_page=100`, { headers });
    const usersData = await usersRes.json();
    if (!usersData.users || usersData.users.length === 0) break;
    user = usersData.users.find(u => u.email === TARGET_EMAIL);
    console.log(`Page ${page}: ${usersData.users.length} users, emails:`, usersData.users.map(u => u.email));
    page++;
  }
  if (!user) {
    console.log('User not found:', TARGET_EMAIL);
    return;
  }
  console.log('Found user:', user.id, user.email);

  // 2. Find homeschools owned by this user
  const hsRes = await fetch(`${SUPABASE_URL}/rest/v1/homeschools?owner_user_id=eq.${user.id}&select=*`, { headers });
  const homeschools = await hsRes.json();
  console.log('Homeschools owned:', homeschools.map(h => `${h.id} (${h.name})`));

  // 3. Find memberships
  const memRes = await fetch(`${SUPABASE_URL}/rest/v1/homeschool_memberships?user_id=eq.${user.id}&select=*`, {
    headers: { ...headers, Accept: 'application/json' },
  });
  const memberships = await memRes.json();
  console.log('Memberships:', JSON.stringify(memberships));

  // 4. For each owned homeschool, cascade delete all related data
  for (const hs of homeschools) {
    const hsId = hs.id;
    console.log(`\nDeleting data for homeschool: ${hs.name} (${hsId})`);

    // Delete in dependency order
    const tables = [
      'time_slots',
      'class_sessions',
      'children',
      'families',
      'teacher_profiles',
      'terms',
      'homeschool_memberships',
    ];

    for (const table of tables) {
      const delRes = await fetch(`${SUPABASE_URL}/rest/v1/${table}?homeschool_id=eq.${hsId}`, {
        method: 'DELETE',
        headers: { ...headers, Prefer: 'return=representation' },
      });
      const deleted = await delRes.json();
      console.log(`  ${table}: deleted ${Array.isArray(deleted) ? deleted.length : 0} rows`);
    }

    // Delete homeschool itself
    const hsDelRes = await fetch(`${SUPABASE_URL}/rest/v1/homeschools?id=eq.${hsId}`, {
      method: 'DELETE',
      headers: { ...headers, Prefer: 'return=representation' },
    });
    const hsDel = await hsDelRes.json();
    console.log(`  homeschools: deleted ${Array.isArray(hsDel) ? hsDel.length : 0} rows`);
  }

  // 5. Delete memberships in other homeschools (if any)
  for (const m of memberships) {
    // Skip if homeschool was already deleted above
    if (homeschools.some(h => h.id === m.homeschool_id)) continue;
    const delRes = await fetch(`${SUPABASE_URL}/rest/v1/homeschool_memberships?id=eq.${m.id}`, {
      method: 'DELETE',
      headers: { ...headers, Prefer: 'return=representation' },
    });
    const deleted = await delRes.json();
    console.log(`Deleted membership ${m.id} from homeschool ${m.homeschool_id}`);
  }

  // 6. Delete auth user
  const authDelRes = await fetch(`${SUPABASE_URL}/auth/v1/admin/users/${user.id}`, {
    method: 'DELETE',
    headers,
  });
  console.log('Auth user delete status:', authDelRes.status);
  console.log('\nDone! User and all related data deleted.');
}

main().catch(console.error);
