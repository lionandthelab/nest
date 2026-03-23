const URL = process.env.SUPABASE_URL || 'https://avursvhmilcsssabqtkx.supabase.co';
const KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const h = { 'apikey': KEY, 'Authorization': `Bearer ${KEY}` };

async function q(path) {
  const r = await fetch(`${URL}/rest/v1/${path}`, { headers: h });
  const body = await r.json();
  return { status: r.status, body };
}

async function main() {
  const hs = 'd20deda6-96c5-4aa3-ae23-50c88705a627';

  const r1 = await q(`terms?select=id&homeschool_id=eq.${hs}`);
  console.log('terms:', r1.status, r1.body.length);

  const termId = r1.body[0]?.id;
  const r2 = await q(`class_groups?select=*&term_id=eq.${termId}`);
  console.log('class_groups:', r2.status, r2.body.length);

  const r3 = await q(`children?select=id,family_id,name,birth_date,profile_note,status,created_at,families!inner(homeschool_id,family_name)&families.homeschool_id=eq.${hs}&order=created_at.desc&limit=600`);
  console.log('children (inner join):', r3.status, Array.isArray(r3.body) ? r3.body.length : JSON.stringify(r3.body).substring(0, 300));

  const r4 = await q(`teacher_profiles?select=*&homeschool_id=eq.${hs}`);
  console.log('teacher_profiles:', r4.status, r4.body.length);

  const r5 = await q(`families?select=*&homeschool_id=eq.${hs}`);
  console.log('families:', r5.status, r5.body.length);

  const r6 = await q(`class_enrollments?select=*,children!inner(family_id,families!inner(homeschool_id))&children.families.homeschool_id=eq.${hs}`);
  console.log('class_enrollments:', r6.status, Array.isArray(r6.body) ? r6.body.length : JSON.stringify(r6.body).substring(0, 300));

  const r7 = await q('homeschool_memberships?select=*');
  console.log('memberships:', r7.status, r7.body.length);

  const r8 = await q(`session_teacher_assignments?select=*,teacher_profiles!inner(homeschool_id)&teacher_profiles.homeschool_id=eq.${hs}`);
  console.log('session_teacher_assignments:', r8.status, Array.isArray(r8.body) ? r8.body.length : JSON.stringify(r8.body).substring(0, 300));

  const r9 = await q(`family_guardians?select=*,families!inner(homeschool_id)&families.homeschool_id=eq.${hs}`);
  console.log('family_guardians:', r9.status, Array.isArray(r9.body) ? r9.body.length : JSON.stringify(r9.body).substring(0, 300));
}

main().catch(e => console.error('ERROR:', e));
