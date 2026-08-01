import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const jsonHeaders = {
  "content-type": "application/json; charset=utf-8",
};

Deno.serve(async (request: Request) => {
  if (request.method !== "POST") {
    return Response.json(
      { deleted: false, error: "method_not_allowed" },
      { status: 405, headers: jsonHeaders },
    );
  }

  const authorization = request.headers.get("authorization");
  const accessToken = authorization?.replace(/^Bearer\s+/i, "");
  if (!accessToken) {
    return Response.json(
      { deleted: false, error: "unauthorized" },
      { status: 401, headers: jsonHeaders },
    );
  }

  const supabaseURL = Deno.env.get("SUPABASE_URL");
  const secretKey = Deno.env.get("SUPABASE_SECRET_KEY")
    ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseURL || !secretKey) {
    console.error("Missing Supabase server credentials");
    return Response.json(
      { deleted: false, error: "server_configuration" },
      { status: 500, headers: jsonHeaders },
    );
  }

  const admin = createClient(supabaseURL, secretKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const {
    data: { user },
    error: userError,
  } = await admin.auth.getUser(accessToken);
  if (userError || !user || user.is_anonymous) {
    return Response.json(
      { deleted: false, error: "registered_account_required" },
      { status: 401, headers: jsonHeaders },
    );
  }

  const { data: projects, error: projectsError } = await admin
    .from("projects")
    .select("id")
    .eq("creator_id", user.id);
  if (projectsError) {
    console.error("Failed to list account projects", projectsError);
    return Response.json(
      { deleted: false, error: "data_preparation_failed" },
      { status: 500, headers: jsonHeaders },
    );
  }

  const { error: preparationError } = await admin.rpc(
    "prepare_account_deletion",
    { p_user_id: user.id },
  );
  if (preparationError) {
    console.error("Failed to prepare account deletion", preparationError);
    return Response.json(
      { deleted: false, error: "data_preparation_failed" },
      { status: 500, headers: jsonHeaders },
    );
  }

  const normalizedUserID = user.id.toLowerCase();
  const projectImagePaths = (projects ?? []).map(({ id }) =>
    `projects/${normalizedUserID}/${String(id).toLowerCase()}/cover.jpg`
  );

  const cleanupResults = await Promise.all([
    projectImagePaths.length > 0
      ? admin.storage.from("project-images").remove(projectImagePaths)
      : Promise.resolve({ data: [], error: null }),
    admin.storage.from("profile-avatars").remove([
      `profiles/${normalizedUserID}/avatar.jpg`,
    ]),
  ]);
  const cleanupError = cleanupResults.find((result) => result.error)?.error;
  if (cleanupError) {
    console.error("Failed to remove account Storage objects", cleanupError);
    return Response.json(
      { deleted: false, error: "storage_cleanup_failed" },
      { status: 500, headers: jsonHeaders },
    );
  }

  // Soft deletion hashes the Auth identifier for limited audit correlation.
  // Public profile and user-owned rows still cascade according to the schema.
  const { error: deletionError } = await admin.auth.admin.deleteUser(
    user.id,
    true,
  );
  if (deletionError) {
    console.error("Failed to delete Auth user", deletionError);
    return Response.json(
      { deleted: false, error: "auth_deletion_failed" },
      { status: 500, headers: jsonHeaders },
    );
  }

  return Response.json(
    { deleted: true },
    { status: 200, headers: jsonHeaders },
  );
});
