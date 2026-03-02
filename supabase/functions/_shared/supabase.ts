import { createClient } from "npm:@supabase/supabase-js@2";

export function createAdminClient() {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!url || !serviceRoleKey) {
    throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  }

  return createClient(url, serviceRoleKey, {
    auth: {
      persistSession: false
    }
  });
}

export function getBearerToken(req: Request): string {
  const authHeader = req.headers.get("Authorization") || "";
  if (!authHeader.startsWith("Bearer ")) {
    throw new Error("Missing bearer token");
  }
  return authHeader.slice("Bearer ".length).trim();
}

export async function requireUser(req: Request, admin: ReturnType<typeof createAdminClient>) {
  const token = getBearerToken(req);
  const { data, error } = await admin.auth.getUser(token);

  if (error || !data.user) {
    throw new Error("Invalid user session");
  }

  return data.user;
}

export async function assertRole(
  admin: ReturnType<typeof createAdminClient>,
  homeschoolId: string,
  userId: string,
  roles: string[]
) {
  const { data, error } = await admin
    .from("homeschool_memberships")
    .select("role")
    .eq("homeschool_id", homeschoolId)
    .eq("user_id", userId)
    .eq("status", "ACTIVE")
    .in("role", roles)
    .limit(1)
    .maybeSingle();

  if (error) {
    throw new Error(`Membership lookup failed: ${error.message}`);
  }

  if (!data) {
    throw new Error("Insufficient role");
  }

  return data.role;
}

export function json(status: number, body: unknown, extraHeaders: HeadersInit = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...extraHeaders
    }
  });
}
