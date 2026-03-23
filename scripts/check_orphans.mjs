const url = process.env.SUPABASE_URL || 'https://avursvhmilcsssabqtkx.supabase.co';
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
const h = { 'apikey': key, 'Authorization': `Bearer ${key}` };

async function q(path) {
  const r = await fetch(`${url}/rest/v1/${path}`, { headers: h });
  return r.json();
}

async function check() {
  const children = await q('children?select=id,name,family_id');
  const families = await q('families?select=id');
  const familyIds = new Set(families.map(f => f.id));
  const orphanedChildren = children.filter(c => !familyIds.has(c.family_id));
  console.log('Total children:', children.length);
  console.log('Orphaned children (family deleted):', orphanedChildren.length);
  if (orphanedChildren.length > 0) console.log(JSON.stringify(orphanedChildren, null, 2));

  const assignments = await q('session_teacher_assignments?select=id,teacher_profile_id');
  const teachers = await q('teacher_profiles?select=id');
  const teacherIds = new Set(teachers.map(t => t.id));
  const orphanedAssignments = assignments.filter(a => !teacherIds.has(a.teacher_profile_id));
  console.log('\nTotal assignments:', assignments.length);
  console.log('Orphaned assignments (teacher deleted):', orphanedAssignments.length);
  if (orphanedAssignments.length > 0) console.log(JSON.stringify(orphanedAssignments, null, 2));

  const groups = await q('class_groups?select=id,name,main_teacher_id&main_teacher_id=not.is.null');
  const orphanedGroups = groups.filter(g => !teacherIds.has(g.main_teacher_id));
  console.log('\nClass groups with deleted main_teacher:', orphanedGroups.length);
  if (orphanedGroups.length > 0) console.log(JSON.stringify(orphanedGroups, null, 2));

  const enrollments = await q('class_enrollments?select=id,child_id');
  const childIds = new Set(children.map(c => c.id));
  const orphanedEnrollments = enrollments.filter(e => !childIds.has(e.child_id));
  console.log('\nOrphaned enrollments (child deleted):', orphanedEnrollments.length);
  if (orphanedEnrollments.length > 0) console.log(JSON.stringify(orphanedEnrollments, null, 2));

  // Check family_guardians referencing deleted families
  const guardians = await q('family_guardians?select=id,family_id,user_id');
  const orphanedGuardians = guardians.filter(g => !familyIds.has(g.family_id));
  console.log('\nOrphaned guardians (family deleted):', orphanedGuardians.length);
  if (orphanedGuardians.length > 0) console.log(JSON.stringify(orphanedGuardians, null, 2));
}

check().catch(e => console.error(e));
